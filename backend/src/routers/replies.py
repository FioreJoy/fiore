# backend/src/routers/replies.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, File, UploadFile, Query
from typing import List, Optional, Dict, Any
import psycopg2
import traceback
import json

from .. import schemas, crud, auth, utils, security
from ..database import get_db_connection
from ..utils import get_minio_url, delete_from_minio, delete_media_item_db_and_file

# REMOVE old manager: from ..connection_manager import manager
# INSTEAD, import 'sio' from socketio_manager for broadcasting
from ..socketio_manager import sio

router = APIRouter(
    prefix="/replies",
    tags=["Replies"],
    dependencies=[Depends(security.get_api_key)]
)

@router.post("", status_code=status.HTTP_201_CREATED, response_model=schemas.ReplyDisplay)
async def create_reply(
        current_user_id: int = Depends(auth.get_current_user),
        post_id: int = Form(...),
        content: str = Form(...),
        parent_reply_id: Optional[int] = Form(None),
        files: List[UploadFile] = File(default=[])
):
    conn = None; reply_id = None; media_ids_created = []; minio_objects_created = []
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        parent_post_db = crud.get_post_by_id(cursor, post_id)
        if not parent_post_db: raise HTTPException(status_code=404, detail=f"Parent post {post_id} not found")
        parent_post_author_id = parent_post_db['user_id']
        parent_reply_author_id = None
        if parent_reply_id is not None:
            parent_reply_db = crud.get_reply_by_id(cursor, parent_reply_id)
            if not parent_reply_db: raise HTTPException(status_code=404, detail=f"Parent reply {parent_reply_id} not found")
            if parent_reply_db.get('post_id') != post_id: raise HTTPException(status_code=400, detail="Parent reply belongs to a different post")
            parent_reply_author_id = parent_reply_db['user_id']

        reply_id = crud.create_reply_db(cursor, post_id=post_id, user_id=current_user_id, content=content, parent_reply_id=parent_reply_id)
        if reply_id is None: raise HTTPException(status_code=500, detail="Reply base creation failed")

        media_items_for_response_db = []
        if files:
            for file_upload in files:
                if file_upload and file_upload.filename:
                    object_name_prefix = f"media/replies/{reply_id}"
                    upload_info = await utils.upload_file_to_minio(file_upload, object_name_prefix)
                    if upload_info:
                        minio_objects_created.append(upload_info['minio_object_name'])
                        media_id_db = crud.create_media_item(cursor, uploader_user_id=current_user_id, **upload_info)
                        if media_id_db:
                            media_ids_created.append(media_id_db); crud.link_media_to_reply(cursor, reply_id, media_id_db)
                            media_item_for_resp = crud.get_media_item_by_id(cursor, media_id_db)
                            if media_item_for_resp: media_items_for_response_db.append(media_item_for_resp)
                        else: print(f"WARN: Failed media_item record for reply {reply_id}")
                    else: print(f"WARN: Failed upload for reply {reply_id}")

        content_preview = content[:100] + ('...' if len(content) > 100 else '')
        actor_user_info = crud.get_user_by_id(cursor, current_user_id)
        actor_username = actor_user_info.get('username', 'Someone') if actor_user_info else 'Someone'

        if parent_post_author_id != current_user_id:
            crud.create_notification(cursor=cursor, recipient_user_id=parent_post_author_id, actor_user_id=current_user_id, type='post_reply', related_entity_type='post', related_entity_id=post_id, content_preview=f"{actor_username} replied: \"{content_preview}\"")
        if parent_reply_author_id is not None and parent_reply_author_id != current_user_id and parent_reply_author_id != parent_post_author_id:
            crud.create_notification(cursor=cursor, recipient_user_id=parent_reply_author_id, actor_user_id=current_user_id, type='reply_reply', related_entity_type='reply', related_entity_id=parent_reply_id, content_preview=f"{actor_username} also replied: \"{content_preview}\"")

        created_reply_relational = crud.get_reply_by_id(cursor, reply_id)
        if not created_reply_relational: raise HTTPException(status_code=500, detail="Could not retrieve created reply")
        created_reply_data = dict(created_reply_relational)
        author_info = crud.get_user_by_id(cursor, created_reply_data['user_id'])
        if author_info:
            created_reply_data['author_name']=author_info.get('username')
            author_avatar_media = crud.get_user_profile_picture_media(cursor, created_reply_data['user_id'])
            created_reply_data['author_avatar_url'] = utils.get_minio_url(author_avatar_media.get('minio_object_name') if author_avatar_media else None)
        else: created_reply_data['author_name'] = "Unknown"; created_reply_data['author_avatar_url'] = None

        try: counts = crud.get_reply_counts(cursor, reply_id); created_reply_data.update(counts)
        except Exception as e: created_reply_data.update({"upvotes": 0, "downvotes": 0, "favorite_count": 0})

        created_reply_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items_for_response_db ]
        created_reply_data['viewer_vote_type'] = None; created_reply_data['viewer_has_favorited'] = False

        response_object = schemas.ReplyDisplay(**created_reply_data)
        conn.commit()

        # Broadcast via Socket.IO
        if sio:
            community_id_for_broadcast = None
            # Determine the community_id from the post_id to find the room
            temp_conn_sio_replies, temp_cursor_sio_replies = None, None
            try:
                temp_conn_sio_replies, temp_cursor_sio_replies = get_db_connection(), None # Short-lived for this check
                temp_cursor_sio_replies = temp_conn_sio_replies.cursor()
                cypher_q_comm_reply = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {post_id}}}) RETURN c.id as id LIMIT 1"; expected_comm_reply = [('id', 'agtype')]
                comm_res_reply = crud.execute_cypher(temp_cursor_sio_replies, cypher_q_comm_reply, fetch_one=True, expected_columns=expected_comm_reply)
                if comm_res_reply and comm_res_reply.get('id'): community_id_for_broadcast = comm_res_reply['id']
            except Exception as e_room_reply: print(f"REPLIES ROUTER WARN: Failed to get community for reply broadcast: {e_room_reply}")
            finally:
                if temp_cursor_sio_replies: temp_cursor_sio_replies.close()
                if temp_conn_sio_replies: temp_conn_sio_replies.close()

            if community_id_for_broadcast:
                target_room_key_reply = f"community_{community_id_for_broadcast}"
                payload_reply_emit = json.loads(response_object.model_dump_json(exclude_none=True))
                # Add post_id explicitly if not already perfectly in response_object structure for client's new_reply event
                payload_reply_emit.setdefault('post_id', post_id)
                payload_reply_emit.setdefault('community_id', community_id_for_broadcast) # So client knows which community feed to update

                print(f"REPLIES ROUTER: Broadcasting new reply {reply_id} to {target_room_key_reply}")
                try:
                    await sio.emit('new_reply', payload_reply_emit, room=target_room_key_reply)
                except Exception as sio_emit_err_reply:
                    print(f"REPLIES ROUTER ERROR: Failed Socket.IO broadcast for new reply: {sio_emit_err_reply}")

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
        print(f"❌ Unexpected Error creating reply: {e}"); traceback.print_exc();
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()


