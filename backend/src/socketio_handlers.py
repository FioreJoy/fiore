# backend/src/socketio_handlers.py
import json
from typing import Optional, Dict, Any
import psycopg2
import traceback
import socketio

from .socketio_manager import authenticate_sio_user_internal, get_sio_db_conn_cursor_internal
from . import crud, utils, schemas

# Define handlers as standalone async functions first
async def handle_sio_connect(sid: str, environ: dict, auth_payload: Optional[dict] = None):
    # We will need the 'sio' instance here to access session, enter_room etc.
    # The register_sio_handlers function will need to make it available,
    # perhaps by setting it as an attribute on the function, or by closures.
    # For now, let's try re-importing it here assuming it's globally set in socketio_manager
    # This is only safe if socketio_manager.sio is guaranteed to be set before this runs.
    from .socketio_manager import sio as sio_instance_for_handler

    if sio_instance_for_handler is None:
        print("SIO HANDLER connect ERROR: sio_instance_for_handler is None!")
        return False # Critical error

    print(f"SIO HANDLER connect (via on_event): *** ENTERED CONNECT HANDLER FOR SID {sid} ***")
    print(f"SIO Handler connect (via on_event): Auth payload received: {auth_payload}")

    user_id = await authenticate_sio_user_internal(auth_payload)
    print(f"SIO Handler connect (via on_event): authenticate_sio_user_internal returned: {user_id} for SID {sid}")

    if user_id is None:
        print(f"SIO Handler connect (via on_event): Auth DENIED for SID: {sid}. Returning False.")
        return False

    async with sio_instance_for_handler.session(sid) as session:
        session['user_id'] = user_id
        session['username'] = "Unknown"
        # ... (rest of session setup logic for username as before)
        conn_handler, cursor_handler = None, None
        try:
            conn_handler, cursor_handler = get_sio_db_conn_cursor_internal()
            db_user = crud.get_user_by_id(cursor_handler, user_id)
            if db_user:
                session['username'] = db_user.get('username', 'N/A')
        except Exception as e:
            print(f"SIO Handler WARN: Could not fetch username for user {user_id} on connect: {e}")
        finally:
            if cursor_handler: cursor_handler.close()
            if conn_handler: conn_handler.close()


    user_room = f"user_{user_id}"
    sio_instance_for_handler.enter_room(sid, user_room)
    print(f"SIO Handler (via on_event): Client {sid} (UID: {user_id}, User: {sio_instance_for_handler.get_session(sid).get('username')}) connected. Joined: {user_room}")
    return True

async def handle_sio_disconnect(sid: str):
    from .socketio_manager import sio as sio_instance_for_handler # Ensure access to sio instance
    if sio_instance_for_handler is None: return
    session_data = sio_instance_for_handler.get_session(sid)
    user_id = session_data.get('user_id') if session_data else 'Unknown'
    print(f"SIO Handler (via on_event): Client {sid} (User ID: {user_id}) disconnected.")

async def handle_sio_join_room(sid: str, data: Dict[str, Any]):
    from .socketio_manager import sio as sio_instance_for_handler
    if sio_instance_for_handler is None: return
    session_data = sio_instance_for_handler.get_session(sid)
    # ... rest of join_room logic using sio_instance_for_handler ...
    user_id = session_data.get('user_id') if session_data else None
    if user_id is None: await sio_instance_for_handler.emit('room_join_error', {'error': 'Authentication required.'}, room=sid); return
    room_key = data.get('room_key')
    if not room_key: await sio_instance_for_handler.emit('room_join_error', {'error': 'Invalid room key.'}, room=sid); return
    print(f"SIO Handler ('join_room'): User {user_id} joining room: {room_key}")
    sio_instance_for_handler.enter_room(sid, room_key)
    await sio_instance_for_handler.emit('room_joined', {'room_key': room_key, 'message': f'You joined {room_key}'}, room=sid)


async def handle_sio_leave_room(sid: str, data: Dict[str, Any]):
    from .socketio_manager import sio as sio_instance_for_handler
    if sio_instance_for_handler is None: return
    session_data = sio_instance_for_handler.get_session(sid)
    # ... rest of leave_room logic using sio_instance_for_handler ...
    user_id = session_data.get('user_id') if session_data else 'Unknown'
    room_key = data.get('room_key')
    if not room_key: await sio_instance_for_handler.emit('room_leave_error', {'error': 'Room key not provided.'}, room=sid); return
    print(f"SIO Handler ('leave_room'): User {user_id} leaving room: {room_key}")
    sio_instance_for_handler.leave_room(sid, room_key)
    await sio_instance_for_handler.emit('room_left', {'room_key': room_key, 'message': f'You left {room_key}'}, room=sid)


