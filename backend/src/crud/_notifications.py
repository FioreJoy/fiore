# backend/src/crud/_notifications.py

import psycopg2
import psycopg2.extras
from typing import Optional, List, Dict, Any
from datetime import datetime
import traceback

from .. import utils # For MinIO URL generation for actor avatar

def create_notification(
        cursor: psycopg2.extensions.cursor,
        recipient_user_id: int,
        type: str, # Use string matching ENUM value, e.g., 'post_reply'
        actor_user_id: Optional[int] = None,
        related_entity_type: Optional[str] = None, # e.g., 'post', 'user'
        related_entity_id: Optional[int] = None,
        content_preview: Optional[str] = None
) -> Optional[int]:
    """
    Inserts a new notification record into the database.
    Checks user's notification preferences before creating.
    """
    print(f"CRUD: Attempting to create notification - Recipient: {recipient_user_id}, Type: {type}, Actor: {actor_user_id}, Entity: {related_entity_type}:{related_entity_id}")

    # Check user's notification preferences
    try:
        # Map notification type to user preference column
        preference_column_map = {
            'new_follower': None,
            'post_reply': 'notify_new_reply_to_post',
            'reply_reply': 'notify_new_reply_to_post',
            'post_vote': None,
            'reply_vote': None,
            'post_favorite': None,
            'reply_favorite': None,
            'event_invite': None,
            'event_reminder': 'notify_event_reminder',
            'event_update': 'notify_event_update',
            'community_invite': None,
            'community_post': 'notify_new_post_in_community',
            # 'new_event_in_community': 'notify_new_event_in_community', # Old mapping
            'new_community_event': 'notify_new_event_in_community', # <-- CORRECTED MAPPING
            'user_mention': None,
        }
        user_pref_column = preference_column_map.get(type)

        if user_pref_column:
            cursor.execute(f"SELECT {user_pref_column} FROM public.users WHERE id = %s", (recipient_user_id,))
            user_pref = cursor.fetchone()
            if user_pref and user_pref[user_pref_column] is False:
                print(f"CRUD: Notification of type '{type}' suppressed for user {recipient_user_id} due to preferences.")
                return None # User has opted out of this notification type

    except psycopg2.Error as db_err:
        print(f"!!! CRUD DB Error checking user preferences for notification: {db_err} (Code: {db_err.pgcode})")
        # Proceed with notification creation if preference check fails, to be safe.
    except Exception as e:
        print(f"!!! CRUD Unexpected Error checking user preferences: {e}")


    try:
        cursor.execute(
            """
            INSERT INTO public.notifications
                (recipient_user_id, actor_user_id, type, related_entity_type, related_entity_id, content_preview)
            VALUES
                (%s, %s, %s::public.notification_type, %s::public.notification_entity_type, %s, %s)
            RETURNING id;
            """,
            (
                recipient_user_id,
                actor_user_id,
                type,
                related_entity_type,
                related_entity_id,
                content_preview
            )
        )
        result = cursor.fetchone()
        if result and 'id' in result:
            new_id = result['id']
            print(f"CRUD: Notification record created with ID: {new_id}")
            # Placeholder for triggering actual push notification
            # from ..tasks import send_push_notification_task
            # send_push_notification_task.delay(new_id)
            return new_id
        else:
            print("CRUD ERROR: Notification insert failed to return ID.")
            return None
    except psycopg2.Error as db_err:
        print(f"!!! CRUD DB Error creating notification: {db_err} (Code: {db_err.pgcode})")
        if db_err.pgcode == '22P02': print("  -> Hint: Check if 'type' or 'related_entity_type' string matches ENUM values.")
        elif db_err.pgcode == '23503': print(f"  -> Hint: Check if recipient_user_id ({recipient_user_id}) or actor_user_id ({actor_user_id}) exists.")
        # Don't re-raise here, allow the original action to succeed if appropriate.
        return None
    except Exception as e:
        print(f"!!! CRUD Unexpected Error creating notification: {e}")
        traceback.print_exc()
        return None

def get_notifications_for_user(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        limit: int,
        offset: int,
        unread_only: Optional[bool] = None
) -> List[Dict[str, Any]]:
    """ Fetches notifications for a user, optionally filtered by read status. """
    query = """
        SELECT
            n.id, n.type, n.is_read, n.created_at, n.content_preview,
            n.actor_user_id, act.username as actor_username, act.name as actor_name,
            act_pp.minio_object_name as actor_avatar_path,
            n.related_entity_type, n.related_entity_id,
            CASE n.related_entity_type
                WHEN 'post' THEN p.title
                WHEN 'event' THEN e.title
                WHEN 'community' THEN c.name
                WHEN 'user' THEN ru.username -- For user-related notifications like 'new_follower'
                WHEN 'reply' THEN rp.content -- Could be a snippet
                ELSE NULL
            END as related_entity_title
        FROM public.notifications n
        LEFT JOIN public.users act ON n.actor_user_id = act.id
        LEFT JOIN public.user_profile_picture upp_act ON act.id = upp_act.user_id
        LEFT JOIN public.media_items act_pp ON upp_act.media_id = act_pp.id
        LEFT JOIN public.posts p ON n.related_entity_type = 'post' AND n.related_entity_id = p.id
        LEFT JOIN public.events e ON n.related_entity_type = 'event' AND n.related_entity_id = e.id
        LEFT JOIN public.communities c ON n.related_entity_type = 'community' AND n.related_entity_id = c.id
        LEFT JOIN public.users ru ON n.related_entity_type = 'user' AND n.related_entity_id = ru.id
        LEFT JOIN public.replies rp ON n.related_entity_type = 'reply' AND n.related_entity_id = rp.id
        WHERE n.recipient_user_id = %s
    """
    params = [user_id]
    if unread_only is True:
        query += " AND n.is_read = FALSE"
    elif unread_only is False: # Explicitly asking for read ones
        query += " AND n.is_read = TRUE"

    query += " ORDER BY n.created_at DESC LIMIT %s OFFSET %s;"
    params.extend([limit, offset])

    try:
        cursor.execute(query, tuple(params))
        notifications_db = cursor.fetchall()

        results = []
        for row in notifications_db:
            notif_dict = dict(row)
            actor = None
            if row.get('actor_user_id'):
                actor = {
                    'id': row['actor_user_id'],
                    'username': row['actor_username'],
                    'name': row.get('actor_name'),
                    'avatar_url': utils.get_minio_url(row.get('actor_avatar_path'))
                }

            related_entity = None
            if row.get('related_entity_type') and row.get('related_entity_id'):
                related_entity = {
                    'type': row['related_entity_type'],
                    'id': row['related_entity_id'],
                    'title': row.get('related_entity_title')
                }

            notif_dict['actor'] = actor
            notif_dict['related_entity'] = related_entity
            results.append(notif_dict)
        return results

    except psycopg2.Error as db_err:
        print(f"CRUD DB Error fetching notifications for user {user_id}: {db_err}")
        raise
    except Exception as e:
        print(f"CRUD Unexpected Error fetching notifications for user {user_id}: {e}")
        raise

