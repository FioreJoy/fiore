# backend/src/routers/websocket.py
import json
import jwt
import os
import traceback
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status, Query, HTTPException
from typing import Optional
import psycopg2
from datetime import datetime, timezone

# Use the central crud import
from .. import schemas, crud, auth, security
from ..database import get_db_connection, update_last_seen
from ..connection_manager import manager

router = APIRouter(tags=["WebSocket"])

# --- Direct Token Validation (Keep existing implementation) ---
async def validate_token_direct(token: Optional[str]) -> Optional[int]:
    if not token: print("WS Token Direct Validate: No token."); return None
    try:
        payload = jwt.decode(token, auth.SECRET_KEY, algorithms=[auth.ALGORITHM]); user_id = payload.get("user_id")
        if user_id is None: print("WS Token Direct Validate: Payload missing user_id."); return None
        user_id_int = int(user_id); print(f"WS Token Direct Validate: User {user_id_int} validated.")
        try: update_last_seen(user_id_int) # Update last seen on successful WS connect
        except Exception as e: print(f"WS Warning: Failed last_seen update: {e}")
        return user_id_int
    except Exception as e: print(f"WS Token Direct Validate: Error - {e}"); return None

# --- Direct API Key Validation (Keep existing implementation) ---
async def validate_api_key_direct(api_key: Optional[str]) -> bool:
    if not security.VALID_API_KEY: print("WS API Key Direct Validate: Server key not configured."); return False
    if not api_key: print("WS API Key Direct Validate: No key provided."); return False
    is_valid = (api_key == security.VALID_API_KEY); print(f"WS API Key Direct Validate: Provided key validation result: {is_valid}"); return is_valid

@router.websocket("/ws/{room_type}/{room_id}")
async def websocket_endpoint(
        websocket: WebSocket,
        room_type: str, # "community" or "event"
        room_id: int,
        token: Optional[str] = Query(None), # Auth token
        api_key: Optional[str] = Query(None) # API Key
):
    user_id: Optional[int] = None
    room_key: Optional[str] = None
    accepted = False

    try:
        # --- Initial Accept & Authentication ---
        await websocket.accept()
        accepted = True
        print(f"WS connection accepted (pre-auth) for {room_type}_{room_id}.")

        # Validate API Key first
        is_api_key_valid = await validate_api_key_direct(api_key)
        if not is_api_key_valid:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid API Key"); return

        # Validate JWT Token
        user_id = await validate_token_direct(token)
        if user_id is None:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid Token"); return

        print(f"WS connection authenticated post-accept for User {user_id}.")

        # --- Validate Room and Connect ---
        valid_room_types = ["community", "event"]
        if room_type not in valid_room_types:
            await websocket.close(code=status.WS_1003_UNSUPPORTED_DATA, reason="Invalid room type"); return

        room_key = f"{room_type}_{room_id}"
        print(f"WS Determined room key: {room_key}")

        await manager.connect(websocket, room_key, user_id)
        print(f"WS Manager connect successful for User {user_id} / {room_key}. Entering loop.")

        # --- Message Handling Loop ---
        while True:
            # print(f"--- WS DEBUG --- User {user_id} / {room_key} waiting for message...")
            data = await websocket.receive_text()
            sender_user_id = user_id # Use ID established at connection time
            print(f"WS Received in {room_key} from User {sender_user_id}: {data[:100]}...") # Log truncated

            try:
                message_data = json.loads(data)
                content = message_data.get('content')

                if not content or not isinstance(content, str) or not content.strip():
                    print(f"WS Warning: User {sender_user_id} sent invalid message content.")
                    await websocket.send_text(json.dumps({"error": "Invalid message content.", "type": "error"}))
                    continue

                # --- Save message to DB using central CRUD import ---
                conn = None
                try:
                    conn = get_db_connection()
                    cursor = conn.cursor()
                    msg_community_id = room_id if room_type == "community" else None
                    msg_event_id = room_id if room_type == "event" else None

                    # Call the chat CRUD function (operates on public.chat_messages)
                    created_message_dict = crud.create_chat_message_db(
                        cursor, user_id=sender_user_id, content=content.strip(),
                        community_id=msg_community_id, event_id=msg_event_id
                    )
                    conn.commit() # Commit successful insert

                    if created_message_dict:
                        print(f"✅ WS Message from User {sender_user_id} saved (ID: {created_message_dict.get('message_id', 'N/A')}). Broadcasting...")
                        broadcast_obj = schemas.ChatMessageData(**created_message_dict)
                        broadcast_json = broadcast_obj.model_dump_json() if hasattr(broadcast_obj, 'model_dump_json') else broadcast_obj.json()

                        await manager.broadcast(broadcast_json, room_key)
                        print(f"📢 WS Broadcast completed for {room_key}.")
                    else:
                        print(f"WS Error: Failed to save message to DB for User {sender_user_id} (CRUD returned None).")
                        await websocket.send_text(json.dumps({"error": "Failed to save message.", "type": "error"}))

                except psycopg2.Error as db_error:
                    if conn: conn.rollback()
                    print(f"WS DB Error (psycopg2) saving message from User {sender_user_id}: {db_error}")
                    await websocket.send_text(json.dumps({"error": f"Database error processing message.", "type": "error"}))
                except Exception as db_e:
                    if conn: conn.rollback()
                    print(f"WS Generic Error saving message from User {sender_user_id}: {db_e}")
                    traceback.print_exc()
                    await websocket.send_text(json.dumps({"error": "Failed processing message data.", "type": "error"}))
                finally:
                    if conn: conn.close()
                # --- End DB interaction ---

            except json.JSONDecodeError:
                print(f"WS Error: Received invalid JSON from User {sender_user_id}.")
                await websocket.send_text(json.dumps({"error": "Invalid message format.", "type": "error"}))
            except Exception as proc_e:
                print(f"WS Error processing received data content from User {sender_user_id}: {proc_e}")
                traceback.print_exc()
                await websocket.send_text(json.dumps({"error": "Error processing message content.", "type": "error"}))
            # --- End Inner processing ---

    except WebSocketDisconnect as ws_exc:
        print(f"WebSocket disconnected (User {user_id}, Room {room_key}): Code {ws_exc.code}, Reason: {ws_exc.reason}")
    except Exception as e:
        print(f"--- !!! UNHANDLED EXCEPTION in WS Handler (User {user_id}, Room {room_key}) !!! ---")
        traceback.print_exc()
        if accepted and websocket.client_state == websocket.client_state.CONNECTED:
            try: await websocket.close(code=status.WS_1011_INTERNAL_ERROR, reason="Internal server error")
            except: pass
        else: print("WS Info: Cannot close socket gracefully.")
    finally:
        # Ensure disconnection from manager ONLY if room_key was determined
        if user_id is not None and room_key is not None:
            manager.disconnect(websocket, room_key)
            print(f"WS Cleaned up connection via finally for User {user_id} from {room_key}")
        else:
            client_host = websocket.client.host if websocket.client else 'Unknown'
            client_port = websocket.client.port if websocket.client else '?'
            print(f"WS Cleaned up connection via finally (User/Room Unknown) from {client_host}:{client_port}")