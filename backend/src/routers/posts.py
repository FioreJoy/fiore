# backend/src/routers/posts.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File
from typing import List, Optional
import psycopg2
import os # For path manipulation if needed

from .. import schemas, crud, auth, utils # Relative imports
from ..database import get_db_connection
from ..utils import upload_file_to_minio, get_minio_url # MinIO specific imports

router = APIRouter(
    prefix="/posts",
    tags=["Posts"],
)

@router.post("", status_code=status.HTTP_201_CREATED, response_model=schemas.PostDisplay)
async def create_post(
        current_user_id: int = Depends(auth.get_current_user),
        title: str = Form(...),
        content: str = Form(...),
        community_id: Optional[int] = Form(None),
        image: Optional[UploadFile] = File(None)
):
    """
    Creates a new post, optionally with an image and linked to a community.
    The image is uploaded to MinIO.
    """
    conn = None
    minio_image_path = None
    try:
        # Handle Image Upload to MinIO
        if image and utils.minio_client:
            # Fetch username for path prefix (optional, could use user_id)
            temp_conn_user = get_db_connection()
            temp_cursor_user = temp_conn_user.cursor()
            user_info = crud.get_user_by_id(temp_cursor_user, current_user_id)
            username = user_info.get('username', f'user_{current_user_id}') if user_info else f'user_{current_user_id}'
            temp_cursor_user.close()
            temp_conn_user.close()

            object_name_prefix = f"users/{username}/posts/"
            minio_image_path = await upload_file_to_minio(image, object_name_prefix)
            if minio_image_path is None:
                print(f"⚠️ Warning: MinIO post image upload failed for user {current_user_id}")
                # Continue without image path if upload failed

        # Proceed with DB insertion
        conn = get_db_connection()
        cursor = conn.cursor()
        post_id = crud.create_post_db(
            cursor,
            user_id=current_user_id,
            title=title,
            content=content,
            image_path=minio_image_path, # Pass MinIO path to CRUD
            community_id=community_id
        )
        if post_id is None:
            raise HTTPException(status_code=500, detail="Post creation failed in database")

        # Fetch the created post details including necessary joins for response
        # (Assuming get_posts_db can fetch a single post with joins by modifying it or using a specific function)
        # For simplicity, let's fetch again with the detailed query structure
        cursor.execute("""
            SELECT
                p.id, p.user_id, p.content, p.title, p.created_at, p.image_path,
                u.username AS author_name, u.image_path AS author_avatar,
                COALESCE(v_counts.upvotes, 0) AS upvotes,
                COALESCE(v_counts.downvotes, 0) AS downvotes,
                COALESCE(r_counts.reply_count, 0) AS reply_count,
                c.id as community_id, c.name as community_name
            FROM posts p
            JOIN users u ON p.user_id = u.id
            LEFT JOIN community_posts cp ON p.id = cp.post_id
            LEFT JOIN communities c ON cp.community_id = c.id
            LEFT JOIN (
                SELECT post_id, COUNT(*) FILTER (WHERE vote_type = TRUE) AS upvotes, COUNT(*) FILTER (WHERE vote_type = FALSE) AS downvotes
                FROM votes WHERE post_id IS NOT NULL GROUP BY post_id
            ) AS v_counts ON p.id = v_counts.post_id
            LEFT JOIN ( SELECT post_id, COUNT(*) AS reply_count FROM replies GROUP BY post_id ) AS r_counts ON p.id = r_counts.post_id
            WHERE p.id = %s;
        """, (post_id,))
        created_post_db = cursor.fetchone()

        if not created_post_db:
            # This shouldn't happen if insert succeeded, but handle defensively
            conn.rollback() # Rollback the insert if fetch failed
            raise HTTPException(status_code=500, detail="Could not retrieve created post after insertion")

        conn.commit() # Commit only after successful insert and fetch

        # Prepare response data with full URLs
        response_data = dict(created_post_db)
        response_data['image_url'] = get_minio_url(created_post_db.get('image_path'))
        response_data['author_avatar_url'] = get_minio_url(created_post_db.get('author_avatar')) # author_avatar contains path

        print(f"✅ Post created with ID: {post_id}, Image Path: {minio_image_path}, Community: {community_id}")
        return schemas.PostDisplay(**response_data)

    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ SQL Error creating post: {e.pgcode} - {e.pgerror}")
        # Consider deleting uploaded MinIO image on DB error?
        # if minio_image_path and utils.minio_client: utils.delete_from_minio(minio_image_path) # Need delete helper
        raise HTTPException(status_code=400, detail=f"Database error: {e.pgerror}")
    except HTTPException as http_exc:
        if conn: conn.rollback()
        # Consider deleting uploaded MinIO image on specific HTTP errors?
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Unexpected Error creating post: {repr(e)}")
        # Consider deleting uploaded MinIO image on general error?
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()