async def handle_sio_chat_message(sid: str, data: Dict[str, Any]):
    from .socketio_manager import sio as sio_instance_for_handler
    if sio_instance_for_handler is None: return

    session_data = sio_instance_for_handler.get_session(sid)
    sender_id = session_data.get('user_id')
    if sender_id is None:
        await sio_instance_for_handler.emit('message_error', {'error': 'Authentication error.'}, room=sid)
        return

    room_key = data.get('room_key')
    content = data.get('content', '').strip()
    if not room_key or not content:
        await sio_instance_for_handler.emit('message_error', {'error': 'Room key and content are required.'}, room=sid)
        return

    community_id_db, event_id_db, dm_recipient_id_db, is_dm = None, None, None, False

    try:
        if room_key.startswith('community_'):
            community_id_db = int(room_key.split('_', 1)[1])
        elif room_key.startswith('event_'):
            event_id_db = int(room_key.split('_', 1)[1])
        elif room_key.startswith('dm_'):
            is_dm = True
            parts = room_key.split('_')
            if len(parts) == 3:
                u1 = int(parts[1])
                u2 = int(parts[2])
                # Determine recipient ensuring it's not the sender
                if sender_id == u1:
                    dm_recipient_id_db = u2
                elif sender_id == u2:
                    dm_recipient_id_db = u1
                else:
                    # This case implies sender_id is not part of the dm_ room key,
                    # which might be an issue depending on your logic.
                    # Or, if sender_id must be one of u1 or u2, this is an invalid key for this sender.
                    raise ValueError("Sender not part of this DM room key.")

                if dm_recipient_id_db == sender_id: # Should ideally be caught by the logic above
                    raise ValueError("DM to self is not allowed via this key structure.")
            else:
                raise ValueError("Malformed DM room key.")
        else:
            # This 'else' correctly corresponds to the outer if/elif/elif chain
            raise ValueError("Unknown room key type.")

        # Validate that at least one ID was parsed if it's not a DM that failed parsing earlier
        if not is_dm and community_id_db is None and event_id_db is None:
            # This check might be redundant if the above logic is exhaustive for non-DM keys
            pass # Or raise a more specific error if needed
        elif is_dm and dm_recipient_id_db is None:
            # This means it was identified as 'dm_' but parsing failed to get a valid recipient
            # The specific ValueError for "Malformed DM room key" or "Sender not part of DM"
            # would have already been raised.
            # If we reach here, it implies a logical flaw in the above DM parsing.
            raise ValueError("Failed to parse DM recipient ID.")


    except ValueError as e:
        await sio_instance_for_handler.emit('message_error', {'error': f'Invalid room key: {e}'}, room=sid)
        return
    # Continue with the rest of the function (database operations, emits, etc.)
    # ... (rest of your function from conn_msg, cursor_msg = None, None; ...)

    conn_msg, cursor_msg = None, None; created_message_dict = None
    try:
        conn_msg, cursor_msg = get_sio_db_conn_cursor_internal()
        created_message_dict = crud.create_chat_message_db( cursor_msg, user_id=sender_id, content=content, community_id=community_id_db, event_id=event_id_db, dm_recipient_id=dm_recipient_id_db )
        conn_msg.commit()
    except Exception as e:
        if conn_msg: conn_msg.rollback()
        print(f"SIO H DB Error chat_message: {e}"); traceback.print_exc()
        await sio_instance_for_handler.emit('message_error', {'error': 'Server error saving message.'}, room=sid)
        return
    finally:
        if cursor_msg: cursor_msg.close()
        if conn_msg: conn_msg.close()

    if created_message_dict:
        final_payload = dict(created_message_dict)
        conn_det, cur_det = None, None
        try:
            conn_det, cur_det = get_sio_db_conn_cursor_internal()
            db_user = crud.get_user_by_id(cur_det, sender_id) # Fetch sender's details
            sender_username = db_user.get('username', 'Unknown') if db_user else 'Unknown'
            final_payload['sender_username'] = sender_username

            pm = crud.get_user_profile_picture_media(cur_det, sender_id)
            final_payload['profile_image_url'] = utils.get_minio_url(pm.get('minio_object_name')) if pm else None

            mid = final_payload.get('message_id')
            if mid:
                db_media_list = crud.get_media_items_for_chat_message(cur_det, mid)
                final_payload['media'] = [ {**dict(mid), 'url': utils.get_minio_url(dict(mid).get('minio_object_name'))
# This function is called from socketio_manager.py to register all handlers
def register_sio_handlers(): # Takes no argument, will use imported global 'sio'
    from .socketio_manager import sio as sio_instance_for_registration # get the sio instance for registration

    if sio_instance_for_registration is None:
        print("SOCKETIO_HANDLERS CRITICAL ERROR: 'sio' instance (imported as sio_instance_for_registration) is None during handler registration.")
        return

    print(f"SOCKETIO_HANDLERS: register_sio_handlers called. Attaching events to SIO instance: {sio_instance_for_registration}")

    sio_instance_for_registration.on('connect', handle_sio_connect)
    sio_instance_for_registration.on('disconnect', handle_sio_disconnect)
    sio_instance_for_registration.on('join_room', handle_sio_join_room)
    sio_instance_for_registration.on('leave_room', handle_sio_leave_room)
    sio_instance_for_registration.on('chat_message', handle_sio_chat_message)

    print("SOCKETIO_HANDLERS: Event handlers registered using sio.on()")