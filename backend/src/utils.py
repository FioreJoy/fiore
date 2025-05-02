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
from datetime import timedelta, datetime, timezone

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
        object_name_prefix: str = "uploads/"
) -> Optional[str]:
    if not minio_client or not file or not file.filename:
        print("MinIO client not available or invalid file.")
        return None
    try:
        file_extension = os.path.splitext(file.filename)[1].lower()
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        object_name = os.path.join(object_name_prefix, unique_filename).replace("\\", "/")
        contents = await file.read()
        file_size = len(contents)
        content_type = file.content_type
        minio_client.put_object(
            MINIO_BUCKET, object_name, io.BytesIO(contents),
            length=file_size, content_type=content_type
        )
        print(f"✅ Successfully uploaded {object_name} to MinIO bucket {MINIO_BUCKET}")
        return object_name
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

# --- Image Saving Helpers (Remove if using MinIO exclusively) ---
# def save_image_from_base64(...) # Remove if not used
# async def save_image_multipart(...) # Remove if not used