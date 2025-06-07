# backend/src/graphql/resolvers/mutations/reply.py
import strawberry
from typing import Optional, List, Dict, Any
import psycopg2
import traceback
import json
from strawberry.types import Info

from .... import crud, utils, schemas, auth
from ....database import get_db_connection
# Correct import path for sio from socketio_manager (which is one level up from src/graphql)
from ....socketio_manager import sio
# get_sio_db_conn_cursor is now internal to socketio_manager and socketio_handlers.
# If GQL needs direct DB access NOT via existing CRUD for some SIO-related task (unlikely),
# it should use get_db_connection directly. For sio.emit, it just needs 'sio'.

from ...types import ReplyType, ReplyCreateInput, MediaItemDisplay
from ...mappings import map_db_reply_to_gql_reply

from .common import _get_authenticated_user_id, _commit_and_fetch_reply_gql

def media_item_to_dict(media: MediaItemDisplay) -> Dict[str, Any]:
    return {
        "id": str(media.id), "url": media.url, "mime_type": media.mime_type,
        "file_size_bytes": media.file_size_bytes, "original_filename": media.original_filename,
        "width": media.width, "height": media.height, "duration_seconds": media.duration_seconds,
        "created_at": media.created_at.isoformat()
    }

async def create_reply_resolver(info: Info, reply_input: ReplyCreateInput) -> ReplyType:
    user_id = _get_authenticated_user_id(info)
    conn = None; reply_id_int = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # ... (validation and DB creation logic for reply and notifications -UNCHANGED from your correct previous version) ...
        parent_post = crud.get_post_by_id(cursor, reply_input.post_id)
        if not parent_post: raise ValueError(f"Parent post {reply_input.post_id} not found.")
        parent_post_author_id = parent_post['user_id']
        parent_reply_author_id = None
        if reply_input.parent_reply_id:
            parent_reply_check = crud.get_reply_by_id(cursor, reply_input.parent_reply_id)
            if not parent_reply_check: raise ValueError(f"Parent reply {reply_input.parent_reply_id} not found.")
            if parent_reply_check.get('post_id') != reply_input.post_id: raise ValueError("Parent reply belongs to different post.")
            parent_reply_author_id = parent_reply_check['user_id']

        reply_id_int = crud.create_reply_db(
            cursor, post_id=reply_input.post_id, user_id=user_id,
            content=reply_input.content, parent_reply_id=reply_input.parent_reply_id
        )
        if not reply_id_int: raise Exception("Failed to create reply record in DB.")

        content_preview = reply_input.content[:50] + ('...' if len(reply_input.content) > 50 else '')
        actor_info_for_notif = crud.get_user_by_id(cursor, user_id)
        actor_username_for_notif = actor_info_for_notif.get('username', 'User') if actor_info_for_notif else 'User'

        if parent_post_author_id != user_id:
            crud.create_notification(cursor, parent_post_author_id, 'post_reply', actor_user_id=user_id,
                                     related_entity_type='post', related_entity_id=reply_input.post_id,
                                     content_preview=f"{actor_username_for_notif} replied: \"{content_preview}\"")
        if parent_reply_author_id and parent_reply_author_id != user_id and parent_reply_author_id != parent_post_author_id:
            crud.create_notification(cursor, parent_reply_author_id, 'reply_reply', actor_user_id=user_id,
                                     related_entity_type='reply', related_entity_id=reply_input.parent_reply_id,
                                     content_preview=f"{actor_username_for_notif} also replied: \"{content_preview}\"")

        created_reply_gql = await _commit_and_fetch_reply_gql(conn, info, reply_id_int)
        # conn is committed by the helper above.

        if sio:
            community_id_for_broadcast = None
            temp_conn_broadcast, temp_cursor_broadcast = None, None
            try:
                temp_conn_broadcast, temp_cursor_broadcast = get_db_connection(), None # Using FastAPI's get_db_connection
                temp_cursor_broadcast = temp_conn_broadcast.cursor()
                # Corrected: Using `execute_cypher` from `crud` which means `crud._graph.execute_cypher`
                cypher_q_comm_reply = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {reply_input.post_id}}}) RETURN c.id as id LIMIT 1"
                comm_res_reply = crud.execute_cypher(temp_cursor_broadcast, cypher_q_comm_reply, fetch_one=True, expected_columns=[('id', 'agtype')])
                if comm_res_reply and comm_res_reply.get('id'): community_id_for_broadcast = comm_res_reply['id']
            except Exception as e_room: print(f"GQL CreateReply WARN: Failed to get room for broadcast: {e_room}")
            finally:
                if temp_cursor_broadcast: temp_cursor_broadcast.close()
                if temp_conn_broadcast: temp_conn_broadcast.close()

            if community_id_for_broadcast:
                target_room_key_reply = f"community_{community_id_for_broadcast}"
                author_details_reply_bc = None
                if info.context and 'user_loader' in info.context:
                    author_details_reply_bc = await info.context['user_loader'].load(created_reply_gql.author_id)

                # Construct broadcast payload (as before)
                broadcast_payload_reply_dict = {
                    "id": str(created_reply_gql.id), "content": created_reply_gql.content,
                    "created_at": created_reply_gql.created_at.isoformat(), "author_id": created_reply_gql.author_id,
                    "post_id": created_reply_gql.post_id, "parent_reply_id": created_reply_gql.parent_reply_id,
                    "upvotes": created_reply_gql.upvotes, "downvotes": created_reply_gql.downvotes,
                    "favorite_count": created_reply_gql.favorite_count,
                    "author_name": author_details_reply_bc.username if author_details_reply_bc else "User",
                    "author_avatar_url": author_details_reply_bc.image_url if author_details_reply_bc else None,
                    "media": [media_item_to_dict(m) for m in created_reply_gql.media] if hasattr(created_reply_gql, 'media') and created_reply_gql.media else [],
                    "community_id": community_id_for_broadcast
                }
                await sio.emit('new_reply', broadcast_payload_reply_dict, room=target_room_key_reply)
                print(f"GQL CreateReply: Broadcasted new reply {reply_id_int} to {target_room_key_reply}")
        return created_reply_gql
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn and not conn.closed and conn.status == psycopg2.extensions.STATUS_IN_TRANSACTION: conn.rollback()
        print(f"Error in GQL create_reply_resolver: {e}"); traceback.print_exc()
        raise Exception(f"Could not create reply: {str(e)[:200]}") from e
    finally:
        if conn and not conn.closed: conn.close()

async def delete_reply_resolver(info: Info, reply_id: strawberry.ID) -> bool:
    # ... (Implementation of delete_reply_resolver is same, no sio specific changes needed usually for delete)
    user_id = _get_authenticated_user_id(info)
    conn = None; media_to_delete_reply = []
    try:
        reply_id_int = int(reply_id)
        conn = get_db_connection(); cursor = conn.cursor()
        reply_db = crud.get_reply_by_id(cursor, reply_id_int)
        if not reply_db: raise ValueError("Reply not found.")
        if reply_db["user_id"] != user_id: raise ValueError("Not authorized to delete this reply.")

        media_to_delete_reply = crud.get_media_items_for_reply(cursor, reply_id_int)
        deleted = crud.delete_reply_db(cursor, reply_id_int)
        if not deleted: raise Exception("Reply deletion DB operation failed.")
        conn.commit()

        for item_media in media_to_delete_reply:
            utils.delete_media_item_db_and_file(item_media.get("id"), item_media.get("minio_object_name"))
        return True
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not delete reply: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()