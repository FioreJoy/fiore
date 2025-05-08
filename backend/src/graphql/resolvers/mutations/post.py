# src/graphql/resolvers/mutations/post.py
import strawberry
from typing import Optional, List, Dict, Any
import psycopg2
import traceback
import json
from strawberry.types import Info

# --- Imports ---
# Use relative imports to access types, mappings etc. from ../../
from .... import crud, utils, schemas, auth
from ....database import get_db_connection
from ...types import ( # Import GQL Types and Inputs
    PostType, PostCreateInput, PostUpdateInput, MediaItemDisplay
)
from ...mappings import map_db_post_to_gql_post # Import relevant mapper
# Import Query resolvers if needed to fetch full objects after mutation
from ..query import get_post_resolver
from ....connection_manager import manager as ws_manager # Import manager

# Import auth helper
from .common import _get_authenticated_user_id, _commit_and_fetch_post # Import common helpers (create this file next)


# --- Mutation Resolvers for Posts ---

async def _create_post_impl(info: Info, post_input: PostCreateInput) -> PostType:
    user_id = _get_authenticated_user_id(info)
    conn = None; post_id = None; comm_exists = None
    # NOTE: Media uploads are not handled in this GraphQL mutation for now. Assumed done via REST.
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Validation
        if post_input.community_id:
            comm_exists = crud.get_community_by_id(cursor, post_input.community_id)
            if not comm_exists: raise ValueError(f"Community {post_input.community_id} not found.")

        # Create post base
        post_id = crud.create_post_db(cursor, user_id=user_id, title=post_input.title, content=post_input.content)
        if not post_id: raise Exception("Failed to create post record.")
        if post_input.community_id: crud.add_post_to_community_db(cursor, post_input.community_id, post_id)

        # Fetch result after commit
        created_post_gql = await _commit_and_fetch_post(conn, cursor, info, post_id)

        # Broadcast WebSocket event
        ws_manager_instance = info.context.get("ws_manager")
        if ws_manager_instance and post_input.community_id:
            room_key = f"community_{post_input.community_id}"
            broadcast_payload = {"type": "new_post", "data": { "post_id": post_id, "community_id": post_input.community_id, "user_id": user_id, "title": post_input.title }}
            try: await ws_manager_instance.broadcast(json.dumps(broadcast_payload), room_key)
            except Exception as ws_err: print(f"GQL WARN: Failed WS broadcast for new post {post_id}: {ws_err}")

        return created_post_gql

    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback()
        print(f"Error in create_post_resolver: {e}"); traceback.print_exc()
        raise Exception(f"Could not create post: {e}") from e
    finally:
        if conn: conn.close()

async def _update_post_impl(info: Info, post_id: int, post_input: PostUpdateInput) -> PostType:
    user_id = _get_authenticated_user_id(info)
    conn = None
    update_dict = post_input.to_dict() # Convert input object to dict
    if not update_dict: raise ValueError("No update data provided.")

    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # 1. Check ownership
        post = crud.get_post_by_id(cursor, post_id)
        if not post: raise ValueError("Post not found.")
        if post["user_id"] != user_id: raise ValueError("Not authorized.")

        # 2. Update Post (Relational - Graph update for title/content?)
        # TODO: Create crud.update_post function if needed, or adapt update_profile logic
        # For now, assume simple update on posts table
        set_clauses = []
        params = []
        if 'title' in update_dict: set_clauses.append("title = %s"); params.append(update_dict['title'])
        if 'content' in update_dict: set_clauses.append("content = %s"); params.append(update_dict['content'])

        if not set_clauses: raise ValueError("No valid fields to update.") # Should be caught earlier

        params.append(post_id)
        sql = f"UPDATE public.posts SET {', '.join(set_clauses)} WHERE id = %s"
        cursor.execute(sql, tuple(params))
        if cursor.rowcount == 0: raise Exception("Post update failed (post not found or no change).")

        # TODO: Update corresponding Post vertex properties in AGE if needed

        # Fetch result after commit
        updated_post_gql = await _commit_and_fetch_post(conn, cursor, info, post_id)
        return updated_post_gql

    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback()
        print(f"Error in update_post_resolver: {e}"); traceback.print_exc()
        raise Exception(f"Could not update post: {e}") from e
    finally:
        if conn: conn.close()


async def _delete_post_impl(info: Info, post_id: strawberry.ID) -> bool:
    user_id = _get_authenticated_user_id(info)
    conn = None; media_to_delete = []
    try:
        post_id_int = int(post_id)
        conn = get_db_connection(); cursor = conn.cursor()
        post = crud.get_post_by_id(cursor, post_id_int)
        if not post: raise ValueError("Post not found.")
        if post["user_id"] != user_id: raise ValueError("Not authorized.")
        media_to_delete = crud.get_media_items_for_post(cursor, post_id_int)
        deleted = crud.delete_post_db(cursor, post_id_int)
        if not deleted: raise Exception("Post deletion failed.")
        conn.commit()
        for item in media_to_delete: utils.delete_media_item_db_and_file(item.get("id"), item.get("minio_object_name"))
        return True
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback()
        print(f"Error in delete_post_resolver: {e}"); traceback.print_exc()
        raise Exception(f"Could not delete post: {e}") from e
    finally:
        if conn: conn.close()


# --- Define Partial Mutation Class ---
@strawberry.type
class PostMutations:
    @strawberry.mutation(description="Create a new post.")
    async def create_post(self, info: Info, post_input: PostCreateInput) -> PostType:
        # Calls the implementation function
        return await _create_post_impl(info, post_input)

    @strawberry.mutation(description="Update an existing post (must be owner).")
    async def update_post(self, info: Info, post_id: strawberry.ID, post_input: PostUpdateInput) -> PostType:
        return await _update_post_impl(info, int(post_id), post_input)

    @strawberry.mutation(description="Delete a post (must be owner).")
    async def delete_post(self, info: Info, post_id: strawberry.ID) -> bool:
        return await _delete_post_impl(info, post_id)
