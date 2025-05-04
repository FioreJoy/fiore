# backend/src/crud/_chat.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime
from .. import utils
# No graph imports needed

# =========================================
# Chat CRUD (Purely Relational)
# =========================================

def create_chat_message_db(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        content: str,
        community_id: Optional[int],
        event_id: Optional[int]
) -> Optional[Dict[str, Any]]:
    """Saves a chat message to the public.chat_messages table."""
    # No changes needed from previous version
    try:
        # Use double quotes for timestamp if it's a reserved keyword or contains uppercase
        cursor.execute(
            """
            INSERT INTO public.chat_messages (community_id, event_id, user_id, content)
            VALUES (%s, %s, %s, %s) RETURNING id, "timestamp";
            """,
            (community_id, event_id, user_id, content)
        )
        result = cursor.fetchone()
        if not result: return None

        cursor.execute("SELECT username FROM public.users WHERE id = %s", (user_id,))
        user_info = cursor.fetchone()
        username = user_info['username'] if user_info else "Unknown"

        return {
            "message_id": result["id"],
            "community_id": community_id,
            "event_id": event_id,
            "user_id": user_id,
            "username": username,
            "content": content,
            "timestamp": result["timestamp"] # Use actual column name from RETURNING
        }
    except psycopg2.Error as e: # Catch specific DB errors
        print(f"Error in create_chat_message_db: {e} (Code: {e.pgcode})")
        raise # Re-raise for transaction handling by caller
    except Exception as e:
        print(f"Unexpected error in create_chat_message_db: {e}")
        raise

def get_chat_messages_db(
        cursor: psycopg2.extensions.cursor,
        community_id: Optional[int],
        event_id: Optional[int],
        limit: int,
        before_id: Optional[int]
) -> List[Dict[str, Any]]:
    """Fetches chat messages from public.chat_messages."""
    # No changes needed from previous version
    # Note: Review WHERE clause logic based on how community/event chats should interact
    query = """
        SELECT
            m.id as message_id, m.community_id, m.event_id, m.user_id, m.content,
            m."timestamp", -- Use double quotes for timestamp if needed
            u.username
        FROM public.chat_messages m
        JOIN public.users u ON m.user_id = u.id
        WHERE """
    params = []
    filters = []

    if event_id is not None:
        # Fetch messages specifically for the event
        filters.append("m.event_id = %s")
        params.append(event_id)
        # Optional: Include general community messages in event chat
        # filters.append("(m.event_id = %s OR (m.community_id = (SELECT community_id FROM public.events WHERE id = %s) AND m.event_id IS NULL))")
        # params.extend([event_id, event_id])
    elif community_id is not None:
        # Fetch only general community messages
        filters.append("m.community_id = %s AND m.event_id IS NULL")
        params.append(community_id)
    else:
        return [] # Require one ID

    if before_id is not None:
        filters.append("m.id < %s")
        params.append(before_id)

    query += " AND ".join(filters)
    query += " ORDER BY m.id DESC LIMIT %s;" # Fetch newest first up to limit for pagination
    params.append(limit)

    try:
        cursor.execute(query, tuple(params))
        # Fetchall returns list of RealDictRow
        return cursor.fetchall()
    except psycopg2.Error as e:
        print(f"Error fetching chat messages: {e} (Code: {e.pgcode})")
        raise
    except Exception as e:
        print(f"Unexpected error fetching chat messages: {e}")
        raise