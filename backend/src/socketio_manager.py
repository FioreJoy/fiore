# backend/src/socketio_manager.py
import socketio
import os
from pathlib import Path
from dotenv import load_dotenv
from typing import Optional, Dict, Any
import jwt
import psycopg2
import traceback

from . import auth, database, crud, schemas, utils

sio: Optional[socketio.AsyncServer] = None
_mgr: Optional[socketio.AsyncRedisManager] = None

def init_socketio_app(fastapi_app_instance):
    global sio, _mgr

    # ... (dotenv, redis, cors config as before) ...
    project_root = Path(__file__).resolve().parent.parent
    dotenv_path = project_root / '.env'
    if dotenv_path.exists(): load_dotenv(dotenv_path=dotenv_path)
    else: print(f"SocketIO Mgr WARN: .env not found at {project_root}")
    REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    SIO_CORS_ALLOWED_ORIGINS_STR = os.getenv("SIO_CORS_ALLOWED_ORIGINS", "*")
    sio_cors_origins_list = [origin.strip() for origin in SIO_CORS_ALLOWED_ORIGINS_STR.split(',') if origin.strip()]
    if not sio_cors_origins_list: sio_cors_origins_list = "*"
    print(f"SocketIO Manager: Using Redis: {REDIS_URL}, SIO CORS: {sio_cors_origins_list}")
    try:
        _mgr = socketio.AsyncRedisManager(REDIS_URL, write_only=False)
        print(f"✅ AsyncRedisManager for SIO initialized.")
    except Exception as e: print(f"❌ Failed AsyncRedisManager SIO: {e}."); _mgr = None

    sio = socketio.AsyncServer(
        async_mode='asgi', client_manager=_mgr,
        cors_allowed_origins=sio_cors_origins_list, logger=True, engineio_logger=True
    )
    print("SOCKETIO_MANAGER: Global 'sio' instance CREATED AND ASSIGNED.")

    from . import socketio_handlers
    socketio_handlers.register_sio_handlers() # CALL THE REGISTRATION FUNCTION
    print("SOCKETIO_MANAGER: socketio_handlers.register_sio_handlers() CALLED.")

    combined_asgi_app = socketio.ASGIApp(
        socketio_server=sio, other_asgi_app=fastapi_app_instance, socketio_path='socket.io'
    )
    if _mgr is None: print("⚠️  Socket.IO using default in-memory manager.")
    return combined_asgi_app

def get_sio_db_conn_cursor_internal() -> tuple[psycopg2.extensions.connection, psycopg2.extensions.cursor]:
    conn = database.get_db_connection()
    return conn, conn.cursor() # Return cursor directly

async def authenticate_sio_user_internal(auth_payload: Optional[dict]) -> Optional[int]:
    print("SIO Auth (mgr-helper): Entered function.")
    # ... (Rest of authenticate_sio_user_internal as defined in my previous message's version of socketio_manager.py)
    if not auth_payload: print("SIO Auth (mgr-helper): auth_payload is None or empty."); return None
    if 'token' not in auth_payload: print("SIO Auth (mgr-helper): 'token' not in auth_payload."); return None
    token = auth_payload['token']
    print(f"SIO Auth (mgr-helper): Token received: {'Yes' if token else 'No'}.")
    try:
        payload = jwt.decode(token, auth.SECRET_KEY, algorithms=[auth.ALGORITHM])
        user_id_from_payload = payload.get("user_id")
        if user_id_from_payload is None: print("SIO Auth (mgr-helper): Token missing 'user_id'."); return None
        user_id = int(user_id_from_payload)
        print(f"SIO Auth (mgr-helper): UID from token: {user_id}")
        sio_conn, sio_cursor = None, None
        try:
            sio_conn, sio_cursor = get_sio_db_conn_cursor_internal()
            db_user = crud.get_user_by_id(sio_cursor, user_id)
            if not db_user: print(f"SIO Auth (mgr-helper): UID {user_id} NOT IN DB."); return None
            print(f"SIO Auth (mgr-helper): UID {user_id} FOUND. Name: {db_user.get('name')}")
            crud.update_user_last_seen(sio_cursor, user_id)
            sio_conn.commit()
            print(f"SIO Auth (mgr-helper): UID {user_id} authenticated, last_seen updated.")
            return user_id
        except Exception as db_err:
            if sio_conn: sio_conn.rollback(); print(f"SIO Auth DB WARN UID {user_id}: {db_err}"); traceback.print_exc(); return None
        finally:
            if sio_cursor: sio_cursor.close();
            if sio_conn: sio_conn.close()
    except jwt.ExpiredSignatureError: print("SIO Auth: Token expired."); return None
    except (jwt.PyJWTError, ValueError) as e: print(f"SIO Auth: Invalid token content: {e}"); return None
    except Exception as e: print(f"SIO Auth: Unexpected token validation error: {e}"); traceback.print_exc(); return None