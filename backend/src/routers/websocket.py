# backend/src/routers/websocket.py
import json
import jwt
import os
import traceback # <--- Import traceback for detailed error logging
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status, Query, HTTPException
from typing import Optional
import psycopg2
from datetime import datetime, timezone

from .. import schemas, crud, auth, security
from ..database import get_db_connection, update_last_seen
from ..connection_manager import manager

router = APIRouter(tags=["WebSocket"])

# --- Direct Token Validation (No Depends) ---
async def validate_token_direct(token: Optional[str]) -> Optional[int]:
    # ... (Keep the same implementation) ...
    if not token: print("WS Token Direct Validate: No token."); return None
    try:
        payload = jwt.decode(token, auth.SECRET_KEY, algorithms=[auth.ALGORITHM]); user_id = payload.get("user_id")
        if user_id is None: print("WS Token Direct Validate: Payload missing user_id."); return None
        user_id_int = int(user_id); print(f"WS Token Direct Validate: User {user_id_int} validated.")
        try: update_last_seen(user_id_int)
        except Exception as e: print(f"WS Warning: Failed last_seen update: {e}")
        return user_id_int
    except Exception as e: print(f"WS Token Direct Validate: Error - {e}"); return None

# --- Direct API Key Validation (No Depends) ---
async def validate_api_key_direct(api_key: Optional[str]) -> bool:
    # ... (Keep the same implementation) ...
     if not security.VALID_API_KEY: print("WS API Key Direct Validate: Server key not configured."); return False
     if not api_key: print("WS API Key Direct Validate: No key provided."); return False
     is_valid = (api_key == security.VALID_API_KEY); print(f"WS API Key Direct Validate: Provided key validation result: {is_valid}"); return is_valid

