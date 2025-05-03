# backend/src/crud/_media.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any

from .. import utils # For get_minio_url

def create_media_item(
    cursor: psycopg2.extensions.cursor,
    uploader_user_id: int,
    minio_object_name: str,
    mime_type: str,
    file_size_bytes: Optional[int],
    original_filename: Optional[str],
    width: Optional[int] = None,
    height: Optional[int] = None,
    duration_seconds: Optional[float] = None
) -> Optional[int]:
    """Inserts a record into the media_items table."""
    try:
        cursor.execute(
            """
            INSERT INTO public.media_items
            (uploader_user_id, minio_object_name, mime_type, file_size_bytes, original_filename, width, height, duration_seconds)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id;
            """,
            (uploader_user_id, minio_object_name, mime_type, file_size_bytes, original_filename, width, height, duration_seconds)
        )
        result = cursor.fetchone()
        return result['id'] if result else None
    except psycopg2.Error as e:
        print(f"Error creating media item for {minio_object_name}: {e}")
        raise # Re-raise for transaction rollback

def link_media_to_post(cursor: psycopg2.extensions.cursor, post_id: int, media_id: int, display_order: int = 0):
    cursor.execute(
        "INSERT INTO public.post_media (post_id, media_id, display_order) VALUES (%s, %s, %s) ON CONFLICT DO NOTHING;",
        (post_id, media_id, display_order)
    )

def link_media_to_reply(cursor: psycopg2.extensions.cursor, reply_id: int, media_id: int, display_order: int = 0):
    cursor.execute(
        "INSERT INTO public.reply_media (reply_id, media_id, display_order) VALUES (%s, %s, %s) ON CONFLICT DO NOTHING;",
        (reply_id, media_id, display_order)
    )

def link_media_to_chat_message(cursor: psycopg2.extensions.cursor, message_id: int, media_id: int):
    cursor.execute(
        "INSERT INTO public.chat_message_media (message_id, media_id) VALUES (%s, %s) ON CONFLICT DO NOTHING;",
        (message_id, media_id)
    )

def set_user_profile_picture(cursor: psycopg2.extensions.cursor, user_id: int, media_id: int):
    # Upsert: Insert or update the profile picture link
    cursor.execute(
        """
        INSERT INTO public.user_profile_picture (user_id, media_id, set_at)
        VALUES (%s, %s, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          media_id = EXCLUDED.media_id,
          set_at = NOW();
        """,
        (user_id, media_id)
    )

def set_community_logo(cursor: psycopg2.extensions.cursor, community_id: int, media_id: int):
     # Upsert
     cursor.execute(
        """
        INSERT INTO public.community_logo (community_id, media_id, set_at)
        VALUES (%s, %s, NOW())
        ON CONFLICT (community_id) DO UPDATE SET
          media_id = EXCLUDED.media_id,
          set_at = NOW();
        """,
        (community_id, media_id)
    )

def get_media_items_for_post(cursor: psycopg2.extensions.cursor, post_id: int) -> List[Dict[str, Any]]:
    cursor.execute(
        """
        SELECT mi.*, pm.display_order
        FROM public.media_items mi
        JOIN public.post_media pm ON mi.id = pm.media_id
        WHERE pm.post_id = %s
        ORDER BY pm.display_order ASC, mi.created_at ASC;
        """,
        (post_id,)
    )
    items = cursor.fetchall()
    results = []
    for item in items:
        item_dict = dict(item)
        item_dict['url'] = utils.get_minio_url(item_dict.get('minio_object_name'))
        results.append(item_dict)
    return results

# Add similar get functions for replies, chat messages, profile picture, logo...
def get_user_profile_picture_media(cursor: psycopg2.extensions.cursor, user_id: int) -> Optional[Dict[str, Any]]:
     cursor.execute(
        """
        SELECT mi.*
        FROM public.media_items mi
        JOIN public.user_profile_picture upp ON mi.id = upp.media_id
        WHERE upp.user_id = %s;
        """,
        (user_id,)
    )
     item = cursor.fetchone()
     if item:
         item_dict = dict(item)
         item_dict['url'] = utils.get_minio_url(item_dict.get('minio_object_name'))
         return item_dict
     return None

def get_community_logo_media(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
     cursor.execute(
        """
        SELECT mi.*
        FROM public.media_items mi
        JOIN public.community_logo cl ON mi.id = cl.media_id
        WHERE cl.community_id = %s;
        """,
        (community_id,)
    )
     item = cursor.fetchone()
     if item:
         item_dict = dict(item)
         item_dict['url'] = utils.get_minio_url(item_dict.get('minio_object_name'))
         return item_dict
     return None

def delete_media_item(cursor: psycopg2.extensions.cursor, media_id: int) -> str | None:
     """ Deletes media item record and returns its minio_object_name for file deletion. """
     # Important: Ensure related FKs in linking tables are ON DELETE CASCADE
     # or handle deletion from linking tables first.
     # We rely on CASCADE for post_media, reply_media, chat_message_media.
     # For profile/logo, we might need to remove the link first if using RESTRICT.
     cursor.execute("UPDATE public.user_profile_picture SET media_id = NULL WHERE media_id = %s;", (media_id,)) # Example handling RESTRICT
     cursor.execute("UPDATE public.community_logo SET media_id = NULL WHERE media_id = %s;", (media_id,)) # Example handling RESTRICT

     cursor.execute("DELETE FROM public.media_items WHERE id = %s RETURNING minio_object_name;", (media_id,))
     result = cursor.fetchone()
     return result['minio_object_name'] if result else None
