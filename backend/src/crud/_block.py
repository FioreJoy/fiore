# backend/src/crud/_block.py
import psycopg2
import psycopg2.extras
from typing import List, Dict, Any

from .. import utils # For get_minio_url

def block_user_db(cursor: psycopg2.extensions.cursor, blocker_id: int, blocked_id: int) -> bool:
    """Creates a block relationship in the user_blocks table."""
    if blocker_id == blocked_id: return False # Prevent self-blocking logic duplication
    try:
        # Use ON CONFLICT DO NOTHING to handle cases where block already exists
        cursor.execute(
            """
            INSERT INTO public.user_blocks (blocker_id, blocked_id)
            VALUES (%s, %s)
            ON CONFLICT (blocker_id, blocked_id) DO NOTHING;
            """,
            (blocker_id, blocked_id)
        )
        # Return True if insert happened or conflict occurred (block exists)
        # cursor.rowcount isn't reliable with ON CONFLICT DO NOTHING in all cases
        # We assume success if no exception is raised
        return True
    except psycopg2.Error as e:
        # Check for specific FK violation if needed (e.g., user doesn't exist)
        print(f"Error blocking user (B:{blocker_id} -> T:{blocked_id}): {e}")
        # Re-raise to allow transaction rollback
        raise e

def unblock_user_db(cursor: psycopg2.extensions.cursor, blocker_id: int, blocked_id: int) -> bool:
    """Removes a block relationship from the user_blocks table."""
    try:
        cursor.execute(
            "DELETE FROM public.user_blocks WHERE blocker_id = %s AND blocked_id = %s;",
            (blocker_id, blocked_id)
        )
        # rowcount > 0 indicates a block was actually removed
        return cursor.rowcount > 0
    except psycopg2.Error as e:
        print(f"Error unblocking user (B:{blocker_id} -> T:{blocked_id}): {e}")
        raise e # Re-raise

def get_blocked_users_db(cursor: psycopg2.extensions.cursor, blocker_id: int) -> List[Dict[str, Any]]:
    """Retrieves the list of users blocked by the blocker_id."""
    try:
        # Join with users table to get blocked user details
        cursor.execute(
            """
            SELECT
                b.blocked_id,
                b.created_at as blocked_at,
                u.username as blocked_username,
                u.name as blocked_name,
                u.image_path as blocked_user_image_path
            FROM public.user_blocks b
            JOIN public.users u ON b.blocked_id = u.id
            WHERE b.blocker_id = %s
            ORDER BY u.username;
            """,
            (blocker_id,)
        )
        blocked_users = cursor.fetchall()
        # Add the full image URL
        results = []
        for user in blocked_users:
             user_dict = dict(user)
             user_dict['blocked_user_avatar_url'] = utils.get_minio_url(user.get('blocked_user_image_path'))
             results.append(user_dict)
        return results

    except psycopg2.Error as e:
        print(f"Error fetching blocked users for user {blocker_id}: {e}")
        raise e
