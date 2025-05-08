# backend/src/crud/_settings.py
import psycopg2
import psycopg2.extras
from typing import Dict, Any, Optional

def get_notification_settings(cursor: psycopg2.extensions.cursor, user_id: int) -> Optional[Dict[str, Any]]:
    # Adjust columns based on your actual users table schema for settings
    # Example assumes boolean columns like notify_new_post, notify_reply exist
    try:
        cursor.execute(
            """SELECT
                -- Define actual columns used for settings, provide defaults if nullable
                COALESCE(notify_new_post_in_community, true) as new_post_in_community,
                COALESCE(notify_new_reply_to_post, true) as new_reply_to_post,
                COALESCE(notify_new_event_in_community, true) as new_event_in_community,
                COALESCE(notify_event_reminder, true) as event_reminder,
                COALESCE(notify_direct_message, false) as direct_message
                -- Add other setting columns...
            FROM public.users WHERE id = %s""",
            (user_id,)
        )
        settings = cursor.fetchone()
        return settings # Returns RealDictRow (acts like dict) or None
    except Exception as e:
        print(f"Error fetching notification settings for user {user_id}: {e}")
        # Decide: return None or raise? Returning None might be safer for GET.
        return None


def update_notification_settings(cursor: psycopg2.extensions.cursor, user_id: int, settings: Dict[str, bool]) -> bool:
    # Update settings columns in the users table
    set_clauses = []
    params = []
    # Map input keys (from schema) to DB column names
    settings_map = {
        "new_post_in_community": "notify_new_post_in_community",
        "new_reply_to_post": "notify_new_reply_to_post",
        "new_event_in_community": "notify_new_event_in_community",
        "event_reminder": "notify_event_reminder",
        "direct_message": "notify_direct_message",
        # Add other mappings...
    }
    for key, value in settings.items():
        db_column = settings_map.get(key)
        # Basic validation: ensure key is known and value is boolean
        if db_column and isinstance(value, bool):
            set_clauses.append(f"{db_column} = %s")
            params.append(value)

    if not set_clauses: return False # Nothing valid to update

    params.append(user_id)
    sql = f"UPDATE public.users SET {', '.join(set_clauses)} WHERE id = %s;"
    try:
        cursor.execute(sql, tuple(params))
        print(f"CRUD: Updated notification settings for user {user_id}")
        # rowcount > 0 means the WHERE clause matched (user exists)
        # It doesn't guarantee values actually changed if they were already set.
        return cursor.rowcount > 0
    except Exception as e:
        print(f"Error updating notification settings for user {user_id}: {e}")
        raise # Re-raise for transaction rollback