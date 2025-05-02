# backend/src/routers/chat.py
from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional, Dict, Any # Added Dict, Any
import psycopg2
import json # For broadcasting

# Use the central crud import
from .. import schemas, crud, auth
from ..database import get_db_connection
from ..connection_manager import manager # Import manager to broadcast HTTP messages

router = APIRouter(
    prefix="/chat",
    tags=["Chat"],
    # dependencies=[Depends(auth.get_current_user)] # Apply auth dependency here
)

@router.post("/messages", status_code=status.HTTP_201_CREATED, response_model=schemas.ChatMessageData)
async def send_chat_message_http(
        message_data: schemas.ChatMessageCreate,
        current_user_id: int = Depends(auth.get_current_user), # Require auth to send
        # Query parameters to specify the room
        community_id: Optional[int] = Query(None),
        event_id: Optional[int] = Query(None)
):
    """Sends a chat message via HTTP and broadcasts it via WebSocket."""
    if not ((community_id is not None and event_id is None) or
            (community_id is None and event_id is not None)):
        raise HTTPException(status_code=400, detail="Provide exactly one of community_id or event_id.")

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Call CRUD function (now imported via central __init__)
        # This uses the public.chat_messages table
        created_message_dict = crud.create_chat_message_db(
            cursor,
            user_id=current_user_id,
            content=message_data.content,
            community_id=community_id,
            event_id=event_id
        )
        if not created_message_dict:
            raise HTTPException(status_code=500, detail="Message insertion failed.")

        conn.commit() # Commit successful insert
        print(f"✅ Message {created_message_dict['message_id']} saved to DB via HTTP.")

        # Prepare ChatMessageData object for broadcast and response
        chat_message_obj = schemas.ChatMessageData(**created_message_dict)

        # Broadcast via WebSocket manager
        room_type = "community" if community_id else "event"
        room_id = community_id if community_id else event_id
        room_identifier = f"{room_type}_{room_id}"

        # Use .model_dump_json() for Pydantic v2 or .json() for v1
        broadcast_message = chat_message_obj.model_dump_json() if hasattr(chat_message_obj, 'model_dump_json') else chat_message_obj.json()

        print(f"📢 Broadcasting HTTP message to WS room {room_identifier}")
        await manager.broadcast(broadcast_message, room_identifier)

        return chat_message_obj # Return the created message data

    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ DB Error sending HTTP message: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error sending message via HTTP: {e}")
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
        conn = get_db_connection()
        cursor = conn.cursor()

        # Call CRUD function (now imported via central __init__)
        # This uses the public.chat_messages table
        messages_db = crud.get_chat_messages_db(
            cursor,
            community_id=community_id,
            event_id=event_id,
            limit=limit,
            before_id=before_id
        )

        # Convert raw db dictionaries to ChatMessageData objects
        # Pydantic will handle the validation
        messages = [schemas.ChatMessageData(**msg) for msg in messages_db]

        print(f"✅ Fetched {len(messages)} messages via HTTP (Comm={community_id}, Event={event_id})")
        # Return in reverse chronological order (newest first) as fetched by query
        return messages
    except Exception as e:
        print(f"❌ Error fetching HTTP messages: {e}")
        raise HTTPException(status_code=500, detail="Error fetching messages")
    finally:
        if conn: conn.close()