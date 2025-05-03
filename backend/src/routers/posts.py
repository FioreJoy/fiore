# backend/src/routers/posts.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File
from typing import List, Optional, Dict, Any # Added Dict, Any
import psycopg2
import os

# Use the central crud import
from .. import schemas, crud, auth, utils
from ..database import get_db_connection
from ..utils import get_minio_url, delete_from_minio # Added delete_from_minio

router = APIRouter(
    prefix="/posts",
    tags=["Posts"],
    # dependencies=[Depends(auth.get_current_user)] # Apply auth here
)

@router.post("", status_code=status.HTTP_201_CREATED, response_model=schemas.PostDisplay)
async def create_post(
        current_user_id: int = Depends(auth.get_current_user),
        title: str = Form(...),
        content: str = Form(...),
        community_id: Optional[int] = Form(None),
        files: List[UploadFile] = File(default=[]) # Accept multiple files
):
    conn = None
    post_id = None
    media_ids_created = [] # Keep track of created media for potential rollback
    minio_objects_created = []

    try:
        conn = get_db_connection(); cursor = conn.cursor()

        # 1. Create the post entry (relational + graph vertex + WROTE edge)
        post_id = crud.create_post_db(
            cursor, user_id=current_user_id, title=title, content=content
            # community_id is linked later if needed
        )
        if post_id is None:
            raise HTTPException(status_code=500, detail="Post base creation failed")

        # 2. Handle File Uploads and Linking
        for file in files:
            if file and file.filename:
                # Define path based on post ID
                object_name_prefix = f"media/posts/{post_id}"
                upload_info = await utils.upload_file_to_minio(file, object_name_prefix)

                if upload_info:
                    minio_objects_created.append(upload_info['minio_object_name'])
                    media_id = crud.create_media_item( # Create media record
                        cursor, uploader_user_id=current_user_id, **upload_info
                    )
                    if media_id:
                        media_ids_created.append(media_id)
                        crud.link_media_to_post(cursor, post_id, media_id) # Link it
                        print(f"Linked media {media_id} to post {post_id}")
                    else:
                        # Failed to create media item record, log warning
                        print(f"WARN: Failed to create media_item record for {upload_info['minio_object_name']}")
                        # Optionally delete the orphaned MinIO object here?
                else:
                    # Upload failed, raise error or log warning?
                    print(f"WARN: Failed to upload file {file.filename} to MinIO.")
                    # raise HTTPException(status_code=500, detail=f"Failed to upload file {file.filename}")


        # 3. Link to community if ID provided (creates graph edge)
        if community_id is not None:
            crud.add_post_to_community_db(cursor, community_id, post_id)
            print(f"Linked post {post_id} to community {community_id}")

        # 4. Fetch full post details for response
        # Need a function like crud.get_post_details_db(cursor, post_id) that includes media
        # Let's adapt get_posts_db logic slightly for single post fetch
        # (Or create a dedicated get_post_details_db function)
        posts_list = crud.get_posts_db(cursor, post_id_single=post_id) # Assume get_posts_db handles single ID
        created_post_data = posts_list[0] if posts_list else None

        if not created_post_data: raise HTTPException(status_code=500, detail="Could not retrieve created post details")

        # Fetch media separately
        media_items = crud.get_media_items_for_post(cursor, post_id)
        created_post_data['media'] = media_items # Add media list

        conn.commit() # Commit everything

        # Prepare response
        response_data = created_post_data
        # URLs for author avatar and media items
        response_data['author_avatar_url'] = utils.get_minio_url(response_data.get('author_avatar')) # author_avatar is path
        response_data['media'] = [ # Generate URLs for media
            {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))}
            for item in media_items
        ]
        # Add viewer status placeholders
        response_data['viewer_vote_type'] = None
        response_data['viewer_has_favorited'] = False

        return schemas.PostDisplay(**response_data)

    except HTTPException as http_exc:
        if conn: conn.rollback()
        # Cleanup any MinIO files uploaded before the error
        for obj_name in minio_objects_created: delete_from_minio(obj_name)
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        for obj_name in minio_objects_created: delete_from_minio(obj_name)
        print(f"❌ Unexpected Error creating post: {repr(e)}")
        import traceback; traceback.print_exc();
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()


