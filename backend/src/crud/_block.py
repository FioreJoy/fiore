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
        # Verify column names match EXACTLY with your actual DB schema
        # Common issues: created_at vs blocked_at, image_path vs avatar_path etc.
        query = """
            SELECT
                b.blocked_id,
                b.created_at as blocked_at, -- Make sure user_blocks has created_at
                u.username as blocked_username,
                u.name as blocked_name            FROM public.user_blocks b -- Make sure user_blocks exists
            JOIN public.users u ON b.blocked_id = u.id
            WHERE b.blocker_id = %s
            ORDER BY u.username;
        """
        print(f"CRUD: Executing get_blocked_users_db for blocker {blocker_id}")
        cursor.execute(query, (blocker_id,))
        blocked_users = cursor.fetchall()
        print(f"CRUD: Fetched {len(blocked_users)} raw blocked user records.")

        results = []
        for user in blocked_users:
            try: # Wrap processing for each user
                user_dict = dict(user)
                #image_path = user_dict.get('blocked_user_image_path')
                # Add a check before calling get_minio_url
                user_dict['blocked_user_avatar_url'] = None
                results.append(user_dict)
            except Exception as proc_err:
                print(f"ERROR: Processing blocked user record failed: {proc_err} - Data: {user}")
                # Decide whether to skip this user or re-raise
                # Skipping might be better to return partial results
                continue # Skip this problematic record

        print(f"CRUD: Processed {len(results)} blocked users.")
        return results

    except psycopg2.Error as e:
        # Log the specific SQL error
        print(f"DB ERROR in get_blocked_users_db for user {blocker_id}: {e} (Code: {e.pgcode})")
        # Optionally log the SQL query that failed if possible (might need adjustment to capture it)
        # print(f"Failed Query (approx): {query}") # Be careful logging queries with parameters
        raise e # Re-raise the original DB error
    except Exception as e: # Catch other potential errors during processing
        print(f"UNEXPECTED ERROR in get_blocked_users_db for user {blocker_id}: {e}")
        import traceback
        traceback.print_exc()
        raise e # Re-raise
