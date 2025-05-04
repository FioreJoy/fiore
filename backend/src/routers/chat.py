# backend/src/routers/chat.py
from fastapi import APIRouter, Depends, HTTPException, status, Query, Form, File, UploadFile
from typing import List, Optional, Dict, Any # Added Dict, Any
import psycopg2
import json # For broadcasting
import traceback


# Use the central crud import
from .. import schemas, crud, auth, utils
from ..database import get_db_connection
from ..connection_manager import manager # Import manager to broadcast HTTP messages

router = APIRouter(
    prefix="/chat",
    tags=["Chat"],
    # dependencies=[Depends(auth.get_current_user)] # Apply auth dependency here
)

@router.post("/messages", status_code=status.HTTP_201_CREATED, response_model=schemas.ChatMessageData)
async def send_chat_message_http(
        # Change parameters to use Form and File
        current_user_id: int = Depends(auth.get_current_user),
        content: str = Form(...),
        community_id: Optional[int] = Query(None), # Keep as Query param
        event_id: Optional[int] = Query(None),      # Keep as Query param
        files: List[UploadFile] = File(default=[])   # Accept files
):
    """Sends a chat message via HTTP and broadcasts it. Handles media."""
    if not ((community_id is not None and event_id is None) or \
            (community_id is None and event_id is not None)):
        raise HTTPException(status_code=400, detail="Provide exactly one of community_id or event_id.")

    conn = None
    message_id = None
    media_ids_created = []
    minio_objects_created = []
    try:
        conn = get_db_connection(); cursor = conn.cursor()

        # Create the base message record
        created_message_dict = crud.create_chat_message_db(
            cursor, user_id=current_user_id, content=content.strip(),
            community_id=community_id, event_id=event_id
        )
        if not created_message_dict or 'message_id' not in created_message_dict:
            raise HTTPException(status_code=500, detail="Message base insertion failed.")
        message_id = created_message_dict['message_id']

        # Link Media
        for file in files:
            if file and file.filename:
                room_type = "communities" if community_id else "events"
                room_id_for_path = community_id if community_id else event_id
                object_name_prefix = f"media/{room_type}/{room_id_for_path}/chat/{message_id}" # Path for chat media
                upload_info = await utils.upload_file_to_minio(file, object_name_prefix)
                if upload_info:
                    minio_objects_created.append(upload_info['minio_object_name'])
                    media_id = crud.create_media_item(cursor, uploader_user_id=current_user_id, **upload_info)
                    if media_id:
                        media_ids_created.append(media_id)
                        crud.link_media_to_chat_message(cursor, message_id, media_id) # Use correct link function
                    else: print(f"WARN: Failed media_item record for chat {message_id}")
                else: print(f"WARN: Failed upload for chat {message_id}")

        # Fetch media items for the response
        media_items = crud.get_media_items_for_chat_message(cursor, message_id)

        conn.commit()
        print(f"✅ Message {message_id} saved to DB via HTTP.")

        # Prepare response data
        chat_message_obj_data = {
            **created_message_dict,
            "media": [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items ]
        }
        chat_message_obj = schemas.ChatMessageData(**chat_message_obj_data)

        # Broadcast via WebSocket manager
        # ... (keep broadcast logic) ...
        room_type_ws = "community" if community_id else "event"
        room_id_ws = community_id if community_id else event_id
        room_identifier = f"{room_type_ws}_{room_id_ws}"
        broadcast_message = chat_message_obj.model_dump_json() if hasattr(chat_message_obj, 'model_dump_json') else chat_message_obj.json()
        print(f"📢 Broadcasting HTTP message to WS room {room_identifier}")
        await manager.broadcast(broadcast_message, room_identifier)

        return chat_message_obj # Return the created message data with media

    # ... (Error Handling - Adapt from create_post/create_reply) ...
    except HTTPException as http_exc:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        print(f"❌ DB Error sending HTTP message: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except Exception as e:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        print(f"❌ Error sending message via HTTP: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@router.get("/messages", response_model=List[schemas.ChatMessageData])
async def get_chat_messages(
        # Auth not strictly needed to view history, but could be added
        # current_user_id: Optional[int] = Depends(auth.get_current_user_optional),
        community_id: Optional[int] = Query(None),
        event_id: Optional[int] = Query(None),
        limit: int = Query(50, gt=0, le=200),
        before_id: Optional[int] = Query(None)
):
    """Fetches historical chat messages for a community or event."""
    if not ((community_id is not None and event_id is None) or
            (community_id is None and event_id is not None)):
        raise HTTPException(status_code=400, detail="Provide exactly one of community_id or event_id.")

    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        messages_db = crud.get_chat_messages_db(cursor, community_id, event_id, limit, before_id)

        messages_with_media = []
        for msg_dict in messages_db:
            message_data = dict(msg_dict)
            message_id = message_data['message_id']
            # --- Fetch Media for this message ---
            try:
                media_items = crud.get_media_items_for_chat_message(cursor, message_id)
                message_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items ]
            except Exception as e:
                print(f"WARN: Failed fetching media for chat msg {message_id}: {e}")
                message_data['media'] = [] # Default to empty list on error
            # --- End Fetch Media ---
            messages_with_media.append(schemas.ChatMessageData(**message_data)) # Validate

        print(f"✅ Fetched {len(messages_with_media)} messages via HTTP (Comm={community_id}, Event={event_id})")
        return messages_with_media
    except Exception as e:
        print(f"❌ Error fetching HTTP messages: {e}")
        raise HTTPException(status_code=500, detail="Error fetching messages")
    finally:
        if conn: conn.close()