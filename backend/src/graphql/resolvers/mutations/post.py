# backend/src/graphql/resolvers/mutations/post.py
import strawberry
from typing import Optional, List, Dict, Any
import psycopg2
import traceback
import json
from strawberry.types import Info

# Assuming this file is src/graphql/resolvers/mutations/post.py
from .... import crud, utils, schemas, auth # Up four levels to src
from ....database import get_db_connection    # Up four levels to src
from ....socketio_manager import sio           # Up three levels to src, then socketio_manager

from ...types import ( # Up two levels to src/graphql/types.py
    PostType, PostCreateInput, PostUpdateInput, MediaItemDisplay
)
from ...mappings import map_db_post_to_gql_post # Up two levels for mappings

from .common import _get_authenticated_user_id, _commit_and_fetch_post_gql # Sibling common.py

# --- Mutation Resolvers for Posts ---

async def create_post_resolver(info: Info, post_input: PostCreateInput) -> PostType:
    user_id = _get_authenticated_user_id(info)
    conn = None; post_id_int = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        comm_exists = None
        if post_input.community_id:
            comm_exists = crud.get_community_by_id(cursor, post_input.community_id)
            if not comm_exists: raise ValueError(f"Community {post_input.community_id} not found.")

        post_id_int = crud.create_post_db(cursor, user_id=user_id, title=post_input.title, content=post_input.content)
        if not post_id_int: raise Exception("Failed to create post record.")

        if post_input.community_id and comm_exists: # Ensure comm_exists before using its properties
            crud.add_post_to_community_db(cursor, post_input.community_id, post_id_int)

        created_post_gql = await _commit_and_fetch_post_gql(conn, info, post_id_int) # Commits and fetches full GQL PostType
        # The created_post_gql object now holds the full data ready for broadcast

        if post_input.community_id and comm_exists and sio:
            target_room_key = f"community_{post_input.community_id}"
            # Prepare a simplified broadcast payload if PostType has complex nested objects not suitable for direct emit
            # or use strawberry.asdict if careful about its output
            author_details_for_broadcast = await info.context['user_loader'].load(created_post_gql.author_id)

            broadcast_payload = {
                "id": str(created_post_gql.id), "title": created_post_gql.title, "content": created_post_gql.content,
                "created_at": created_post_gql.created_at.isoformat(), "author_id": created_post_gql.author_id,
                "community_id": created_post_gql.community_id,
                "reply_count": created_post_gql.reply_count, "upvotes": created_post_gql.upvotes,
                "downvotes": created_post_gql.downvotes, "favorite_count": created_post_gql.favorite_count,
                "author_name": author_details_for_broadcast.username if author_details_for_broadcast else "User",
                "author_avatar_url": author_details_for_broadcast.image_url if author_details_for_broadcast else None,
                "community_name": comm_exists.get('name') if comm_exists else None,
                "media": [media_item_to_dict(m) for m in created_post_gql.media] if hasattr(created_post_gql, 'media') and created_post_gql.media else []
            }
            try:
                await sio.emit('new_post', broadcast_payload, room=target_room_key)
                print(f"GQL CreatePost: Broadcasted new post {post_id_int} to {target_room_key}")
            except Exception as sio_emit_err:
                print(f"GQL WARN: Failed WS broadcast for new post {post_id_int}: {sio_emit_err}")

        return created_post_gql
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback()
        print(f"Error in GQL create_post_resolver: {e}"); traceback.print_exc()
        raise Exception(f"Could not create post: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

async def update_post_resolver(info: Info, post_id: strawberry.ID, post_input: PostUpdateInput) -> Optional[PostType]:
    user_id = _get_authenticated_user_id(info)
    conn = None
    post_id_int = int(post_id)

    # Convert Strawberry input to dict, excluding UNSET values
    update_data_dict = {
        field.name: getattr(post_input, field.name)
        for field in strawberry.fields(PostUpdateInput) # type: ignore
        if hasattr(post_input, field.name) and getattr(post_input, field.name) != strawberry.UNSET
    }

    if not update_data_dict: raise ValueError("No update data provided.")

    try:
        conn = get_db_connection(); cursor = conn.cursor()
        post_db = crud.get_post_by_id(cursor, post_id_int)
        if not post_db: raise ValueError("Post not found.")
        if post_db["user_id"] != user_id: raise ValueError("Not authorized to update this post.")

        # CRUD function for updating posts needed
        # success = crud.update_post_db(cursor, post_id_int, update_data_dict)
        # For now, doing it directly if simple text fields:
        set_clauses = []
        params_update = []
        if 'title' in update_data_dict: set_clauses.append("title = %s"); params_update.append(update_data_dict['title'])
        if 'content' in update_data_dict: set_clauses.append("content = %s"); params_update.append(update_data_dict['content'])

        if not set_clauses: raise ValueError("No valid fields to update.")

        params_update.append(post_id_int)
        sql_update = f"UPDATE public.posts SET {', '.join(set_clauses)} WHERE id = %s"
        cursor.execute(sql_update, tuple(params_update))
        if cursor.rowcount == 0: raise Exception("Post update failed (post not found or no change).")

        # Also update graph node if title changed (content not usually on graph node)
        if 'title' in update_data_dict:
            crud.execute_cypher(cursor, f"MATCH (p:Post {{id: {post_id_int}}}) SET p.title = {utils.quote_cypher_string(update_data_dict['title'])}")

        updated_post_gql = await _commit_and_fetch_post_gql(conn, info, post_id_int)
        # TODO: Consider broadcasting 'post_updated' event if necessary
        return updated_post_gql
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback()
        raise Exception(f"Could not update post: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

async def delete_post_resolver(info: Info, post_id: strawberry.ID) -> bool:
    user_id = _get_authenticated_user_id(info)
    conn = None; media_to_delete = []
    try:
        post_id_int = int(post_id)
        conn = get_db_connection(); cursor = conn.cursor()
        post = crud.get_post_by_id(cursor, post_id_int);
        if not post: raise ValueError("Post not found.")
        if post["user_id"] != user_id: raise ValueError("Not authorized.")

        # Determine community for broadcast BEFORE deleting post data
        community_id_for_broadcast = None
        try:
            cypher_q_comm_del = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {post_id_int}}}) RETURN c.id as id LIMIT 1"
            comm_res_del = crud.execute_cypher(cursor, cypher_q_comm_del, fetch_one=True, expected_columns=[('id', 'agtype')])
            if comm_res_del and comm_res_del.get('id'): community_id_for_broadcast = comm_res_del['id']
        except Exception as e: print(f"GQL DeletePost WARN: Failed to get community for broadcast: {e}")

        media_to_delete = crud.get_media_items_for_post(cursor, post_id_int)
        deleted = crud.delete_post_db(cursor, post_id_int)
        if not deleted: raise Exception("Post deletion DB operation failed.")
        conn.commit()

        # Delete associated media files from MinIO after successful DB commit
        for item in media_to_delete:
            utils.delete_media_item_db_and_file(item.get("id"), item.get("minio_object_name"))

        # Broadcast 'post_deleted' event if applicable
        if community_id_for_broadcast and sio:
            target_room_key_delete = f"community_{community_id_for_broadcast}"
            await sio.emit('post_deleted', {'post_id': str(post_id_int), 'community_id': community_id_for_broadcast}, room=target_room_key_delete)
            print(f"GQL DeletePost: Broadcasted post_deleted {post_id_int} to {target_room_key_delete}")

        return True
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not delete post: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

# Helper for broadcast payload (should match client expectations for MediaItemDisplay)
def media_item_to_dict(media: MediaItemDisplay) -> Dict[str, Any]:
    return {
        "id": str(media.id),
        "url": media.url,
        "mime_type": media.mime_type,
        "file_size_bytes": media.file_size_bytes,
        "original_filename": media.original_filename,
        "width": media.width,
        "height": media.height,
        "duration_seconds": media.duration_seconds,
        "created_at": media.created_at.isoformat()
    }