# Remaining router functions (GET /replies/{post_id}, DELETE /replies/{reply_id}, POST/DELETE favorite)
# do not need WebSocket broadcasting and can remain as they were (assuming their CRUD calls are correct).
# GET replies - for fetching history.
@router.get("/{post_id}", response_model=List[schemas.ReplyDisplay])
async def get_replies_for_post(
        post_id: int,
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        replies_db = crud.get_replies_for_post_db(cursor, post_id)
        processed_replies = []
        for reply in replies_db:
            reply_data = dict(reply); reply_id_int = reply_data['id']
            author_avatar_path = reply.get('author_avatar')
            reply_data['author_avatar_url'] = utils.get_minio_url(author_avatar_path)
            try:
                media_items = crud.get_media_items_for_reply(cursor, reply_id_int)
                reply_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items ]
            except Exception as e: print(f"WARN GET /replies: Failed fetching media for reply {reply_id_int}: {e}"); reply_data['media'] = []
            viewer_vote = None; is_favorited = False
            if current_user_id is not None:
                try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=None, reply_id=reply_id_int)
                except Exception as e: print(f"WARN GET /replies: vote status check failed R:{reply_id_int}: {e}")
                try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=None, reply_id=reply_id_int)
                except Exception as e: print(f"WARN GET /replies: fav status check failed R:{reply_id_int}: {e}")
            reply_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
            reply_data['viewer_has_favorited'] = is_favorited
            reply_data.setdefault('upvotes', 0); reply_data.setdefault('downvotes', 0); reply_data.setdefault('favorite_count', 0); reply_data.setdefault('media', [])
            try: processed_replies.append(schemas.ReplyDisplay(**reply_data))
            except Exception as pydantic_err: print(f"ERROR: Pydantic for reply {reply_id_int} in post {post_id}: {pydantic_err}\nData: {reply_data}")
        return processed_replies
    except psycopg2.Error as db_err: print(f"DB Error GET /replies/{post_id}: {db_err}"); raise HTTPException(status_code=500, detail="Database error fetching replies")
    except Exception as e: print(f"❌ Error fetching replies for post {post_id}: {e}"); traceback.print_exc(); raise HTTPException(status_code=500, detail="Error fetching replies")
    finally:
        if conn: conn.close()

