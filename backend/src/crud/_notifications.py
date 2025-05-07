# src/crud/_notifications.py

import psycopg2
import psycopg2.extras
from typing import Optional, List, Dict, Any
from datetime import datetime
import traceback

# We might need utils later if we format things, but not strictly needed now
# from .. import utils

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

    Args:
        cursor: The database cursor.
        recipient_user_id: The ID of the user who should receive the notification.
        type: The type of notification (must match a value in the notification_type ENUM).
        actor_user_id: The ID of the user who performed the action (optional).
        related_entity_type: The type of entity the notification relates to (optional).
        related_entity_id: The ID of the related entity (optional).
        content_preview: A short preview text for the notification (optional).

    Returns:
        The ID of the newly created notification, or None on failure.
    """
    print(f"CRUD: Attempting to create notification - Recipient: {recipient_user_id}, Type: {type}, Actor: {actor_user_id}, Entity: {related_entity_type}:{related_entity_id}")
    try:
        # Ensure ENUM values passed as strings match the defined ENUMs in the DB
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
                type, # Cast string to notification_type ENUM
                related_entity_type, # Cast string to notification_entity_type ENUM (allows NULL)
                related_entity_id,
                content_preview
            )
        )
        result = cursor.fetchone()
        if result and 'id' in result:
            new_id = result['id']
            print(f"CRUD: Notification record created with ID: {new_id}")
            # --- Trigger Background Task for Push Notification (Placeholder) ---
            # This is where you would enqueue the task for actual push delivery
            # from ..tasks import send_push_notification_task # Example import
            # try:
            #     send_push_notification_task.delay(new_id)
            #     print(f"CRUD: Enqueued push notification task for notification ID: {new_id}")
            # except Exception as task_err:
            #     print(f"CRUD ERROR: Failed to enqueue push notification task for ID {new_id}: {task_err}")
            # --- End Placeholder ---
            return new_id
        else:
            print("CRUD ERROR: Notification insert failed to return ID.")
            return None
    except psycopg2.Error as db_err:
        print(f"!!! CRUD DB Error creating notification: {db_err} (Code: {db_err.pgcode})")
        # Check for specific errors like invalid ENUM value (22P02) or FK violation (23503)
        if db_err.pgcode == '22P02':
             print("  -> Hint: Check if 'type' or 'related_entity_type' string matches ENUM values.")
        elif db_err.pgcode == '23503':
             print(f"  -> Hint: Check if recipient_user_id ({recipient_user_id}) or actor_user_id ({actor_user_id}) exists.")
        # Don't re-raise here, allow the original action (like creating a reply) to succeed.
        return None # Indicate notification creation failed
    except Exception as e:
        print(f"!!! CRUD Unexpected Error creating notification: {e}")
        traceback.print_exc() # Ensure traceback is imported in the file using this
        return None

# --- Add get_notifications and mark_notifications_read later for Task 2.4 ---
