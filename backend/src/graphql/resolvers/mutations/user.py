# backend/src/graphql/resolvers/mutations/user.py
import strawberry
from typing import Optional
import psycopg2
from strawberry.types import Info

from .... import crud
from ....database import get_db_connection
from ....socketio_manager import sio # Import SIO for potential real-time updates if needed
from .common import _get_authenticated_user_id

async def follow_user_resolver(info: Info, user_id: strawberry.ID) -> bool:
    follower_id = _get_authenticated_user_id(info)
    conn = None
    try:
        following_id_int = int(user_id)
        if follower_id == following_id_int: raise ValueError("Cannot follow yourself.")
        conn = get_db_connection(); cursor = conn.cursor()
        if not crud.get_user_by_id(cursor, following_id_int): raise ValueError("User to follow not found.")

        success = crud.follow_user(cursor, follower_id, following_id_int)
        if not success: raise Exception("Follow operation failed at CRUD level.")

        # Create Notification
        actor_info = crud.get_user_by_id(cursor, follower_id)
        actor_username = actor_info.get('username', 'Someone') if actor_info else 'Someone'
        crud.create_notification(cursor, recipient_user_id=following_id_int, actor_user_id=follower_id,
                                 type='new_follower', related_entity_type='user', related_entity_id=follower_id,
                                 content_preview=f"{actor_username} started following you.")
        conn.commit()
        # TODO: Emit 'user_followed' event to target user (user_id_int) via sio if they are online.
        # Example: await sio.emit('profile_update_counts', {'user_id': following_id_int, 'new_follower_count': ...}, room=f'user_{following_id_int}')
        return True
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not follow user: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

async def unfollow_user_resolver(info: Info, user_id: strawberry.ID) -> bool:
    follower_id = _get_authenticated_user_id(info)
    conn = None
    try:
        following_id_int = int(user_id)
        if follower_id == following_id_int: raise ValueError("Target user ID same as current user.")
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.unfollow_user(cursor, follower_id, following_id_int)
        conn.commit()
        # TODO: Emit 'user_unfollowed' if needed
        return success # crud.unfollow_user returns True even if edge didn't exist.
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not unfollow user: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

# TODO: update_user_profile GQL mutation
# TODO: block_user, unblock_user GQL mutations