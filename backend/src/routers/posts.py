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
    media_ids_created = []
    minio_objects_created = []

    try:
        conn = get_db_connection(); cursor = conn.cursor()

        # 1. Create the post entry
        post_id = crud.create_post_db(
            cursor, user_id=current_user_id, title=title, content=content
        )
        if post_id is None:
            raise HTTPException(status_code=500, detail="Post base creation failed")

        # 2. Handle File Uploads and Linking (Keep existing logic)
        # ... (upload loop) ...
        for file in files:
            if file and file.filename:
                object_name_prefix = f"media/posts/{post_id}"
                upload_info = await utils.upload_file_to_minio(file, object_name_prefix)
                if upload_info:
                    minio_objects_created.append(upload_info['minio_object_name'])
                    media_id = crud.create_media_item(
                        cursor, uploader_user_id=current_user_id, **upload_info
                    )
                    if media_id:
                        media_ids_created.append(media_id)
                        crud.link_media_to_post(cursor, post_id, media_id)
                    else:
                        print(f"WARN: Failed media_item record for {upload_info['minio_object_name']}")
                else:
                    print(f"WARN: Failed upload for {file.filename}")
                    # Consider raising HTTP 500 here?
                    # raise HTTPException(status_code=500, detail=f"Failed to upload file {file.filename}")

        # 3. Link to community if ID provided (Keep existing logic)
        if community_id is not None:
            # Ensure community exists before linking (optional but good)
            comm_exists = crud.get_community_by_id(cursor, community_id)
            if not comm_exists:
                raise HTTPException(status_code=404, detail=f"Community {community_id} not found")
            crud.add_post_to_community_db(cursor, community_id, post_id)
            print(f"Linked post {post_id} to community {community_id}")


        # --- *** START FIX for Failure 8 *** ---
        # 4. Fetch full post details for response (Corrected Fetch Logic)

        # Fetch relational post data
        created_post_relational = crud.get_post_by_id(cursor, post_id)
        if not created_post_relational:
            raise HTTPException(status_code=500, detail="Could not retrieve created post relational details")

        created_post_data = dict(created_post_relational) # Convert to dict

        # Fetch author info
        author_info = crud.get_user_by_id(cursor, created_post_data['user_id'])
        if author_info:
            created_post_data['author_name'] = author_info.get('username')
            created_post_data['author_avatar'] = author_info.get('image_path') # Store path
            created_post_data['author_id'] = author_info.get('id') # Keep if needed elsewhere
        else: # Should ideally not happen if user_id FK holds
            created_post_data['author_name'] = "Unknown"
            created_post_data['author_avatar'] = None
            created_post_data['author_id'] = created_post_data['user_id']

        # Fetch community info (if linked)
        created_post_data['community_id'] = None # Default
        created_post_data['community_name'] = None
        if community_id is not None:
            # We already checked existence, or fetch again if paranoid
            comm_info = crud.get_community_by_id(cursor, community_id)
            if comm_info:
                created_post_data['community_id'] = community_id
                created_post_data['community_name'] = comm_info.get('name')

        # Fetch graph counts
        try:
            counts = crud.get_post_counts(cursor, post_id)
            created_post_data.update(counts)
        except Exception as count_err:
            print(f"WARN: Failed getting counts for new post {post_id}: {count_err}")
            created_post_data.update({"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0})

        # Fetch media items
        try:
            media_items = crud.get_media_items_for_post(cursor, post_id)
            created_post_data['media'] = media_items # Add media list
        except Exception as media_err:
            print(f"WARN: Failed getting media for new post {post_id}: {media_err}")
            created_post_data['media'] = []

        # --- *** END FIX for Failure 8 *** ---

        conn.commit() # Commit everything

        # Prepare response (adjust structure if schema changed)
        response_data = created_post_data # Now contains augmented data
        response_data['author_avatar_url'] = utils.get_minio_url(response_data.get('author_avatar'))
        response_data['media'] = [
            {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))}
            for item in response_data.get('media', [])
        ]
        # Ensure all fields required by PostDisplay are present
        response_data.setdefault('upvotes', 0); response_data.setdefault('downvotes', 0); response_data.setdefault('reply_count', 0); response_data.setdefault('favorite_count', 0)
        response_data['viewer_vote_type'] = None
        response_data['viewer_has_favorited'] = False

        return schemas.PostDisplay(**response_data)

    # ... (keep existing error handling) ...
    except HTTPException as http_exc:
        if conn: conn.rollback()
        for obj_name in minio_objects_created: delete_from_minio(obj_name)
        raise http_exc
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        for obj_name in minio_objects_created: delete_from_minio(obj_name)
        print(f"❌ DB Error creating post: {db_err} (Code: {db_err.pgcode})")
        raise HTTPException(status_code=500, detail=f"Database error: {db_err.pgerror}")
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

