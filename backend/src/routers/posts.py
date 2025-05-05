# src/routers/posts.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File, Query
from typing import List, Optional, Dict, Any, Literal # Added Query, Literal
import psycopg2
import os
import traceback
import json # For WebSocket payload

# Use the central crud import
from .. import schemas, crud, auth, utils, security
from ..database import get_db_connection
from ..utils import get_minio_url, delete_from_minio, delete_media_item_db_and_file
from ..connection_manager import manager # Import the WebSocket manager

router = APIRouter(
    prefix="/posts",
    tags=["Posts"],
    dependencies=[Depends(security.get_api_key)] # Apply API Key globally
)

# --- Placeholder for /trending ---
@router.get("/trending", response_model=List[schemas.PostDisplay])
async def get_trending_posts(
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional),
        limit: int = Query(20, ge=1, le=100), # Use Query for params
        offset: int = Query(0, ge=0)
):
    """
    [PLACEHOLDER] Fetches trending posts based on recent activity.
    Current implementation returns an empty list.
    """
    print("WARN: /posts/trending endpoint is a placeholder and not implemented.")
    # TODO: Implement actual trending logic in crud._feed.get_discover_feed
    # and call it here if using this endpoint for discover/trending.
    # For now, just return empty to pass the test expecting 200 OK.
    return []

# --- GET /{post_id} ---
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
            # Fetch author avatar URL correctly
            author_avatar_media = crud.get_user_profile_picture_media(cursor, post_data['user_id'])
            post_data['author_avatar_url'] = utils.get_minio_url(author_avatar_media.get('minio_object_name') if author_avatar_media else None)
        else:
            post_data['author_name'] = "Unknown"; post_data['author_avatar_url'] = None

        # Fetch community info (if linked) using graph
        comm_id = None; comm_name = None
        try:
            cypher_q_comm = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {post_id}}}) RETURN c.id as id, c.name as name LIMIT 1"
            expected_comm = [('id', 'agtype'), ('name', 'agtype')]
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
            # Validate and add URLs
            processed_media = []
            for item in media_items:
                item_dict = dict(item)
                item_dict['url'] = utils.get_minio_url(item_dict.get('minio_object_name'))
                processed_media.append(schemas.MediaItemDisplay(**item_dict))
            post_data['media'] = processed_media
        except Exception as e: print(f"WARN: Failed getting media P:{post_id}: {e}"); post_data['media'] = []

        # Fetch viewer status
        viewer_vote = None; is_favorited = False
        if current_user_id is not None:
            try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=post_id)
            except Exception as e: print(f"WARN: vote status check failed P:{post_id}: {e}")
            try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=post_id)
            except Exception as e: print(f"WARN: fav status check failed P:{post_id}: {e}")
        post_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
        post_data['viewer_has_favorited'] = is_favorited

        # Ensure necessary defaults if counts failed, etc.
        post_data.setdefault('upvotes', 0); post_data.setdefault('downvotes', 0); post_data.setdefault('reply_count', 0); post_data.setdefault('favorite_count', 0)
        post_data.setdefault('image_url', None) # If schema still has it

        return schemas.PostDisplay(**post_data) # Validate final response

    except HTTPException as http_exc: raise http_exc
    except psycopg2.Error as db_err: print(f"DB Error GET /posts/{post_id}: {db_err}"); raise HTTPException(status_code=500, detail="Database error")
    except Exception as e: print(f"Error GET /posts/{post_id}: {e}"); traceback.print_exc(); raise HTTPException(status_code=500, detail="Internal server error")
    finally:
        if conn: conn.close()

