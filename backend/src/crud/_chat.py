# backend/src/crud/_chat.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime

# Corrected: Import utils and the specific media CRUD functions needed.
from .. import utils
from ._media import get_media_items_for_chat_message # Direct import of the function

# =========================================
# Chat CRUD (Relational)
# =========================================

def create_chat_message_db(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        content: str,
        community_id: Optional[int],
        event_id: Optional[int],
        dm_recipient_id: Optional[int] = None
) -> Optional[Dict[str, Any]]:
    try:
        username_to_return = "Unknown User"
        cursor.execute("SELECT username FROM public.users WHERE id = %s", (user_id,))
        user_info = cursor.fetchone()
        if user_info:
            username_to_return = user_info['username']

        sql_insert = ""
        params = []
        is_dm = dm_recipient_id is not None

        if is_dm:
            if user_id == dm_recipient_id:
                raise ValueError("Sender and recipient cannot be the same for a direct message.")
            sql_insert = """
                INSERT INTO public.chat_messages 
                    (user_id, content, sender_id, recipient_id, community_id, event_id)
                VALUES (%s, %s, %s, %s, NULL, NULL) RETURNING id, "timestamp";
            """
            params = (user_id, content, user_id, dm_recipient_id)
        elif community_id is not None:
            sql_insert = """
                INSERT INTO public.chat_messages 
                    (user_id, content, community_id, event_id, sender_id, recipient_id)
                VALUES (%s, %s, %s, NULL, NULL, NULL) RETURNING id, "timestamp";
            """
            params = (user_id, content, community_id)
        elif event_id is not None:
            sql_insert = """
                INSERT INTO public.chat_messages 
                    (user_id, content, event_id, community_id, sender_id, recipient_id)
                VALUES (%s, %s, %s, NULL, NULL, NULL) RETURNING id, "timestamp";
            """
            params = (user_id, content, event_id)
        else:
            raise ValueError("Message must target a community, event, or user.")

        cursor.execute(sql_insert, tuple(params))
        result = cursor.fetchone()
        if not result: return None

        return_data = {
            "message_id": result["id"],
            "user_id": user_id,
            "username": username_to_return,
            "content": content,
            "timestamp": result["timestamp"],
            "community_id": community_id if not is_dm else None,
            "event_id": event_id if not is_dm else None,
            "sender_id": user_id if is_dm else None,
            "recipient_id": dm_recipient_id if is_dm else None,
        }
        return return_data
    except psycopg2.Error as e:
        print(f"DB Error in create_chat_message_db: {e} (Code: {e.pgcode})")
        raise
    except ValueError as ve:
        print(f"ValueError in create_chat_message_db: {ve}")
        raise
    except Exception as e:
        print(f"Unexpected error in create_chat_message_db: {e}")
        raise

def get_chat_messages_db(
        cursor: psycopg2.extensions.cursor,
        community_id: Optional[int] = None,
        event_id: Optional[int] = None,
        limit: int = 50,
        before_id: Optional[int] = None
) -> List[Dict[str, Any]]:
    query_parts = [
        """
        SELECT
            m.id as message_id, m.community_id, m.event_id, 
            m.user_id, m.content, m."timestamp",
            u.username,
            u_pp.minio_object_name as profile_image_path
        FROM public.chat_messages m
        JOIN public.users u ON m.user_id = u.id
        LEFT JOIN public.user_profile_picture upp ON u.id = upp.user_id
        LEFT JOIN public.media_items u_pp ON upp.media_id = u_pp.id
        WHERE 
        """
    ]
    params = []
    filters = []

    if event_id is not None:
        filters.append("m.event_id = %s AND m.community_id IS NULL AND m.sender_id IS NULL AND m.recipient_id IS NULL")
        params.append(event_id)
    elif community_id is not None:
        filters.append("m.community_id = %s AND m.event_id IS NULL AND m.sender_id IS NULL AND m.recipient_id IS NULL")
        params.append(community_id)
    else:
        raise ValueError("Must provide either community_id or event_id for group chat history.")

    if before_id is not None: filters.append("m.id < %s"); params.append(before_id)
    if not filters: return []

    query_parts.append(" AND ".join(filters))
    query_parts.append(" ORDER BY m.id DESC LIMIT %s;")
    params.append(limit)

    final_query = "".join(query_parts)

    try:
        cursor.execute(final_query, tuple(params))
        results_db = cursor.fetchall()
        results = []
        for row_dict_raw in results_db:
            item = dict(row_dict_raw) # Ensure it's a standard dict
            item['profile_image_url'] = utils.get_minio_url(item.pop('profile_image_path', None))

            # Corrected: Use the directly imported function
            media_items_db = get_media_items_for_chat_message(cursor, item['message_id'])
            item['media'] = [ {**dict(m_item), 'url': utils.get_minio_url(dict(m_item).get('minio_object_name'))} for m_item in media_items_db ]
            results.append(item)
        return results
    except psycopg2.Error as e: print(f"DB Error fetching group chat messages: {e} (Code: {e.pgcode})"); raise
    except Exception as e: print(f"Unexpected error fetching group chat messages: {e}"); raise

def get_direct_messages_db(
        cursor: psycopg2.extensions.cursor,
        user1_id: int, user2_id: int, limit: int = 50, before_id: Optional[int] = None
) -> List[Dict[str, Any]]:
    query_parts = [
        """
        SELECT
            m.id as message_id, m.user_id, m.content, m."timestamp",
            m.sender_id, m.recipient_id, 
            u.username as username,
            u_pp.minio_object_name as profile_image_path
        FROM public.chat_messages m
        JOIN public.users u ON m.user_id = u.id 
        LEFT JOIN public.user_profile_picture upp ON u.id = upp.user_id
        LEFT JOIN public.media_items u_pp ON upp.media_id = u_pp.id
        WHERE 
            ( (m.sender_id = %s AND m.recipient_id = %s) OR
              (m.sender_id = %s AND m.recipient_id = %s) )
            AND m.community_id IS NULL AND m.event_id IS NULL 
        """
    ]
    params = [user1_id, user2_id, user2_id, user1_id]
    if before_id is not None: query_parts.append(" AND m.id < %s "); params.append(before_id)
    query_parts.append(" ORDER BY m.id DESC LIMIT %s;")
    params.append(limit)

    final_query = "".join(query_parts)
    try:
        cursor.execute(final_query, tuple(params))
        results_db = cursor.fetchall()
        results = []
        for row_dict_raw in results_db:
            item = dict(row_dict_raw) # Ensure it's a standard dict
            item['profile_image_url'] = utils.get_minio_url(item.pop('profile_image_path', None))

            # Corrected: Use the directly imported function
            media_items_db = get_media_items_for_chat_message(cursor, item['message_id'])
            item['media'] = [ {**dict(m_item), 'url': utils.get_minio_url(dict(m_item).get('minio_object_name'))} for m_item in media_items_db ]
            results.append(item)
        return results
    except psycopg2.Error as e: print(f"DB Error DMs {user1_id}-{user2_id}: {e} (Code: {e.pgcode})"); raise
    except Exception as e: print(f"Unexpected error DMs {user1_id}-{user2_id}: {e}"); raise