@router.websocket("/ws/{room_type}/{room_id}")
async def websocket_endpoint(
    websocket: WebSocket,
    room_type: str,
    room_id: int,
    token: Optional[str] = Query(None),
    api_key: Optional[str] = Query(None) # Assuming API key validation is added
):
    user_id: Optional[int] = None
    room_key: Optional[str] = None
    accepted = False

    try:
        await websocket.accept()
        accepted = True
        print(f"WS connection accepted (pre-auth) for {room_type}_{room_id}.")

        # --- Perform Validations ---
        # (Keep your existing API Key and Token validation logic here)
        is_api_key_valid = await validate_api_key_direct(api_key) # Assuming this helper exists
        if not is_api_key_valid:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid API Key"); return

        user_id = await validate_token_direct(token) # Assuming this helper exists
        if user_id is None:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid Token"); return

        print(f"WS connection fully authenticated post-accept for User {user_id}.")

        # --- Validate Room Type ---
        valid_room_types = ["community", "event"]
        if room_type not in valid_room_types:
             await websocket.close(code=status.WS_1003_UNSUPPORTED_DATA, reason="Invalid room type"); return

        room_key = f"{room_type}_{room_id}"
        print(f"WS Endpoint: Determined room key: {room_key}")

        # --- Connect to Manager ---
        await manager.connect(websocket, room_key, user_id)
        print(f"WS Endpoint: Manager connect successful for User {user_id} / {room_key}. Entering loop.")

        # --- Message Handling Loop ---
        while True:
            print(f"--- WS Endpoint DEBUG --- User {user_id} / {room_key} waiting for message...")
            data = await websocket.receive_text()
            # Use the user_id established at connection time for this specific websocket instance
            sender_user_id = user_id
            print(f"WS Received in {room_key} from User {sender_user_id}: {data}")

            # --- Process incoming message ---
            try:
                message_data = json.loads(data)
                content = message_data.get('content')

                # Validate content
                if not content or not isinstance(content, str) or not content.strip():
                    log_message = "WS Warning: Received message without valid 'content' string."
                    print(log_message)
                    await websocket.send_text(json.dumps({"error": log_message, "type": "error"}))
                    continue # Wait for next message

                # --- Save message to DB ---
                conn = None
                try:
                    conn = get_db_connection()
                    cursor = conn.cursor()
                    msg_community_id = room_id if room_type == "community" else None
                    msg_event_id = room_id if room_type == "event" else None

                    # Use the sender_user_id obtained from the authenticated connection
                    created_message_dict = crud.create_chat_message_db(
                        cursor,
                        user_id=sender_user_id,
                        content=content.strip(), # Use sanitized content
                        community_id=msg_community_id,
                        event_id=msg_event_id
                    )
                    conn.commit()

                    if created_message_dict:
                        # Message saved successfully, prepare for broadcast
                        print(f"✅ WS Message from User {sender_user_id} saved to DB (ID: {created_message_dict.get('message_id', 'N/A')}).")
                        broadcast_obj = schemas.ChatMessageData(**created_message_dict)
                        # Use model_dump_json for Pydantic v2+, json() for v1
                        broadcast_json = broadcast_obj.model_dump_json() if hasattr(broadcast_obj, 'model_dump_json') else broadcast_obj.json()

                        # --- Broadcast Logic with Logging ---
                        print(f"--- WS DEBUG --- About to broadcast to {room_key}: {broadcast_json[:100]}...")
                        try:
                            await manager.broadcast(broadcast_json, room_key)
                            print(f"--- WS DEBUG --- Broadcast call completed for {room_key}.")
                        except Exception as broadcast_err:
                            print(f"--- WS ERROR --- Error during manager.broadcast for {room_key}: {broadcast_err}")
                            import traceback
                            traceback.print_exc()
                        # --- End Broadcast Logic ---

                    else:
                        # DB insertion function returned None/empty
                        print(f"WS Error: Failed to save message to DB for User {sender_user_id} (CRUD function returned None).")
                        await websocket.send_text(json.dumps({"error": "Failed to save message.", "type": "error"}))

                except psycopg2.Error as db_error: # Catch specific DB errors
                     if conn: conn.rollback()
                     print(f"WS DB Error (psycopg2) from User {sender_user_id}: {db_error}")
                     await websocket.send_text(json.dumps({"error": f"Database error processing message.", "type": "error"}))
                except Exception as db_e: # Catch other exceptions during DB interaction
                      if conn: conn.rollback()
                      print(f"WS Generic DB Error from User {sender_user_id}: {db_e}")
                      import traceback
                      traceback.print_exc()
                      await websocket.send_text(json.dumps({"error": "Failed processing message data.", "type": "error"}))
                finally:
                     if conn: conn.close()
                # --- End DB interaction ---

            except json.JSONDecodeError:
                print(f"WS Error: Received invalid JSON from User {sender_user_id}.")
                await websocket.send_text(json.dumps({"error": "Invalid message format. Send JSON with 'content' key.", "type": "error"}))
            except Exception as proc_e: # Catch errors during message content processing
                 print(f"WS Error processing received data content from User {sender_user_id}: {proc_e}")
                 import traceback
                 traceback.print_exc()
                 await websocket.send_text(json.dumps({"error": "Error processing message content.", "type": "error"}))
            # --- End Inner processing ---

    except WebSocketDisconnect as ws_exc:
        # Log normal disconnects, reason is important
        print(f"WebSocket disconnected normally for User {user_id} from {room_key}: Code {ws_exc.code}, Reason: {ws_exc.reason}")
    except Exception as e:
         # Log unexpected errors within the main try block
         print(f"--- !!! UNHANDLED EXCEPTION in WS Handler for User {user_id} !!! ---")
         import traceback
         print(f"Error Type: {type(e).__name__}"); print(f"Error Details: {e}"); print("Traceback:"); print(traceback.format_exc())
         print(f"------------------------------------------------------------------")
         if accepted and websocket.client_state == websocket.client_state.CONNECTED:
              try: await websocket.close(code=status.WS_1011_INTERNAL_ERROR, reason="Internal server error")
              except: pass # Ignore errors during forced close
         else: print("WS Info: Cannot close socket gracefully (already closed or not accepted).")
    finally:
        # Ensure disconnection from manager ONLY if room_key was successfully determined
        if user_id is not None and room_key:
             manager.disconnect(websocket, room_key)
             print(f"Cleaned up WS connection via finally for User {user_id} from {room_key}")
        else:
             client_host = websocket.client.host if websocket.client else 'Unknown'
             client_port = websocket.client.port if websocket.client else '?'
             print(f"Cleaned up WS connection via finally (User/Room Unknown or Pre-Manager Connect) from {client_host}:{client_port}")