# DELETE reply
@router.delete("/{reply_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_reply( reply_id: int, current_user_id: int = Depends(auth.get_current_user) ):
    conn = None; media_to_delete_reply: List[Dict[str, Any]] = []
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        reply = crud.get_reply_by_id(cursor, reply_id)
        if not reply: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reply not found")
        if reply["user_id"] != current_user_id: raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
        media_to_delete_reply = crud.get_media_items_for_reply(cursor, reply_id)
        deleted = crud.delete_reply_db(cursor, reply_id)
        if not deleted: conn.rollback(); raise HTTPException(status_code=404, detail="Reply not found during deletion")
        conn.commit()
        if media_to_delete_reply:
            for media_item in media_to_delete_reply:
                utils.delete_media_item_db_and_file(media_item.get("id"), media_item.get("minio_object_name"))
        # Possibility to emit 'reply_deleted' event via Socket.IO to the room
        # target_room_key_delete_reply = f"community_{community_id_where_post_was}" (requires fetching this)
        # await sio.emit('reply_deleted', {'reply_id': reply_id, 'post_id': reply['post_id']}, room=target_room_key_delete_reply)
        return None
    except HTTPException as http_exc:
        if conn: conn.rollback(); raise http_exc
    except Exception as e:
        if conn: conn.rollback(); print(f"❌ Error deleting reply {reply_id}: {e}"); raise HTTPException(status_code=500, detail="Could not delete reply")
    finally:
        if conn: conn.close()

# Favorite/Unfavorite - these don't typically have wide broadcasts, only affect counts which client might refetch or get via specific 'counts_updated' event.
@router.post("/{reply_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def favorite_reply( reply_id: int, current_user_id: int = Depends(auth.get_current_user)):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        reply_check = crud.get_reply_by_id(cursor, reply_id)
        if not reply_check: raise HTTPException(status_code=404, detail="Reply not found")
        success = crud.add_favorite_db(cursor, user_id=current_user_id, post_id=None, reply_id=reply_id)
        conn.commit()
        counts = crud.get_reply_counts(cursor, reply_id)
        return {"message": "Reply favorited successfully", "success": success, "new_counts": counts}
    except Exception as e:
        if conn: conn.rollback(); raise HTTPException(status_code=500, detail=f"Could not favorite reply: {e}") from e
    finally:
        if conn: conn.close()

@router.delete("/{reply_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def unfavorite_reply( reply_id: int, current_user_id: int = Depends(auth.get_current_user)):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        deleted = crud.remove_favorite_db(cursor, user_id=current_user_id, post_id=None, reply_id=reply_id)
        conn.commit()
        counts = crud.get_reply_counts(cursor, reply_id)
        return {"message": "Reply unfavorited successfully" if deleted else "Reply not favorited", "success": deleted, "new_counts": counts}
    except Exception as e:
        if conn: conn.rollback(); raise HTTPException(status_code=500, detail=f"Could not unfavorite reply: {e}") from e
    finally:
        if conn: conn.close()