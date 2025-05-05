# src/routers/replies.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, File, UploadFile, Query
from typing import List, Optional, Dict, Any
import psycopg2
import traceback
import json # For WebSocket payload

# Use the central crud import
from .. import schemas, crud, auth, utils, security
from ..database import get_db_connection
from ..utils import get_minio_url, delete_from_minio, delete_media_item_db_and_file
from ..connection_manager import manager # Import the WebSocket manager

router = APIRouter(
    prefix="/replies",
    tags=["Replies"],
    dependencies=[Depends(security.get_api_key)] # Apply API Key globally
)

@router.post("", status_code=status.HTTP_201_CREATED, response_model=schemas.ReplyDisplay)
async def create_reply(
        current_user_id: int = Depends(auth.get_current_user), # Require auth
        post_id: int = Form(...),
        content: str = Form(...),
        parent_reply_id: Optional[int] = Form(None),
        files: List[UploadFile] = File(default=[]) # Accept media files
):
    """ Creates a new reply with optional media. Broadcasts update via WebSocket. """
    conn = None
    reply_id = None
    media_ids_created = []
    minio_objects_created = []

    try:
        conn = get_db_connection(); cursor = conn.cursor()

        # Check if parent post exists
        parent_post_check = crud.get_post_by_id(cursor, post_id)
        if not parent_post_check:
            raise HTTPException(status_code=404, detail=f"Parent post {post_id} not found")

        # Check if parent reply exists (if provided)
        if parent_reply_id is not None:
            parent_reply_check = crud.get_reply_by_id(cursor, parent_reply_id)
            if not parent_reply_check:
                raise HTTPException(status_code=404, detail=f"Parent reply {parent_reply_id} not found")
            # Optional: Check if parent reply belongs to the same post_id
            if parent_reply_check.get('post_id') != post_id:
                raise HTTPException(status_code=400, detail="Parent reply does not belong to the specified post")

        # 1. Create reply base record (relational + graph)
        reply_id = crud.create_reply_db(
            cursor, post_id=post_id, user_id=current_user_id,
            content=content, parent_reply_id=parent_reply_id
        )
        if reply_id is None: raise HTTPException(status_code=500, detail="Reply base creation failed")

        # 2. Link Media
        for file in files:
            if file and file.filename:
                object_name_prefix = f"media/replies/{reply_id}"
                upload_info = await utils.upload_file_to_minio(file, object_name_prefix)
                if upload_info:
                    minio_objects_created.append(upload_info['minio_object_name'])
                    media_id = crud.create_media_item(cursor, uploader_user_id=current_user_id, **upload_info)
                    if media_id: media_ids_created.append(media_id); crud.link_media_to_reply(cursor, reply_id, media_id)
                    else: print(f"WARN: Failed media_item record for reply {reply_id}")
                else: print(f"WARN: Failed upload for reply {reply_id}")

        # 3. Fetch details for response
        created_reply_relational = crud.get_reply_by_id(cursor, reply_id)
        if not created_reply_relational: raise HTTPException(status_code=500, detail="Could not retrieve created reply")
        created_reply_data = dict(created_reply_relational)
        # Augment (Author, Counts, Media)
        author_info = crud.get_user_by_id(cursor, created_reply_data['user_id'])
        if author_info: created_reply_data['author_name']=author_info.get('username'); author_avatar_media = crud.get_user_profile_picture_media(cursor, created_reply_data['user_id']); created_reply_data['author_avatar_url'] = utils.get_minio_url(author_avatar_media.get('minio_object_name') if author_avatar_media else None)
        else: created_reply_data['author_name'] = "Unknown"; created_reply_data['author_avatar_url'] = None
        try: counts = crud.get_reply_counts(cursor, reply_id); created_reply_data.update(counts)
        except Exception as e: print(f"WARN create_reply: Failed counts R:{reply_id}: {e}"); created_reply_data.update({"upvotes": 0, "downvotes": 0, "favorite_count": 0})
        try:
            media_items = crud.get_media_items_for_reply(cursor, reply_id)
            processed_media = []
            for item in media_items: item_dict = dict(item); item_dict['url'] = utils.get_minio_url(item_dict.get('minio_object_name')); processed_media.append(schemas.MediaItemDisplay(**item_dict))
            created_reply_data['media'] = processed_media
        except Exception as e: print(f"WARN create_reply: Failed media R:{reply_id}: {e}"); created_reply_data['media'] = []
        created_reply_data['viewer_vote_type'] = None; created_reply_data['viewer_has_favorited'] = False; created_reply_data.setdefault('upvotes', 0); created_reply_data.setdefault('downvotes', 0); created_reply_data.setdefault('favorite_count', 0)

        # Validate response object
        response_object = schemas.ReplyDisplay(**created_reply_data)

        conn.commit()

        # --- 4. Broadcast WebSocket Event ---
        room_key = None
        community_id_for_broadcast = None # Store community ID if found
        try:
            cypher_q_comm = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {post_id}}}) RETURN c.id as id LIMIT 1"
            expected_comm = [('id', 'agtype')]
            comm_res = crud.execute_cypher(cursor, cypher_q_comm, fetch_one=True, expected_columns=expected_comm)
            if comm_res and comm_res.get('id'):
                community_id_for_broadcast = comm_res['id']
                room_key = f"community_{community_id_for_broadcast}"
            # TODO: Else check if post belongs to an event?
        except Exception as e: print(f"WARN: Failed to determine room key for post {post_id} during reply broadcast: {e}")

        if room_key:
            broadcast_payload = {
                "type": "new_reply",
                "data": {
                    "post_id": post_id,
                    "reply_id": reply_id,
                    "parent_reply_id": parent_reply_id,
                    "user_id": current_user_id,
                    "community_id": community_id_for_broadcast, # Include context
                    "content_snippet": content[:50] + ('...' if len(content)>50 else '')
                }
            }
            print(f"Broadcasting new reply notification to room: {room_key}")
            try: await manager.broadcast(json.dumps(broadcast_payload), room_key)
            except Exception as ws_err: print(f"WARN: Failed to broadcast new reply to {room_key}: {ws_err}")
        else: print(f"No specific room key found for post {post_id}, cannot broadcast reply {reply_id}.")
        # --- End Broadcast ---

        print(f"✅ Reply {reply_id} created by User {current_user_id} for Post {post_id}")
        return response_object

    except HTTPException as http_exc:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        print(f"❌ DB Error creating reply: {e} (Code: {e.pgcode})")
        detail = f"Database error: {e.pgerror or 'Unknown DB Error'}"
        if e.pgcode == '23503': detail = "Invalid post_id or parent_reply_id provided."
        raise HTTPException(status_code=400, detail=detail)
    except Exception as e:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        print(f"❌ Unexpected Error creating reply: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()


@router.get("/{post_id}", response_model=List[schemas.ReplyDisplay])
async def get_replies_for_post(
        post_id: int,
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    """ Fetches replies for a post, including media and viewer status. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Fetches relational data + graph counts + author info
        replies_db = crud.get_replies_for_post_db(cursor, post_id)

        processed_replies = []
        for reply in replies_db:
            reply_data = dict(reply)
            reply_id = reply_data['id']

            # Generate author avatar URL
            author_avatar_path = reply.get('author_avatar') # Path comes from CRUD func
            reply_data['author_avatar_url'] = utils.get_minio_url(author_avatar_path)

            # Fetch and Attach Media
            try:
                media_items = crud.get_media_items_for_reply(cursor, reply_id)
                reply_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items ]
            except Exception as e: print(f"WARN GET /replies: Failed fetching media for reply {reply_id}: {e}"); reply_data['media'] = []

            # Get viewer status
            viewer_vote = None; is_favorited = False
            if current_user_id is not None:
                try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=None, reply_id=reply_id)
                except Exception as e: print(f"WARN GET /replies: vote status check failed R:{reply_id}: {e}")
                try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=None, reply_id=reply_id)
                except Exception as e: print(f"WARN GET /replies: fav status check failed R:{reply_id}: {e}")
            reply_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
            reply_data['viewer_has_favorited'] = is_favorited

            # Ensure defaults
            reply_data.setdefault('upvotes', 0); reply_data.setdefault('downvotes', 0); reply_data.setdefault('favorite_count', 0); reply_data.setdefault('media', [])

            try:
                processed_replies.append(schemas.ReplyDisplay(**reply_data))
            except Exception as pydantic_err:
                print(f"ERROR: Pydantic validation failed for reply {reply_id} in post {post_id}: {pydantic_err}\nData: {reply_data}")

        print(f"✅ Fetched {len(processed_replies)} replies for post {post_id}")
        return processed_replies

    except psycopg2.Error as db_err:
        print(f"DB Error GET /replies/{post_id}: {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching replies")
    except Exception as e:
        print(f"❌ Error fetching replies for post {post_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Error fetching replies")
    finally:
        if conn: conn.close()


@router.delete("/{reply_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_reply(
        reply_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Deletes a reply (requires ownership). Deletes relational, graph, and associated media. """
    conn = None
    media_to_delete: List[Dict[str, Any]] = []
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check ownership & get media info BEFORE deleting reply
        reply = crud.get_reply_by_id(cursor, reply_id)
        if not reply: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reply not found")
        if reply["user_id"] != current_user_id: raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

        media_to_delete = crud.get_media_items_for_reply(cursor, reply_id)
        print(f"Found {len(media_to_delete)} media items associated with reply {reply_id} for deletion.")

        # 2. Delete reply (handles relational + graph)
        deleted = crud.delete_reply_db(cursor, reply_id)
        if not deleted: conn.rollback(); raise HTTPException(status_code=404, detail="Reply not found during deletion")

        conn.commit()

        # 3. Delete associated media items (DB records + MinIO files) AFTER commit
        if media_to_delete:
            print(f"Attempting post-delete cleanup for {len(media_to_delete)} media items...")
            for media_item in media_to_delete:
                media_id = media_item.get("id")
                minio_path = media_item.get("minio_object_name")
                if media_id:
                    # Use the synchronous helper
                    utils.delete_media_item_db_and_file(media_id, minio_path)
                elif minio_path:
                    utils.delete_from_minio(minio_path)

        print(f"✅ Reply {reply_id} deleted successfully by User {current_user_id}")
        return None

    except HTTPException as http_exc:
        if conn: conn.rollback(); raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback(); print(f"❌ SQL Error deleting reply {reply_id}: {e}"); raise HTTPException(status_code=500, detail="Database error during deletion")
    except Exception as e:
        if conn: conn.rollback(); print(f"❌ Unexpected Error deleting reply {reply_id}: {e}"); raise HTTPException(status_code=500, detail="Could not delete reply")
    finally:
        if conn: conn.close()

# --- Favorite/Unfavorite Reply Endpoints ---

@router.post("/{reply_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def favorite_reply(
        reply_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """Adds a reply to the user's favorites."""
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Ensure reply exists
        reply_check = crud.get_reply_by_id(cursor, reply_id)
        if not reply_check: raise HTTPException(status_code=404, detail="Reply not found")

        success = crud.add_favorite_db(cursor, user_id=current_user_id, post_id=None, reply_id=reply_id)
        conn.commit()
        counts = crud.get_reply_counts(cursor, reply_id)
        return {"message": "Reply favorited successfully", "success": success, "new_counts": counts}
    except psycopg2.Error as e:
        if conn: conn.rollback(); print(f"❌ DB Error favoriting reply {reply_id}: {e}"); raise HTTPException(status_code=500, detail="Database error favoriting reply")
    except HTTPException as http_exc:
        if conn: conn.rollback(); raise http_exc
    except Exception as e:
        if conn: conn.rollback(); print(f"❌ Error favoriting reply {reply_id}: {e}"); raise HTTPException(status_code=500, detail="Could not favorite reply")
    finally:
        if conn: conn.close()


@router.delete("/{reply_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def unfavorite_reply(
        reply_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """Removes a reply from the user's favorites."""
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        deleted = crud.remove_favorite_db(cursor, user_id=current_user_id, post_id=None, reply_id=reply_id)
        conn.commit()
        counts = crud.get_reply_counts(cursor, reply_id)
        return {"message": "Reply unfavorited successfully" if deleted else "Reply was not favorited", "success": deleted, "new_counts": counts}
    except psycopg2.Error as e:
        if conn: conn.rollback(); print(f"❌ DB Error unfavoriting reply {reply_id}: {e}"); raise HTTPException(status_code=500, detail="Database error unfavoriting reply")
    except Exception as e:
        if conn: conn.rollback(); print(f"❌ Error unfavoriting reply {reply_id}: {e}"); raise HTTPException(status_code=500, detail="Could not unfavorite reply")
    finally:
        if conn: conn.close()