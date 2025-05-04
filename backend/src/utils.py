# backend/src/utils.py
import os
import shutil
import uuid
import base64
import io
import json # <-- Add json import
from PIL import Image
from fastapi import UploadFile
from typing import Optional, Dict, Any # <-- Add Any
from minio import Minio
from minio.error import S3Error
from dotenv import load_dotenv
from datetime import date, timedelta, datetime, timezone
import mimetypes # To guess mime type if not provided
from .database import get_db_connection

load_dotenv()

IMAGE_DIR = "user_images" # Keep for potential fallback or local caching if needed

# --- MinIO Configuration & Client (Keep as is) ---
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "fiore")
MINIO_USE_SSL = os.getenv("MINIO_USE_SSL", "False").lower() == "true"

minio_client = None
if MINIO_ENDPOINT and MINIO_ACCESS_KEY and MINIO_SECRET_KEY:
    try:
        minio_client = Minio(
            MINIO_ENDPOINT,
            access_key=MINIO_ACCESS_KEY,
            secret_key=MINIO_SECRET_KEY,
            secure=MINIO_USE_SSL
        )
        found = minio_client.bucket_exists(MINIO_BUCKET)
        if not found:
            minio_client.make_bucket(MINIO_BUCKET)
        else:
            print(f"MinIO Bucket '{MINIO_BUCKET}' already exists.")
        print(f"✅ MinIO client initialized for endpoint: {MINIO_ENDPOINT}")
    except Exception as e:
        print(f"❌ Failed to initialize MinIO client: {e}")
        minio_client = None
else:
    print("⚠️ MinIO environment variables not fully set. MinIO integration disabled.")

# --- MinIO Upload Utility (Keep as is) ---
async def upload_file_to_minio(
        file: UploadFile,
        # Define base path structure based on type
        base_path: str = "media/general", # e.g., "media/posts", "media/avatars"
        item_id: Optional[Any] = None, # Optional ID of related item (post_id, user_id)
        generate_uuid_filename: bool = True
) -> Optional[Dict[str, Any]]:
    """
    Uploads file to MinIO under a structured path.
    Returns dict with object_name, mime_type, size, original_filename or None on failure.
    """
    if not minio_client or not file or not file.filename:
        print("MinIO client not available or invalid file.")
        return None

    try:
        # Generate filename and path
        original_filename = file.filename
        file_extension = os.path.splitext(original_filename)[1].lower()
        if generate_uuid_filename:
            unique_filename = f"{uuid.uuid4()}{file_extension}"
        else:
            # Use original filename (sanitize carefully if doing this)
            # Be cautious about collisions or malicious filenames
            safe_filename = "".join(c for c in original_filename if c.isalnum() or c in ['.', '_', '-']).strip()
            if not safe_filename: safe_filename = f"{uuid.uuid4()}{file_extension}" # Fallback
            unique_filename = safe_filename

        # Construct path: base_path / [item_id /] unique_filename
        path_parts = [base_path.rstrip('/')]
        if item_id is not None:
            path_parts.append(str(item_id))
        path_parts.append(unique_filename)
        # Use os.path.join for OS-agnostic paths, then convert backslashes if needed for MinIO/web
        # MinIO typically uses forward slashes like web paths
        object_name = "/".join(path_parts)

        # Read file content
        contents = await file.read(); file_size = len(contents)
        content_type = file.content_type;
        if not content_type or content_type == 'application/octet-stream': content_type, _ = mimetypes.guess_type(original_filename); content_type = content_type or 'application/octet-stream'

        minio_client.put_object(MINIO_BUCKET, object_name, io.BytesIO(contents), length=file_size, content_type=content_type)
        print(f"✅ Successfully uploaded {object_name} ({content_type}, {file_size} bytes) to MinIO bucket {MINIO_BUCKET}")
        return {"minio_object_name": object_name, "mime_type": content_type, "file_size_bytes": file_size, "original_filename": original_filename}
    except S3Error as e:
        print(f"❌ MinIO S3 Error during upload: {e}")
        return None
    except Exception as e:
        print(f"❌ General error during MinIO upload: {e}")
        return None
    finally:
        await file.close()

# --- MinIO URL Generation (Keep as is) ---
def get_minio_url(object_name: Optional[str], expires_in_hours: int = 24) -> Optional[str]: # Increased default expiry
    if not minio_client or not object_name:
        return None
    try:
        presigned_url = minio_client.presigned_get_object(
            MINIO_BUCKET,
            object_name,
            expires=timedelta(hours=expires_in_hours)
        )
        return presigned_url
    except S3Error as e:
        # Log specific MinIO errors if helpful
        print(f"❌ MinIO presign URL Error for {object_name}: Code={e.code}, Message={e.message}")
        return None
    except Exception as e:
        print(f"❌ General Error generating presigned URL for {object_name}: {e}")
        # import traceback # Uncomment for deeper debugging if needed
        # traceback.print_exc()
        return None

# --- MinIO Delete Utility (Keep as is) ---
def delete_from_minio(object_name: str) -> bool:
    if not minio_client or not object_name:
        print(f"MinIO delete skipped: Client not ready or no object name ({object_name}).")
        return False
    try:
        print(f"Attempting to delete MinIO object: {object_name} from bucket {MINIO_BUCKET}")
        minio_client.remove_object(MINIO_BUCKET, object_name)
        print(f"✅ Successfully deleted MinIO object: {object_name}")
        return True
    except S3Error as e:
        print(f"❌ MinIO S3 Error during delete of {object_name}: {e}")
        if "NoSuchKey" in str(e):
            print(f"  (Object {object_name} not found in MinIO, treating as deleted)")
            return True
        return False
    except Exception as e:
        print(f"❌ General error during MinIO delete of {object_name}: {e}")
        return False