# --- GET /posts (List) ---
@router.get("", response_model=List[schemas.PostDisplay])
async def get_posts(
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional),
        community_id: Optional[int] = Query(None), # Use Query for query params
        user_id: Optional[int] = Query(None),
        limit: int = Query(20, ge=1, le=100),
        offset: int = Query(0, ge=0)
):
    """ Fetches posts, optionally filtered. Includes graph counts & viewer status. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # get_posts_db fetches relational data + graph counts + basic author/community info
        posts_db = crud.get_posts_db(
            cursor, community_id=community_id, user_id=user_id,
            limit=limit, offset=offset
        )

        processed_posts = []
        for post in posts_db:
            post_data = dict(post)
            post_id = post_data['id']
            author_id = post_data['user_id'] # Included from get_posts_db query

            # Generate author avatar URL
            # get_posts_db query includes author_id, fetch avatar media
            author_avatar_media = crud.get_user_profile_picture_media(cursor, author_id)
            post_data['author_avatar_url'] = utils.get_minio_url(author_avatar_media.get('minio_object_name') if author_avatar_media else None)

            # Fetch and generate Media URLs
            try:
                media_items = crud.get_media_items_for_post(cursor, post_id)
                post_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items ]
            except Exception as e: print(f"WARN list: Failed getting media P:{post_id}: {e}"); post_data['media'] = []

            # Get viewer status
            viewer_vote = None; is_favorited = False
            if current_user_id is not None:
                try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=post_id)
                except Exception as e: print(f"WARN list: vote status check failed P:{post_id}: {e}")
                try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=post_id)
                except Exception as e: print(f"WARN list: fav status check failed P:{post_id}: {e}")
            post_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
            post_data['viewer_has_favorited'] = is_favorited

            # Ensure defaults
            post_data.setdefault('upvotes', 0); post_data.setdefault('downvotes', 0); post_data.setdefault('reply_count', 0); post_data.setdefault('favorite_count', 0); post_data.setdefault('image_url', None)

            try:
                processed_posts.append(schemas.PostDisplay(**post_data)) # Validate
            except Exception as pydantic_err:
                print(f"ERROR: Pydantic validation failed for post {post_id} in list: {pydantic_err}\nData: {post_data}")

        print(f"✅ Fetched {len(processed_posts)} posts (Comm: {community_id}, User: {user_id})")
        return processed_posts
    except psycopg2.Error as db_err:
        print(f"DB Error listing posts: {db_err}")
        raise HTTPException(status_code=500, detail="Database error listing posts")
    except Exception as e:
        print(f"❌ Error fetching posts: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Error fetching posts")
    finally:
        if conn: conn.close()

# --- POST / (Create Post) ---
@router.post("", status_code=status.HTTP_201_CREATED, response_model=schemas.PostDisplay)
async def create_post(
        current_user_id: int = Depends(auth.get_current_user),
        title: str = Form(...),
        content: str = Form(...),
        community_id: Optional[int] = Form(None),
        files: List[UploadFile] = File(default=[])
):
    """ Creates a new post with optional media and community linking. Broadcasts update via WebSocket. """
    conn = None
    post_id = None
    media_ids_created = []
    minio_objects_created = []
    comm_exists = None # Store community check result

    try:
        conn = get_db_connection(); cursor = conn.cursor()

        # 1. Check community existence *before* creating post if ID provided
        if community_id is not None:
            comm_exists = crud.get_community_by_id(cursor, community_id)
            if not comm_exists:
                # Use 404 if community doesn't exist
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Community {community_id} not found")

        # 2. Create the post entry (relational + graph vertex + WROTE edge)
        post_id = crud.create_post_db(
            cursor, user_id=current_user_id, title=title, content=content
        )
        if post_id is None: raise HTTPException(status_code=500, detail="Post base creation failed")

        # 3. Handle File Uploads and Linking
        for file in files:
            if file and file.filename:
                object_name_prefix = f"media/posts/{post_id}"
                upload_info = await utils.upload_file_to_minio(file, object_name_prefix)
                if upload_info:
                    minio_objects_created.append(upload_info['minio_object_name'])
                    media_id = crud.create_media_item(cursor, uploader_user_id=current_user_id, **upload_info)
                    if media_id: media_ids_created.append(media_id); crud.link_media_to_post(cursor, post_id, media_id)
                    else: print(f"WARN: Failed media_item record for post {post_id}")
                else: print(f"WARN: Failed upload for post {post_id}")

        # 4. Link to community if ID provided (graph edge)
        if community_id is not None:
            crud.add_post_to_community_db(cursor, community_id, post_id)

        # 5. Fetch full post details for response
        post_relational = crud.get_post_by_id(cursor, post_id)
        if not post_relational: raise HTTPException(status_code=500, detail="Could not retrieve created post")
        created_post_data = dict(post_relational)
        # Augment (Author, Community, Counts, Media, Viewer Status)
        author_info = crud.get_user_by_id(cursor, created_post_data['user_id']);
        if author_info: created_post_data['author_name'] = author_info.get('username'); author_avatar_media = crud.get_user_profile_picture_media(cursor, created_post_data['user_id']); created_post_data['author_avatar_url'] = utils.get_minio_url(author_avatar_media.get('minio_object_name') if author_avatar_media else None)
        else: created_post_data['author_name'] = "Unknown"; created_post_data['author_avatar_url'] = None
        created_post_data['community_id'] = community_id
        created_post_data['community_name'] = comm_exists.get('name') if community_id and comm_exists else None # Use checked data
        try: counts = crud.get_post_counts(cursor, post_id); created_post_data.update(counts)
        except Exception as e: created_post_data.update({"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0})
        try:
            media_items = crud.get_media_items_for_post(cursor, post_id);
            processed_media = []
            for item in media_items: item_dict = dict(item); item_dict['url'] = utils.get_minio_url(item_dict.get('minio_object_name')); processed_media.append(schemas.MediaItemDisplay(**item_dict))
            created_post_data['media'] = processed_media
        except Exception as e: created_post_data['media'] = []
        created_post_data['viewer_vote_type'] = None; created_post_data['viewer_has_favorited'] = False; created_post_data.setdefault('upvotes', 0); created_post_data.setdefault('downvotes', 0); created_post_data.setdefault('reply_count', 0); created_post_data.setdefault('favorite_count', 0); created_post_data.setdefault('image_url', None)

        # Validate before commit & broadcast
        response_object = schemas.PostDisplay(**created_post_data)

        conn.commit()

        # 6. Broadcast WebSocket Event
        if community_id is not None:
            room_key = f"community_{community_id}"
            broadcast_payload = {"type": "new_post", "data": { "post_id": post_id, "community_id": community_id, "user_id": current_user_id, "title": title }}
            print(f"Broadcasting new post notification to room: {room_key}")
            try: # Wrap broadcast in try/except
                await manager.broadcast(json.dumps(broadcast_payload), room_key)
            except Exception as ws_err: print(f"WARN: Failed to broadcast new post to {room_key}: {ws_err}")
        else:
            print(f"New post {post_id} created (not in community), no broadcast target.")

        return response_object

    except HTTPException as http_exc:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        raise http_exc
    except psycopg2.Error as db_err:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        print(f"❌ DB Error creating post: {db_err} (Code: {db_err.pgcode})")
        raise HTTPException(status_code=500, detail=f"Database error: {db_err.pgerror or 'Unknown DB Error'}")
    except Exception as e:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        print(f"❌ Unexpected Error creating post: {repr(e)}")
        traceback.print_exc();
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

# --- DELETE /{post_id} ---
@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Deletes a post (requires ownership). Deletes from relational, graph, and associated media. """
    conn = None
    media_to_delete: List[Dict[str, Any]] = [] # Store media info before deleting post

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check ownership & get media info BEFORE deleting post
        post = crud.get_post_by_id(cursor, post_id)
        if not post: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
        if post["user_id"] != current_user_id: raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

        # Fetch associated media items
        media_to_delete = crud.get_media_items_for_post(cursor, post_id)
        print(f"Found {len(media_to_delete)} media items associated with post {post_id} for deletion.")

        # 2. Call the combined delete function (handles graph + relational)
        deleted = crud.delete_post_db(cursor, post_id)
        if not deleted:
            conn.rollback() # Should not happen if initial check passed
            raise HTTPException(status_code=404, detail="Post not found during deletion attempt")

        conn.commit() # Commit successful DB deletion of post and relational links (like post_media via CASCADE)

        # 3. Delete associated media items (DB records + MinIO files) AFTER commit
        if media_to_delete:
            print(f"Attempting post-delete cleanup for {len(media_to_delete)} media items...")
            for media_item in media_to_delete:
                media_id = media_item.get("id")
                minio_path = media_item.get("minio_object_name")
                if media_id:
                    await utils.delete_media_item_db_and_file(media_id, minio_path)
                elif minio_path: # If only path is known, try deleting file
                    utils.delete_from_minio(minio_path)


        print(f"✅ Post {post_id} deleted successfully by User {current_user_id}")
        return None

    except HTTPException as http_exc:
        if conn: conn.rollback(); raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback(); print(f"❌ SQL Error deleting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Database error during deletion")
    except Exception as e:
        if conn: conn.rollback(); print(f"❌ Unexpected Error deleting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Could not delete post")
    finally:
        if conn: conn.close()