@router.get("", response_model=List[schemas.PostDisplay])
async def get_posts(
        # Keep auth optional depending on whether public viewing is allowed
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional), # Correct usage
        community_id: Optional[int] = None,
        user_id: Optional[int] = None,
        limit: int = 20,
        offset: int = 0
):
    """ Fetches posts, optionally filtered. Includes graph counts. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # get_posts_db now fetches relational data + graph counts
        posts_db = crud.get_posts_db(
            cursor, community_id=community_id, user_id=user_id,
            limit=limit, offset=offset
        )

        processed_posts = []
        for post in posts_db:
            post_data = dict(post)
            # Generate URLs
            post_data['image_url'] = get_minio_url(post.get('image_path'))
            post_data['author_avatar_url'] = get_minio_url(post.get('author_avatar'))
            # TODO: Add user's vote/favorite status if user is authenticated
            # This would require another graph query per post or a more complex initial query
            post_data['has_upvoted'] = False # Placeholder
            post_data['has_downvoted'] = False # Placeholder
            post_data['is_favorited'] = False # Placeholder

            processed_posts.append(schemas.PostDisplay(**post_data)) # Validate

        print(f"✅ Fetched {len(processed_posts)} posts (Comm: {community_id}, User: {user_id})")
        return processed_posts
    except Exception as e:
        print(f"❌ Error fetching posts: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Error fetching posts")
    finally:
        if conn: conn.close()

# --- GET /trending (Keep as is, assuming get_trending_posts_db exists or uses get_posts_db) ---
# @router.get("/trending", ...)

@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Require auth
):
    """ Deletes a post (requires ownership). Deletes from relational, graph, and MinIO. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check ownership and get image path BEFORE deleting
        post = crud.get_post_by_id(cursor, post_id) # Fetch relational data
        if not post:
            # Don't rollback, just return 404
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
        if post["user_id"] != current_user_id:
            # Don't rollback, just return 403
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to delete this post")

        minio_image_path_to_delete = post.get("image_path")

        # 2. Call the combined delete function (handles graph + relational)
        deleted = crud.delete_post_db(cursor, post_id) # Assumes this handles transaction internally or raises

        if not deleted:
            # This might happen if the graph delete worked but relational failed, or vice-versa
            # Or if the post was deleted between the check and the delete call (race condition)
            conn.rollback() # Rollback if delete function indicated failure somehow
            print(f"⚠️ Post {post_id} delete function returned false.")
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found during deletion")

        conn.commit() # Commit successful deletion

        # 3. Attempt to delete from MinIO AFTER successful DB deletion
        if minio_image_path_to_delete:
            delete_from_minio(minio_image_path_to_delete) # Use helper

        print(f"✅ Post {post_id} deleted successfully by User {current_user_id}")
        return None # Return None for 204 No Content

    except HTTPException as http_exc:
        if conn: conn.rollback() # Rollback on HTTP exceptions caught before commit
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ SQL Error deleting post {post_id}: {e}")
        raise HTTPException(status_code=500, detail="Database error during deletion")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Unexpected Error deleting post {post_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not delete post")
    finally:
        if conn: conn.close()


# --- NEW: Favorite/Unfavorite Endpoints ---

@router.post("/{post_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def favorite_post(
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """Adds a post to the user's favorites."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Call CRUD function to create/update :FAVORITED edge
        success = crud.add_favorite_db(cursor, user_id=current_user_id, post_id=post_id, reply_id=None)
        conn.commit()

        # Fetch updated favorite count for response
        counts = crud.get_post_counts(cursor, post_id)

        return {
            "message": "Post favorited successfully",
            "success": success,
            "new_counts": counts
        }
    except psycopg2.Error as e:
        if conn: conn.rollback()
        # Check if error is due to post not existing (MATCH failed)
        print(f"❌ DB Error favoriting post {post_id}: {e}")
        raise HTTPException(status_code=500, detail="Database error favoriting post")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error favoriting post {post_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not favorite post")
    finally:
        if conn: conn.close()


@router.delete("/{post_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def unfavorite_post(
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """Removes a post from the user's favorites."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Call CRUD function to delete :FAVORITED edge
        deleted = crud.remove_favorite_db(cursor, user_id=current_user_id, post_id=post_id, reply_id=None)
        conn.commit()

        # Fetch updated favorite count for response
        counts = crud.get_post_counts(cursor, post_id)

        return {
            "message": "Post unfavorited successfully" if deleted else "Post was not favorited",
            "success": deleted,
            "new_counts": counts
        }
    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ DB Error unfavoriting post {post_id}: {e}")
        raise HTTPException(status_code=500, detail="Database error unfavoriting post")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error unfavoriting post {post_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not unfavorite post")
    finally:
        if conn: conn.close()