# --- Placeholder for /trending ---
@router.get("/trending", response_model=List[schemas.PostDisplay])
async def get_trending_posts(
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional),
        limit: int = 20, # Add optional limit/offset if needed
        offset: int = 0
):
    """
    [PLACEHOLDER] Fetches trending posts based on recent activity.
    Current implementation returns an empty list.
    """
    print("WARN: /posts/trending endpoint is a placeholder and not implemented.")
    # TODO: Implement actual trending logic.
    # This might involve:
    # 1. A complex SQL query ranking posts by recent votes, replies, favorites within a time window.
    # 2. A complex Cypher query finding posts with high recent engagement.
    # 3. Using a separate analytics system or pre-calculated scores.

    # --- Placeholder Logic ---
    conn = None
    try:
        # Example: Fetching recent posts as a temporary placeholder (NOT actual trending)
        # conn = get_db_connection(); cursor = conn.cursor()
        # posts_db = crud.get_posts_db(cursor, limit=limit, offset=offset) # Just get latest
        # processed_posts = []
        # for post in posts_db:
        #     # ... (process post data like in GET /posts) ...
        #     processed_posts.append(schemas.PostDisplay(**post_data))
        # return processed_posts

        # Return empty list for now
        return []

    except Exception as e:
        print(f"❌ Error in (placeholder) /posts/trending: {e}")
        traceback.print_exc()
        # Return empty list on error for now, or raise 500
        # raise HTTPException(status_code=500, detail="Error fetching trending posts")
        return []
    finally:
        if conn: conn.close()
# --- End Placeholder ---

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

@router.get("/{post_id}", response_model=schemas.PostDisplay)
async def get_post_details(
        post_id: int,
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    """ Fetches details for a specific post, including media and counts. """
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()

        # Fetch relational post data
        post_relational = crud.get_post_by_id(cursor, post_id)
        if not post_relational:
            raise HTTPException(status_code=404, detail="Post not found")

        post_data = dict(post_relational)

        # Fetch author info
        author_info = crud.get_user_by_id(cursor, post_data['user_id'])
        if author_info:
            post_data['author_name'] = author_info.get('username')
            post_data['author_avatar_url'] = utils.get_minio_url(author_info.get('image_path'))
        else:
            post_data['author_name'] = "Unknown"; post_data['author_avatar_url'] = None

        # Fetch community info (if linked)
        # Need a way to know if it's linked. Query community_posts or graph edge?
        # Let's assume graph edge is preferred now
        # Fetch community info (if linked) using graph
        comm_id = None; comm_name = None
        try:
            cypher_q_comm = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {post_id}}}) RETURN c.id as id, c.name as name LIMIT 1"
            expected_comm = [('id', 'agtype'), ('name', 'agtype')] # Define expected
            comm_res = crud.execute_cypher(cursor, cypher_q_comm, fetch_one=True, expected_columns=expected_comm)
            if comm_res and isinstance(comm_res, dict):
                comm_id = comm_res.get('id'); comm_name = comm_res.get('name')
        except Exception as e: print(f"WARN: Failed fetching community link for P:{post_id}: {e}")
        post_data['community_id'] = comm_id
        post_data['community_name'] = comm_name



        # Fetch graph counts
        try: counts = crud.get_post_counts(cursor, post_id); post_data.update(counts)
        except Exception as e: print(f"WARN: Failed getting counts P:{post_id}: {e}"); post_data.update({"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0})

        # Fetch media items
        try:
            media_items = crud.get_media_items_for_post(cursor, post_id)
            print(f"DEBUG GET /posts/{post_id}: Fetched {len(media_items)} media items from DB.") # Log count
            post_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items ]
            print(f"DEBUG GET /posts/{post_id}: Processed media data: {post_data['media']}") # Log processed data
        except Exception as e:
            print(f"WARN: Failed getting media P:{post_id}: {e}")
            post_data['media'] = [] # Ensure it's an empty list on error

        # Fetch viewer status
        viewer_vote = None; is_favorited = False
        if current_user_id is not None:
            try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=post_id)
            except Exception as e: print(f"WARN: vote status check failed: {e}")
            try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=post_id)
            except Exception as e: print(f"WARN: fav status check failed: {e}")
        post_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
        post_data['viewer_has_favorited'] = is_favorited

        # Ensure necessary defaults if counts failed
        post_data.setdefault('upvotes', 0); post_data.setdefault('downvotes', 0); post_data.setdefault('reply_count', 0); post_data.setdefault('favorite_count', 0)

        return schemas.PostDisplay(**post_data)

    except HTTPException as http_exc: raise http_exc
    except psycopg2.Error as db_err: print(f"DB Error GET /posts/{post_id}: {db_err}"); raise HTTPException(status_code=500, detail="Database error")
    except Exception as e: print(f"Error GET /posts/{post_id}: {e}"); traceback.print_exc(); raise HTTPException(status_code=500, detail="Internal server error")
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
