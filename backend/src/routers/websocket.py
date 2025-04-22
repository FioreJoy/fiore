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
    api_key: Optional[str] = Query(None)
):
    # --- LOG AT THE VERY START ---
    print(f"--- WS Endpoint START --- Received connection attempt for {room_type}_{room_id}")
    # --- END LOG ---

    user_id: Optional[int] = None
    room_key: Optional[str] = None
    accepted = False # Flag to track if accept was called

    try:
        # --- Accept the connection FIRST ---
        await websocket.accept()
        accepted = True # Mark as accepted
        print(f"WS connection accepted (pre-auth) for {room_type}_{room_id}.")

        # --- Perform Validations ---
        print("--- WS Endpoint DEBUG --- Validating API Key...")
        is_api_key_valid = await validate_api_key_direct(api_key)
        if not is_api_key_valid:
            reason = "Invalid API Key"; print(f"WS closing connection post-accept: {reason}")
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason=reason); return

        print("--- WS Endpoint DEBUG --- Validating Token...")
        user_id = await validate_token_direct(token)
        if user_id is None:
            reason = "Invalid Token"; print(f"WS closing connection post-accept: {reason}")
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason=reason); return

        print(f"WS connection fully authenticated post-accept for User {user_id}.")

        # --- Validate Room Type ---
        print("--- WS Endpoint DEBUG --- Validating Room Type...")
        valid_room_types = ["community", "event"]
        if room_type not in valid_room_types:
            reason="Invalid room type"; print(f"WS closing for User {user_id}: {reason}")
            await websocket.close(code=status.WS_1003_UNSUPPORTED_DATA, reason=reason); return

        room_key = f"{room_type}_{room_id}"
        print(f"--- WS Endpoint DEBUG --- Attempting manager.connect User {user_id} to {room_key}...")

        # --- Connect to Manager ---
        await manager.connect(websocket, room_key, user_id) # This call might error internally

        print(f"--- WS Endpoint DEBUG --- Manager connect successful. Entering loop User {user_id} / {room_key}.")

        # --- Message Loop ---
        while True:
            # Add log right before receive
            print(f"--- WS Endpoint DEBUG --- User {user_id} / {room_key} waiting for message...")
            data = await websocket.receive_text()
            sender_user_id = user_id
            print(f"WS Received in {room_key} from User {sender_user_id}: {data}")
            # ...(Rest of message processing logic)...
            try:
                message_data = json.loads(data); content = message_data.get('content')
                if not content or not isinstance(content, str) or not content.strip(): await websocket.send_text(json.dumps({"error": "Invalid message content.", "type": "error"})); continue
                conn = None
                try:
                    conn = get_db_connection(); cursor = conn.cursor(); msg_comm_id = room_id if room_type == "community" else None; msg_event_id = room_id if room_type == "event" else None
                    created_msg = crud.create_chat_message_db(cursor, user_id=sender_user_id, content=content.strip(), community_id=msg_comm_id, event_id=msg_event_id)
                    conn.commit()
                    if created_msg: msg_obj = schemas.ChatMessageData(**created_msg); await manager.broadcast(msg_obj.model_dump_json(), room_key)
                    else: await websocket.send_text(json.dumps({"error": "Failed to save message.", "type": "error"}))
                except Exception as db_e:
                    if conn: conn.rollback(); print(f"WS DB Error from User {sender_user_id}: {db_e}")
                    await websocket.send_text(json.dumps({"error": "Failed processing message.", "type": "error"}))
                finally:
                    if conn: conn.close()
            except json.JSONDecodeError: await websocket.send_text(json.dumps({"error": "Invalid message format.", "type": "error"}))
            except Exception as proc_e: print(f"WS Error processing data from User {user_id}: {proc_e}"); await websocket.send_text(json.dumps({"error": "Error processing message.", "type": "error"}))
            # --- End Inner processing ---

    except WebSocketDisconnect as ws_exc:
        print(f"WebSocket disconnected normally for User {user_id} from {room_key}: Code {ws_exc.code}, Reason: {ws_exc.reason}")
    except Exception as e:
         print(f"--- !!! UNHANDLED EXCEPTION in WS Handler for User {user_id} !!! ---")
         print(f"Error Type: {type(e).__name__}"); print(f"Error Details: {e}"); print("Traceback:"); print(traceback.format_exc())
         print(f"------------------------------------------------------------------")
         # Check if accepted before trying to close
         if accepted and websocket.client_state == websocket.client_state.CONNECTED:
              try: await websocket.close(code=status.WS_1011_INTERNAL_ERROR, reason="Unhandled server error")
              except RuntimeError as re: print(f"WS Info: Error closing websocket: {re}")
              except Exception as ce: print(f"WS Info: Generic error closing websocket: {ce}")
         else:
              print("--- WS Info --- Cannot close socket gracefully as it might not be connected/accepted.")
    finally:
        if user_id is not None and room_key:
             manager.disconnect(websocket, room_key)
             print(f"Cleaned up WS connection via finally for User {user_id} from {room_key}")
        else:
             client_host = websocket.client.host if websocket.client else 'Unknown'
             client_port = websocket.client.port if websocket.client else '?'
             print(f"Cleaned up WS connection via finally (User/Room Unknown or Pre-Manager Connect) from {client_host}:{client_port}")
