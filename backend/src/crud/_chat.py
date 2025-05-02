# backend/src/crud/_chat.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime

# No graph imports needed here

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
    # This function remains the same as before AGE migration
    try:
        cursor.execute(
            """
            INSERT INTO public.chat_messages (community_id, event_id, user_id, content)
            VALUES (%s, %s, %s, %s) RETURNING id, "timestamp"; -- Ensure timestamp column name is quoted if needed
            """,
            (community_id, event_id, user_id, content)
        )
        result = cursor.fetchone()
        if not result: return None

        # Fetch username separately (could be optimized by joining in main query if performance is critical)
        cursor.execute("SELECT username FROM public.users WHERE id = %s", (user_id,))
        user_info = cursor.fetchone()
        username = user_info['username'] if user_info else "Unknown"

        # Use explicit key names matching ChatMessageData schema
        return {
            "message_id": result["id"],
            "community_id": community_id,
            "event_id": event_id,
            "user_id": user_id,
            "username": username,
            "content": content,
            "timestamp": result["timestamp"] # Use actual column name from RETURNING
        }
    except Exception as e:
        print(f"Error in create_chat_message_db: {e}")
        raise # Re-raise for transaction handling

def get_chat_messages_db(
    cursor: psycopg2.extensions.cursor,
    community_id: Optional[int],
    event_id: Optional[int],
    limit: int,
    before_id: Optional[int]
) -> List[Dict[str, Any]]:
    """Fetches chat messages from public.chat_messages."""
    # This function also remains the same as before AGE migration
    # Note: Query logic for fetching combined community/event messages might need review based on requirements.
    query = """
        SELECT
            m.id as message_id, m.community_id, m.event_id, m.user_id, m.content,
            m."timestamp", -- Ensure correct column name quoting
            u.username
        FROM public.chat_messages m
        JOIN public.users u ON m.user_id = u.id
        WHERE """
    params = []
    filters = []

    # Current logic: fetches EITHER event OR specific community messages
    if event_id is not None:
        # Fetch messages specifically for the event
        filters.append("m.event_id = %s")
        params.append(event_id)
        # If you want event chat to INCLUDE general community chat:
        # filters.append("(m.event_id = %s OR (m.community_id = (SELECT community_id FROM public.events WHERE id = %s) AND m.event_id IS NULL))")
        # params.extend([event_id, event_id])
    elif community_id is not None:
        # Fetch only general community messages (no specific event)
        filters.append("m.community_id = %s AND m.event_id IS NULL")
        params.append(community_id)
    else:
        return [] # Must provide community or event ID

    if before_id is not None:
        filters.append("m.id < %s") # Paginate based on message ID
        params.append(before_id)

    query += " AND ".join(filters)
    # Fetch older messages first for pagination (before_id < X), then reverse in code if needed
    query += " ORDER BY m.id DESC LIMIT %s;"
    params.append(limit)

    cursor.execute(query, tuple(params))
    # Return results directly (caller might reverse for display)
    return cursor.fetchall()