# --- Location Parsing/Formatting (Keep as is) ---
def parse_point_string(point_str: str) -> Optional[Dict[str, float]]:
    try:
        coords = point_str.strip('()').split(',')
        if len(coords) == 2:
            lon = float(coords[0].strip())
            lat = float(coords[1].strip())
            return {'longitude': lon, 'latitude': lat}
    except Exception as e:
        print(f"Warning: Could not parse point string '{point_str}': {e}")
    return None

def format_location_for_db(location_str: str) -> str:
    try:
        coords = location_str.strip('()').split(',')
        if len(coords) == 2:
            lon = float(coords[0].strip())
            lat = float(coords[1].strip())
            return f'({lon},{lat})'
        else:
            print(f"Warning: Invalid location string format '{location_str}'. Using default.")
            return '(0,0)'
    except Exception as e:
        print(f"Warning: Error parsing location string '{location_str}': {e}. Using default.")
        return '(0,0)'

# --- *** NEW: Helper for Parsing agtype Results *** ---
def parse_agtype(value: Any) -> Any:
    """
    Attempts to parse common agtype results (often JSON strings) into Python types.
    Returns the original value if parsing fails or isn't needed.
    """
    if isinstance(value, str):
        # Try parsing if it looks like JSON object or array
        if (value.startswith('{') and value.endswith('}')) or \
                (value.startswith('[') and value.endswith(']')):
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                # It wasn't valid JSON, return the original string
                return value
        # Handle potential quoted strings from AGE (e.g., '"username"')
        elif value.startswith('"') and value.endswith('"') and len(value) >= 2:
            return value[1:-1] # Return string without quotes
        else:
            return value # Return plain string as is
    # If it's already a basic Python type (int, float, bool, None), return it directly
    elif isinstance(value, (int, float, bool)) or value is None:
        return value
    # Add handling for other potential agtype representations if encountered
    else:
        # Fallback: return the value as is if type is unexpected
        print(f"Warning: Unexpected type in parse_agtype: {type(value)}, value: {value}")
        return value

# --- *** END NEW HELPER *** ---
# --- Helper to safely quote strings for embedding in Cypher ---
def quote_cypher_string(value):
    if value is None: return 'null'
    if isinstance(value, (datetime, date)): return f"'{value.isoformat()}'"
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, (int, float)): return str(value)
    str_val = str(value).replace("'", "''") # Escape for SQL embedding first
    # Further escape for Cypher string literal if needed, though $$ usually handles it
    # str_val = str_val.replace("\\", "\\\\").replace("'", "\\'") # Cypher escaping
    return f"'{str_val}'" # Return as SQL literal string
# --- Image Saving Helpers (Remove if using MinIO exclusively) ---
# def save_image_from_base64(...) # Remove if not used
# async def save_image_multipart(...) # Remove if not used

def delete_media_item_db_and_file(media_id: int, minio_object_name: Optional[str]) -> bool:
    """
    Attempts to delete a media item record from the DB and its corresponding file from MinIO.
    Uses a separate DB connection for deletion commit.
    Best effort: Logs errors but tries to proceed. Returns True if DB delete succeeded.
    """
    db_deleted = False
    conn = None
    try:
        print(f"UTILS: Attempting to delete media item record ID: {media_id}")
        conn = get_db_connection() # Use the imported function
        cursor = conn.cursor()
        # ... (DELETE statements remain the same) ...
        print(f"  - Deleting links for media {media_id}...")
        cursor.execute("DELETE FROM public.post_media WHERE media_id = %s;", (media_id,))
        cursor.execute("DELETE FROM public.reply_media WHERE media_id = %s;", (media_id,))
        cursor.execute("DELETE FROM public.chat_message_media WHERE media_id = %s;", (media_id,))
        cursor.execute("DELETE FROM public.user_profile_picture WHERE media_id = %s;", (media_id,))
        cursor.execute("DELETE FROM public.community_logo WHERE media_id = %s;", (media_id,))
        print(f"  - Deleting main record for media {media_id}...")
        cursor.execute("DELETE FROM public.media_items WHERE id = %s;", (media_id,))
        rows_affected = cursor.rowcount
        conn.commit()
        db_deleted = rows_affected > 0
        print(f"UTILS: DB media item record deletion result (ID: {media_id}): Success={db_deleted}")
    except Exception as db_err:
        print(f"UTILS ERROR: Failed to delete media item record ID {media_id}: {db_err}")
        if conn: conn.rollback()
    finally:
        if conn: conn.close()

    # --- Delete MinIO File (remains the same) ---
    file_deleted = False
    if minio_object_name:
        print(f"UTILS: Attempting to delete MinIO file: {minio_object_name}")
        file_deleted = delete_from_minio(minio_object_name)
        print(f"UTILS: MinIO file deletion result ({minio_object_name}): Success={file_deleted}")
    else:
        print("UTILS: Skipping MinIO file deletion (no object name provided).")

    print(f"UTILS: Overall deletion status for Media ID {media_id} - DB Deleted: {db_deleted}, File Deleted: {file_deleted}")
    return db_deleted