# src/routers/chat.py
from fastapi import APIRouter, Depends, HTTPException, status, Query, Form, File, UploadFile
from typing import List, Optional, Dict, Any
import psycopg2
import traceback
import json

# Use the central crud import
from .. import schemas, crud, auth, utils, security # Import utils
from ..database import get_db_connection
from ..connection_manager import manager # Import manager to broadcast HTTP messages

router = APIRouter(
    prefix="/chat",
    tags=["Chat"],
    dependencies=[Depends(security.get_api_key)] # API Key for all chat routes
)

@router.post("/messages", status_code=status.HTTP_201_CREATED, response_model=schemas.ChatMessageData)
async def send_chat_message_http(
        # Requires user auth
        current_user_id: int = Depends(auth.get_current_user),
        # Use Form fields for multipart
        content: str = Form(...),
        community_id: Optional[int] = Query(None),
        event_id: Optional[int] = Query(None),
        files: List[UploadFile] = File(default=[])
):
    """Sends a chat message via HTTP (multipart) and broadcasts via WebSocket."""
    if not ((community_id is not None and event_id is None) or \
            (community_id is None and event_id is not None)):
        raise HTTPException(status_code=400, detail="Provide exactly one of community_id or event_id.")

    conn = None; message_id = None; media_ids_created = []; minio_objects_created = []
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Create base message
        created_message_dict = crud.create_chat_message_db(cursor, user_id=current_user_id, content=content.strip(), community_id=community_id, event_id=event_id)
        if not created_message_dict or 'message_id' not in created_message_dict: raise HTTPException(status_code=500, detail="Message base insertion failed.")
        message_id = created_message_dict['message_id']

        # Link Media
        media_items_for_response = []
        for file in files:
            if file and file.filename:
                room_type = "communities" if community_id else "events"; room_id_for_path = community_id if community_id else event_id
                object_name_prefix = f"media/{room_type}/{room_id_for_path}/chat/{message_id}"
                upload_info = await utils.upload_file_to_minio(file, object_name_prefix)
                if upload_info:
                    minio_objects_created.append(upload_info['minio_object_name'])
                    media_id = crud.create_media_item(cursor, uploader_user_id=current_user_id, **upload_info)
                    if media_id:
                        media_ids_created.append(media_id); crud.link_media_to_chat_message(cursor, message_id, media_id)
                        # Prepare media for response object
                        media_item_db = crud.get_media_item_by_id(cursor, media_id) # Fetch details for response
                        if media_item_db: media_items_for_response.append(media_item_db)
                    else: print(f"WARN: Failed media_item record for chat {message_id}")
                else: print(f"WARN: Failed upload for chat {message_id}")

        conn.commit() # Commit message and media links
        print(f"✅ Message {message_id} saved to DB via HTTP.")

        # Prepare response data
        chat_message_obj_data = {**created_message_dict}
        # Add mapped media to response data
        chat_message_obj_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items_for_response ]

        # Validate with Pydantic model
        chat_message_obj = schemas.ChatMessageData(**chat_message_obj_data)

        # Broadcast via WebSocket manager
        room_type_ws = "community" if community_id else "event"; room_id_ws = community_id if community_id else event_id
        room_identifier = f"{room_type_ws}_{room_id_ws}"
        broadcast_message = chat_message_obj.model_dump_json(exclude_none=True) if hasattr(chat_message_obj, 'model_dump_json') else chat_message_obj.json(exclude_none=True) # Exclude nulls for cleaner broadcast?
        print(f"📢 Broadcasting HTTP message to WS room {room_identifier}")
        await manager.broadcast(broadcast_message, room_identifier)

        return chat_message_obj

    # --- Error Handling ---
    except HTTPException as http_exc:
        if conn: conn.rollback();
        for obj in minio_objects_created: utils.delete_from_minio(obj)
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback();
        for obj in minio_objects_created: utils.delete_from_minio(obj)
        print(f"❌ DB Error sending HTTP message: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror or 'Unknown DB error'}")
    except Exception as e:
        if conn: conn.rollback();
        for obj in minio_objects_created: utils.delete_from_minio(obj)
        print(f"❌ Error sending message via HTTP: {e}")
        traceback.print_exc() # Ensure imported
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()


@router.get("/messages", response_model=List[schemas.ChatMessageData])
async def get_chat_messages(
        # Auth optional for reading history? Depends on requirements.
        # current_user_id: Optional[int] = Depends(auth.get_current_user_optional),
        community_id: Optional[int] = Query(None),
        event_id: Optional[int] = Query(None),
        limit: int = Query(50, ge=1, le=200),
        before_id: Optional[int] = Query(None)
):
    """Fetches historical chat messages, including associated media."""
    if not ((community_id is not None and event_id is None) or \
            (community_id is None and event_id is not None)):
        raise HTTPException(status_code=400, detail="Provide exactly one of community_id or event_id.")

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Fetch base message data
        messages_db = crud.get_chat_messages_db(cursor, community_id, event_id, limit, before_id)

        # --- FIX: Fetch and add media for each message ---
        messages_with_media = []
        for msg_dict in messages_db:
            message_data = dict(msg_dict)
            message_id = message_data['message_id']
            try:
                # Fetch media items associated with this message ID
                media_items_db = crud.get_media_items_for_chat_message(cursor, message_id)
                # Map DB media items to schema, generating URLs
                message_data['media'] = [
                    {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))}
                    for item in media_items_db
                ]
            except Exception as e:
                print(f"WARN GET /chat/messages: Failed fetching media for msg {message_id}: {e}")
                message_data['media'] = [] # Ensure media key exists even on error

            # Validate and add to final list
            try:
                messages_with_media.append(schemas.ChatMessageData(**message_data))
            except Exception as pydantic_err:
                print(f"ERROR: Pydantic validation failed for chat msg {message_id}: {pydantic_err}")
                print(f"       Data: {message_data}")
        # --- End FIX ---

        room_name = f"Community {community_id}" if community_id else f"Event {event_id}"
        print(f"✅ Fetched {len(messages_with_media)} messages via HTTP for {room_name}")
        return messages_with_media

    except psycopg2.Error as e:
        print(f"DB Error fetching chat messages: {e}")
        raise HTTPException(status_code=500, detail="Database error fetching messages")
    except Exception as e:
        print(f"❌ Error fetching HTTP messages: {e}")
        traceback.print_exc() # Ensure imported
        raise HTTPException(status_code=500, detail="Error fetching messages")
    finally:
        if conn: conn.close()