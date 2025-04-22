# backend/src/routers/websocket.py
import json
import jwt # Need jwt for token decoding here
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, status, Query, HTTPException
from typing import Optional
import psycopg2

from .. import schemas, crud, auth # Need auth for SECRET_KEY, ALGORITHM
from ..database import get_db_connection, update_last_seen # Import update_last_seen
from ..connection_manager import manager

router = APIRouter(tags=["WebSocket"])

# --- WebSocket Authentication Helper (Revised) ---
async def authenticate_websocket(token: Optional[str]) -> Optional[int]:
    """Authenticates WebSocket connection using token from query param."""
    if not token:
        print("WS Auth: No token provided.")
        return None # Let the main endpoint handle closing

    try:
        payload = jwt.decode(
            token,
            auth.SECRET_KEY, # Use SECRET_KEY from auth module
            algorithms=[auth.ALGORITHM] # Use ALGORITHM from auth module
        )
        user_id = payload.get("user_id")
        if user_id is None:
            print("WS Auth Error: Token payload missing 'user_id'")
            return None
        user_id_int = int(user_id)
        print(f"WS Auth: User {user_id_int} authenticated successfully.")
        # Optionally update last_seen here (can add slight latency)
        try:
            update_last_seen(user_id_int) # Use the function directly
        except Exception as e:
            print(f"WS Warning: Failed to update last_seen for user {user_id_int}: {e}")

        return user_id_int
    except jwt.ExpiredSignatureError:
        print("WS Auth Error: Token has expired.")
        return None
    except jwt.InvalidTokenError as e:
        print(f"WS Auth Error: Invalid Token - {e}")
        return None
    except Exception as e:
        print(f"WS Auth Error: Unexpected error - {e}")
        return None
# --- End Helper ---

@router.websocket("/ws/{room_type}/{room_id}")
async def websocket_endpoint(
        websocket: WebSocket,
        room_type: str,
        room_id: int,
        token: Optional[str] = Query(None) # Get token from query parameter
):
    """Handles WebSocket connections for chat rooms (community or event)."""

    # --- Authenticate Connection ---
    user_id = await authenticate_websocket(token)

    if user_id is None:
        # Close connection if authentication failed
        await websocket.accept() # Need to accept before closing with code
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Authentication failed or token missing")
        print(f"WebSocket connection rejected for room {room_type}_{room_id} due to auth failure.")
        return

    # --- Validate Room ---
    valid_room_types = ["community", "event"]
    if room_type not in valid_room_types:
        await websocket.accept() # Accept before closing
        await websocket.close(code=status.WS_1003_UNSUPPORTED_DATA, reason="Invalid room type")
        print(f"WebSocket connection rejected for User {user_id}: Invalid room type '{room_type}'")
        return
    # TODO: Add check if room_id exists in DB and if user has permission to join?

    room_key = f"{room_type}_{room_id}"

    # --- Connect using Manager ---
    # Pass authenticated user_id to the manager
    await manager.connect(websocket, room_key, user_id)

    try:
        # --- Message Handling Loop ---
        while True:
            data = await websocket.receive_text()
            print(f"WS Received in {room_key} from User {user_id}: {data}") # Log user ID

            # --- Process incoming message ---
            try:
                message_data = json.loads(data)
                content = message_data.get('content')

                if not content or not isinstance(content, str) or not content.strip():
                    log_message = "WS Warning: Received message without valid content."
                    print(log_message)
                    # Optionally send error back to the specific client
                    await websocket.send_text(json.dumps({"error": log_message, "type": "error"}))
                    continue

                # *** CRITICAL: Use the user_id associated with this specific connection ***
                # sender_user_id = manager.get_user_id(websocket, room_key) # Get user_id from manager (less reliable if ws object changes?)
                sender_user_id = user_id # Use the user_id established at connection time

                if sender_user_id is None:
                    # This shouldn't happen if connect stored it, but handle defensively
                    print(f"WS CRITICAL ERROR: Could not determine sender user ID for connection in {room_key}. Dropping message.")
                    await websocket.send_text(json.dumps({"error": "Internal server error: Cannot identify sender.", "type": "error"}))
                    continue # Skip processing this message

                # --- Save message to DB ---
                conn = None
                try:
                    conn = get_db_connection()
                    cursor = conn.cursor()
                    msg_community_id = room_id if room_type == "community" else None
                    msg_event_id = room_id if room_type == "event" else None

                    # Use the CORRECT sender_user_id
                    created_message_dict = crud.create_chat_message_db(
                        cursor,
                        user_id=sender_user_id,
                        content=content.strip(), # Sanitize content slightly
                        community_id=msg_community_id,
                        event_id=msg_event_id
                    )
                    conn.commit()

                    if created_message_dict:
                        # Prepare Pydantic model for broadcasting
                        broadcast_obj = schemas.ChatMessageData(**created_message_dict)
                        broadcast_json = broadcast_obj.model_dump_json() # Pydantic v2
                        # broadcast_json = broadcast_obj.json() # Pydantic v1

                        await manager.broadcast(broadcast_json, room_key)
                        print(f"✅ WS Broadcasted from User {sender_user_id}: {broadcast_json[:100]}...")
                    else:
                        print(f"WS Error: Failed to save message to DB for User {sender_user_id}.")
                        await websocket.send_text(json.dumps({"error": "Failed to save message.", "type": "error"}))

                except psycopg2.Error as db_error:
                    if conn: conn.rollback()
                    print(f"WS DB Error processing message from User {sender_user_id}: {db_error}")
                    await websocket.send_text(json.dumps({"error": f"Database error: {db_error}", "type": "error"}))
                except Exception as db_e:
                    if conn: conn.rollback()
                    print(f"WS Generic DB Error processing message from User {sender_user_id}: {db_e}")
                    await websocket.send_text(json.dumps({"error": "Failed processing message.", "type": "error"}))
                finally:
                    if conn: conn.close()
                # --- End DB interaction ---

            except json.JSONDecodeError:
                print(f"WS Error: Received invalid JSON from User {user_id}.")
                await websocket.send_text(json.dumps({"error": "Invalid message format. Send JSON with 'content' key.", "type": "error"}))
            except Exception as e:
                print(f"WS Error processing received data from User {user_id}: {e}")
                # Avoid sending detailed errors back generally
                await websocket.send_text(json.dumps({"error": "Error processing message.", "type": "error"}))

    except WebSocketDisconnect as ws_exc:
        print(f"WebSocket disconnected for User {user_id} from {room_key}: Code {ws_exc.code}, Reason: {ws_exc.reason}")
        # Manager disconnect is handled below in finally
    except Exception as e:
        print(f"Error in WebSocket handler for User {user_id} in {room_key}: {e}")
        # Try to close gracefully if possible
        try:
            await websocket.close(code=status.WS_1011_INTERNAL_ERROR)
        except:
            pass # Ignore errors during close after another error
    finally:
        # Ensure cleanup happens
        manager.disconnect(websocket, room_key)
        print(f"Cleaned up connection for User {user_id} from {room_key}")