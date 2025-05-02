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
        image: Optional[UploadFile] = File(None)
):
    conn = None
    minio_image_path = None
    post_id = None # Keep track of ID for potential rollback cleanup
    try:
        # 1. Handle Image Upload to MinIO first (if provided)
        if image and utils.minio_client:
            # Fetch username for path prefix (optional)
            # This requires a DB call - consider if needed or just use user_id
            temp_conn_user = get_db_connection()
            temp_cursor_user = temp_conn_user.cursor()
            user_info = crud.get_user_by_id(temp_cursor_user, current_user_id) # Use relational get
            username = user_info.get('username', f'user_{current_user_id}') if user_info else f'user_{current_user_id}'
            temp_cursor_user.close()
            temp_conn_user.close()

            object_name_prefix = f"users/{username}/posts/"
            minio_image_path = await utils.upload_file_to_minio(image, object_name_prefix)
            if minio_image_path is None:
                print(f"⚠️ Warning: MinIO post image upload failed for user {current_user_id}")
                # Fail fast if image upload fails? Or allow post without image?
                # raise HTTPException(status_code=500, detail="Image upload failed")
        else:
            minio_image_path = None # Ensure it's None if no image or no minio client

        # 2. Proceed with DB insertion (Relational + Graph)
        conn = get_db_connection()
        cursor = conn.cursor()
        # create_post_db now handles both relational insert and graph creation
        post_id = crud.create_post_db(
            cursor, user_id=current_user_id, title=title, content=content,
            image_path=minio_image_path, community_id=community_id
        )
        if post_id is None:
            # If DB insert failed, try to clean up uploaded image
            if minio_image_path: delete_from_minio(minio_image_path)
            raise HTTPException(status_code=500, detail="Post creation failed in database")

        # 3. Fetch the created post details for the response
        # Use the combined fetch function
        created_post_db = crud.get_posts_db(cursor, post_id=post_id) # Assuming get_posts_db handles single ID fetch
        if not created_post_db:
            # This shouldn't happen if insert succeeded, but handle defensively
            conn.rollback()
            if minio_image_path: delete_from_minio(minio_image_path)
            raise HTTPException(status_code=500, detail="Could not retrieve created post after insertion")

        conn.commit() # Commit only after all DB operations succeed

        # 4. Prepare response data with full URLs
        # get_posts_db should return a list, get the first item
        response_data = created_post_db[0] if created_post_db else {}
        if response_data:
            # Generate URLs if paths exist
            response_data['image_url'] = get_minio_url(response_data.get('image_path'))
            response_data['author_avatar_url'] = get_minio_url(response_data.get('author_avatar'))
        else:
            # Handle case where post details couldn't be fetched back
            # This part needs refinement based on how get_posts_db handles single ID fetch
            print(f"Warning: Could not fetch back details for created post {post_id}")
            # Return minimal data or raise error
            return {"id": post_id, "title": title, "content": content} # Example fallback

        print(f"✅ Post created with ID: {post_id}, Image Path: {minio_image_path}, Community: {community_id}")
        return schemas.PostDisplay(**response_data) # Validate against schema

    except psycopg2.Error as e:
        if conn: conn.rollback()
        if minio_image_path: delete_from_minio(minio_image_path) # Cleanup upload on DB error
        print(f"❌ SQL Error creating post: {e.pgcode} - {e.pgerror}")
        raise HTTPException(status_code=400, detail=f"Database error: {e.pgerror}")
    except HTTPException as http_exc:
        # If it's an image upload failure exception we raised earlier
        # No need to rollback DB as it likely hasn't started
        # If it's another HTTP exception after DB started, rollback might be needed
        if conn: conn.rollback()
        # No image cleanup here as it would have happened before raising or didn't happen
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        if minio_image_path: delete_from_minio(minio_image_path) # Cleanup upload on general error
        print(f"❌ Unexpected Error creating post: {repr(e)}")
        import traceback
        traceback.print_exc()
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