# --- POST /{post_id}/favorite ---
@router.post("/{post_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def favorite_post(
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """Adds a post to the user's favorites."""
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Ensure post exists before favoriting
        post_check = crud.get_post_by_id(cursor, post_id)
        if not post_check: raise HTTPException(status_code=404, detail="Post not found")

        success = crud.add_favorite_db(cursor, user_id=current_user_id, post_id=post_id, reply_id=None)
        conn.commit()
        counts = crud.get_post_counts(cursor, post_id) # Get updated counts
        return {"message": "Post favorited successfully", "success": success, "new_counts": counts}
    except psycopg2.Error as e:
        if conn: conn.rollback(); print(f"❌ DB Error favoriting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Database error favoriting post")
    except HTTPException as http_exc:
        if conn: conn.rollback(); raise http_exc # Re-raise 404 etc.
    except Exception as e:
        if conn: conn.rollback(); print(f"❌ Error favoriting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Could not favorite post")
    finally:
        if conn: conn.close()

# --- DELETE /{post_id}/favorite ---
@router.delete("/{post_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def unfavorite_post(
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """Removes a post from the user's favorites."""
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        deleted = crud.remove_favorite_db(cursor, user_id=current_user_id, post_id=post_id, reply_id=None)
        conn.commit()
        counts = crud.get_post_counts(cursor, post_id) # Get updated counts
        return {"message": "Post unfavorited successfully" if deleted else "Post was not favorited", "success": deleted, "new_counts": counts}
    except psycopg2.Error as e:
        if conn: conn.rollback(); print(f"❌ DB Error unfavoriting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Database error unfavoriting post")
    except Exception as e:
        if conn: conn.rollback(); print(f"❌ Error unfavoriting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Could not unfavorite post")
    finally:
        if conn: conn.close()