def mark_notifications_as_read(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        notification_ids: List[int],
        read_status: bool = True
) -> int:
    """ Marks specified notifications as read or unread for a user. Returns number of rows affected. """
    if not notification_ids:
        return 0
    try:
        query = """
            UPDATE public.notifications
            SET is_read = %s
            WHERE recipient_user_id = %s AND id = ANY(%s)
            RETURNING id; 
        """ # Use RETURNING to count actual updates
        cursor.execute(query, (read_status, user_id, notification_ids))
        updated_count = len(cursor.fetchall()) # Count how many rows were actually returned
        return updated_count
    except psycopg2.Error as db_err:
        print(f"CRUD DB Error marking notifications read for user {user_id}: {db_err}")
        raise
    except Exception as e:
        print(f"CRUD Unexpected Error marking notifications read for user {user_id}: {e}")
        raise

def mark_all_notifications_as_read(
        cursor: psycopg2.extensions.cursor, user_id: int
) -> int:
    """ Marks all unread notifications as read for a user. Returns number of rows affected. """
    try:
        cursor.execute(
            """
            UPDATE public.notifications
            SET is_read = TRUE
            WHERE recipient_user_id = %s AND is_read = FALSE
            RETURNING id;
            """,
            (user_id,)
        )
        updated_count = len(cursor.fetchall())
        return updated_count
    except psycopg2.Error as db_err:
        print(f"CRUD DB Error marking all notifications read for user {user_id}: {db_err}")
        raise
    except Exception as e:
        print(f"CRUD Unexpected Error marking all notifications read for user {user_id}: {e}")
        raise

def get_unread_notification_count(
        cursor: psycopg2.extensions.cursor, user_id: int
) -> int:
    """ Gets the count of unread notifications for a user. """
    try:
        cursor.execute(
            "SELECT COUNT(*) as unread_count FROM public.notifications WHERE recipient_user_id = %s AND is_read = FALSE",
            (user_id,)
        )
        result = cursor.fetchone()
        return result['unread_count'] if result else 0
    except psycopg2.Error as db_err:
        print(f"CRUD DB Error getting unread notification count for user {user_id}: {db_err}")
        raise
    except Exception as e:
        print(f"CRUD Unexpected Error getting unread notification count for user {user_id}: {e}")
        raise

# --- Device Token CRUD ---
def register_user_device_token(
        cursor: psycopg2.extensions.cursor, user_id: int, device_token: str, platform: str
) -> Optional[int]:
    try:
        cursor.execute(
            """
            INSERT INTO public.user_device_tokens (user_id, device_token, platform, last_used_at)
            VALUES (%s, %s, %s::public.device_platform, NOW())
            ON CONFLICT (device_token, platform) DO UPDATE SET
                user_id = EXCLUDED.user_id,
                last_used_at = NOW()
            RETURNING id;
            """,
            (user_id, device_token, platform)
        )
        result = cursor.fetchone()
        return result['id'] if result else None
    except psycopg2.Error as e:
        print(f"CRUD Error registering device token for user {user_id}: {e}")
        raise
    except Exception as e:
        print(f"CRUD Unexpected error registering device token for user {user_id}: {e}")
        raise

def unregister_user_device_token(
        cursor: psycopg2.extensions.cursor, user_id: int, device_token: str
) -> bool:
    try:
        cursor.execute(
            "DELETE FROM public.user_device_tokens WHERE user_id = %s AND device_token = %s",
            (user_id, device_token)
        )
        return cursor.rowcount > 0
    except psycopg2.Error as e:
        print(f"CRUD Error unregistering device token for user {user_id}: {e}")
        raise
    except Exception as e:
        print(f"CRUD Unexpected error unregistering device token for user {user_id}: {e}")
        raise

def get_user_device_tokens(cursor: psycopg2.extensions.cursor, user_id: int) -> List[Dict[str, Any]]:
    try:
        cursor.execute(
            "SELECT device_token, platform FROM public.user_device_tokens WHERE user_id = %s ORDER BY last_used_at DESC",
            (user_id,)
        )
        return cursor.fetchall()
    except psycopg2.Error as e:
        print(f"CRUD DB Error fetching device tokens for user {user_id}: {e}")
        raise