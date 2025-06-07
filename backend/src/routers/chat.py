# backend/src/routers/chat.py
from fastapi import APIRouter, Depends, HTTPException, status, Query, Form, File, UploadFile
from typing import List, Optional, Dict, Any
import psycopg2
import traceback
import json # For potential WebSocket payload if needed, though moving away from direct broadcast here

# Use the central crud import
from .. import schemas, crud, auth, utils, security # Import utils
from ..database import get_db_connection
# Removed import for old manager: from ..connection_manager import manager

router = APIRouter(
    prefix="/chat",
    tags=["Chat"],
    dependencies=[Depends(security.get_api_key)]
)

@router.post("/messages", status_code=status.HTTP_201_CREATED, response_model=schemas.ChatMessageData)
async def send_chat_message_http(
        current_user_id: int = Depends(auth.get_current_user),
        content: str = Form(...),
        community_id: Optional[int] = Form(None), # Changed from Query to Form
        event_id: Optional[int] = Form(None),     # Changed from Query to Form
        dm_recipient_user_id: Optional[int] = Form(None), # New for DMs
        files: List[UploadFile] = File(default=[])
):
    """
    Sends a chat message (community, event, or DM) via HTTP (multipart).
    Real-time broadcasting is now handled by the dedicated Socket.IO server.
    """
    # Validate input: exactly one target type
    is_community_chat = community_id is not None
    is_event_chat = event_id is not None
    is_dm_chat = dm_recipient_user_id is not None

    num_targets = sum([is_community_chat, is_event_chat, is_dm_chat])
    if num_targets != 1:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Provide exactly one of: community_id, event_id, or dm_recipient_user_id."
        )
    if is_dm_chat and current_user_id == dm_recipient_user_id:
        raise HTTPException(status_code=400, detail="Cannot send a direct message to yourself.")


    conn = None
    message_id = None
    media_ids_created = []
    minio_objects_created = []

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Call updated CRUD function
        created_message_dict = crud.create_chat_message_db(
            cursor,
            user_id=current_user_id,
            content=content.strip(),
            community_id=community_id if is_community_chat else None,
            event_id=event_id if is_event_chat else None,
            dm_recipient_id=dm_recipient_user_id if is_dm_chat else None
        )
        if not created_message_dict or 'message_id' not in created_message_dict:
            raise HTTPException(status_code=500, detail="Message base insertion failed.")
        message_id = created_message_dict['message_id']

        # Link Media (remains the same)
        media_items_for_response_db = []
        if files:
            room_type_path = "dms" # Default to dms for path construction
            room_id_for_path = f"{min(current_user_id, dm_recipient_user_id)}_{max(current_user_id, dm_recipient_user_id)}" if is_dm_chat else current_user_id # Simplified path

            if is_community_chat: room_type_path = "communities"; room_id_for_path = community_id
            elif is_event_chat: room_type_path = "events"; room_id_for_path = event_id

            for file_upload in files:
                if file_upload and file_upload.filename:
                    object_name_prefix = f"media/{room_type_path}/{room_id_for_path}/chat/{message_id}"
                    upload_info = await utils.upload_file_to_minio(file_upload, object_name_prefix)
                    if upload_info:
                        minio_objects_created.append(upload_info['minio_object_name'])
                        media_id_db = crud.create_media_item(cursor, uploader_user_id=current_user_id, **upload_info)
                        if media_id_db:
                            media_ids_created.append(media_id_db)
                            crud.link_media_to_chat_message(cursor, message_id, media_id_db)
                            media_item_db = crud.get_media_item_by_id(cursor, media_id_db)
                            if media_item_db: media_items_for_response_db.append(media_item_db)
                        else: print(f"WARN: Failed media_item record for chat {message_id}")
                    else: print(f"WARN: Failed upload for chat {message_id}")

        conn.commit() # Commit message and media links
        print(f"✅ Message {message_id} (Type: {'DM' if is_dm_chat else ('Community' if is_community_chat else 'Event')}) saved via HTTP.")

        # Prepare response data based on what crud.create_chat_message_db returns
        # It should now include all necessary fields including sender_id, recipient_id for DMs
        response_chat_message_data = {**created_message_dict}
        response_chat_message_data['media'] = [
            {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))}
            for item in media_items_for_response_db
        ]

        # No direct WebSocket broadcast from here anymore for new Socket.IO architecture
        # Real-time messages will be sent by clients *through* Socket.IO, which then broadcasts.
        # This HTTP endpoint is for cases where WS might not be used or for initial messages.

        return schemas.ChatMessageData(**response_chat_message_data)

    except HTTPException as http_exc:
        if conn: conn.rollback()
        for obj_name in minio_objects_created: utils.delete_from_minio(obj_name)
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback()
        for obj_name in minio_objects_created: utils.delete_from_minio(obj_name)
        print(f"❌ DB Error sending HTTP message: {e} (Code: {e.pgcode})")
        detail = f"Database error: {e.pgerror or 'Unknown DB error'}"
        if e.pgcode == '23503': # FK violation
            detail = "Invalid user, community, or event reference."
        elif e.pgcode == '23514': # Check constraint violation
            detail = "Invalid message parameters (e.g., sender is recipient, or wrong target type mix)."
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)
    except Exception as e:
        if conn: conn.rollback()
        for obj_name in minio_objects_created: utils.delete_from_minio(obj_name)
        print(f"❌ Error sending message via HTTP: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))
    finally:
        if conn: conn.close()

@router.get("/messages", response_model=List[schemas.ChatMessageData])
async def get_chat_messages(
        current_user_id: int = Depends(auth.get_current_user), # Auth required to fetch any chat history
        community_id: Optional[int] = Query(None),
        event_id: Optional[int] = Query(None),
        # New parameters for DMs
        dm_with_user_id: Optional[int] = Query(None, description="ID of the other user for DM history."),
        limit: int = Query(50, ge=1, le=200),
        before_id: Optional[int] = Query(None)
):
    """Fetches historical chat messages (community, event, or DM)."""
    is_community_chat = community_id is not None
    is_event_chat = event_id is not None
    is_dm_chat = dm_with_user_id is not None

    num_targets = sum([is_community_chat, is_event_chat, is_dm_chat])
    if num_targets == 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Provide one of: community_id, event_id, or dm_with_user_id."
        )
    if num_targets > 1:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Provide only one of: community_id, event_id, or dm_with_user_id, not a mix."
        )

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        messages_db: List[Dict[str, Any]] = []

        if is_dm_chat:
            if dm_with_user_id == current_user_id:
                raise HTTPException(status_code=400, detail="Cannot fetch DMs with yourself using this parameter.")
            messages_db = crud.get_direct_messages_db(
                cursor, user1_id=current_user_id, user2_id=dm_with_user_id,
                limit=limit, before_id=before_id
            )
        else: # Community or Event Chat
            messages_db = crud.get_chat_messages_db(
                cursor, community_id=community_id, event_id=event_id,
                limit=limit, before_id=before_id
            )

        # The CRUD functions already handle media item fetching and URL generation within their results
        # They return a list of dicts where each dict has a 'media' key (List[Dict])
        return [schemas.ChatMessageData(**msg) for msg in messages_db]

    except psycopg2.Error as e:
        print(f"DB Error fetching chat messages: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error fetching messages")
    except Exception as e:
        print(f"❌ Error fetching HTTP messages: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error fetching messages")
    finally:
        if conn: conn.close()