@router.get("", response_model=List[schemas.PostDisplay])
async def get_posts(
        community_id: Optional[int] = None,
        user_id: Optional[int] = None,
        limit: int = 20,
        offset: int = 0
):
    """ Fetches posts, optionally filtered by community or user, with image URLs. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Modify crud.get_posts_db to accept limit/offset if needed, or do it here
        posts_db = crud.get_posts_db(cursor, community_id=community_id, user_id=user_id) # Add limit/offset later

        processed_posts = []
        for post in posts_db:
            post_data = dict(post)
            post_data['image_url'] = get_minio_url(post.get('image_path'))
            post_data['author_avatar_url'] = get_minio_url(post.get('author_avatar'))
            processed_posts.append(schemas.PostDisplay(**post_data)) # Validate each item

        print(f"✅ Fetched {len(processed_posts)} posts")
        return processed_posts
    except Exception as e:
        print(f"❌ Error fetching posts: {e}")
        raise HTTPException(status_code=500, detail="Error fetching posts")
    finally:
        if conn: conn.close()


@router.get("/trending", response_model=List[schemas.PostDisplay])
async def get_trending_posts():
    """ Fetches trending posts with image URLs. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        posts_db = crud.get_trending_posts_db(cursor)

        processed_posts = []
        for post in posts_db:
            post_data = dict(post)
            post_data['image_url'] = get_minio_url(post.get('image_path'))
            post_data['author_avatar_url'] = get_minio_url(post.get('author_avatar'))
            processed_posts.append(schemas.PostDisplay(**post_data)) # Validate

        print(f"✅ Fetched {len(processed_posts)} trending posts")
        return processed_posts
    except Exception as e:
        print(f"❌ Error fetching trending posts: {e}")
        raise HTTPException(status_code=500, detail="Error fetching trending posts")
    finally:
        if conn: conn.close()


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Deletes a post (only author can delete). Optionally deletes MinIO image. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Check ownership and get image path before deleting from DB
        post = crud.get_post_by_id(cursor, post_id)
        if not post:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
        if post["user_id"] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to delete this post")

        minio_image_path_to_delete = post.get("image_path")

        # Delete from DB first
        rows_deleted = crud.delete_post_db(cursor, post_id)
        conn.commit() # Commit DB change

        if rows_deleted == 0:
            # This case should be caught by the check above, but good to have
            print(f"⚠️ Post {post_id} not found for deletion (already checked).")
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found during delete step")

        # Attempt to delete from MinIO AFTER successful DB deletion
        if minio_image_path_to_delete and utils.minio_client:
            try:
                utils.minio_client.remove_object(utils.MINIO_BUCKET, minio_image_path_to_delete)
                print(f"🗑️ Deleted MinIO object: {minio_image_path_to_delete}")
            except Exception as minio_del_err:
                # Log error but don't fail the request, DB delete was successful
                print(f"⚠️ Warning: Failed to delete MinIO object {minio_image_path_to_delete}: {minio_del_err}")

        print(f"✅ Post {post_id} deleted successfully from DB")
        return None # Return None for 204 No Content

    except HTTPException as http_exc:
        if conn: conn.rollback()
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

# --- TODO: Add post favorites endpoints if needed ---