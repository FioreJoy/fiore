# backend/utils.py
import os
import shutil
import uuid
import base64
import io
from PIL import Image
from fastapi import UploadFile
from typing import Optional, Dict
from minio import Minio # <-- Add import
from minio.error import S3Error # <-- Add import
from dotenv import load_dotenv

load_dotenv() # Ensure env vars are loaded

IMAGE_DIR = "user_images" # Keep for potential fallback or local caching if needed

# --- MinIO Configuration ---
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "connections-media")
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
        # Check if bucket exists, create if not
        found = minio_client.bucket_exists(MINIO_BUCKET)
        if not found:
            minio_client.make_bucket(MINIO_BUCKET)
            print(f"MinIO Bucket '{MINIO_BUCKET}' created.")
            # Optional: Set public read policy (use with caution!)
            # from minio.commonconfig import Policy
            # minio_client.set_bucket_policy(MINIO_BUCKET, Policy.READ_ONLY)
            # print(f"Bucket '{MINIO_BUCKET}' policy set to public read.")
        else:
            print(f"MinIO Bucket '{MINIO_BUCKET}' already exists.")
        print(f"✅ MinIO client initialized for endpoint: {MINIO_ENDPOINT}")
    except Exception as e:
        print(f"❌ Failed to initialize MinIO client: {e}")
        minio_client = None
else:
    print("⚠️ MinIO environment variables not fully set. MinIO integration disabled.")

# --- MinIO Upload Utility ---
async def upload_file_to_minio(
        file: UploadFile,
        object_name_prefix: str = "uploads/"
) -> Optional[str]:
    """Uploads an UploadFile object to MinIO and returns the object name."""
    if not minio_client or not file or not file.filename:
        print("MinIO client not available or invalid file.")
        return None

    try:
        # Generate a unique filename
        file_extension = os.path.splitext(file.filename)[1].lower()
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        object_name = os.path.join(object_name_prefix, unique_filename).replace("\\", "/") # Ensure forward slashes

        # Read file content
        contents = await file.read()
        file_size = len(contents)
        content_type = file.content_type

        # Use put_object with BytesIO
        minio_client.put_object(
            MINIO_BUCKET,
            object_name,
            io.BytesIO(contents),
            length=file_size,
            content_type=content_type
        )
        print(f"✅ Successfully uploaded {object_name} to MinIO bucket {MINIO_BUCKET}")
        # Return the object name (path within the bucket)
        return object_name
    except S3Error as e:
        print(f"❌ MinIO S3 Error during upload: {e}")
        return None
    except Exception as e:
        print(f"❌ General error during MinIO upload: {e}")
        return None
    finally:
        await file.close()

# --- MinIO URL Generation ---
def get_minio_url(object_name: Optional[str]) -> Optional[str]:
    """Generates a publicly accessible URL for a MinIO object."""
    if not minio_client or not object_name:
        return None

    # Construct the URL based on endpoint, bucket, and object name
    # This assumes the bucket is publicly readable or you handle signed URLs elsewhere
    protocol = "https" if MINIO_USE_SSL else "http"
    # Basic URL construction - adjust if your MinIO setup needs different pathing
    url = f"{protocol}://{MINIO_ENDPOINT}/{MINIO_BUCKET}/{object_name}"
    # print(f"Generated MinIO URL: {url}") # Debugging
    return url

    # --- Alternative: Pre-signed URL (more secure if bucket isn't public) ---
    # try:
    #     presigned_url = minio_client.presigned_get_object(
    #         MINIO_BUCKET,
    #         object_name,
    #         expires=timedelta(hours=1) # Example: URL valid for 1 hour
    #     )
    #     return presigned_url
    # except S3Error as e:
    #     print(f"❌ MinIO S3 Error generating presigned URL: {e}")
    #     return None
    # except Exception as e:
    #      print(f"❌ General error generating presigned URL: {e}")
    #      return None

# def save_image_from_base64(base64_string: str, username: str) -> Optional[str]:
#     """Decodes a Base64 string, saves it as an image, and returns the relative file path."""
#     if not base64_string:
#         return None
#     try:
#         # Ensure the string is pure Base64 data without prefixes like "data:image/jpeg;base64,"
#         if ',' in base64_string:
#              base64_string = base64_string.split(',')[1]
#
#         image_data = base64.b64decode(base64_string)
#         image = Image.open(io.BytesIO(image_data))
#
#         # Create the directory if it doesn't exist
#         os.makedirs(IMAGE_DIR, exist_ok=True)
#
#         file_extension = image.format.lower() if image.format else 'jpeg' # Default extension
#         filename = f"{username}_{uuid.uuid4()}.{file_extension}"
#         # Save relative path for database storage
#         relative_path = os.path.join(IMAGE_DIR, filename)
#         image.save(relative_path) # Save using the relative path
#         print(f"Image saved via base64: {relative_path}")
#         return relative_path
#     except Exception as e:
#         print(f"Error saving base64 image for {username}: {e}")
#         return None
#
#
# async def save_image_multipart(image: UploadFile, username: str) -> Optional[str]:
#     """Saves an uploaded image and returns the relative file path."""
#     if not image or not image.filename:
#         return None
#     try:
#         # Create the directory if it doesn't exist
#         os.makedirs(IMAGE_DIR, exist_ok=True)
#
#         # Sanitize filename and create unique name
#         file_extension = image.filename.split(".")[-1].lower()
#         if not file_extension: file_extension = 'jpeg' # Default
#         filename = f"{username}_{uuid.uuid4()}.{file_extension}"
#         relative_path = os.path.join(IMAGE_DIR, filename)
#
#         # Use shutil for efficient saving
#         with open(relative_path, "wb") as buffer:
#             shutil.copyfileobj(image.file, buffer)
#         print(f"Image saved via multipart: {relative_path}")
#         return relative_path
#     except Exception as e:
#         print(f"Error saving multipart image for {username}: {e}")
#         return None
#     finally:
#         await image.close() # Ensure file is closed

def parse_point_string(point_str: str) -> Optional[Dict[str, float]]:
    """Parses POINT '(lon,lat)' string to dict."""
    try:
        # Remove parentheses and split
        coords = point_str.strip('()').split(',')
        if len(coords) == 2:
            lon = float(coords[0].strip())
            lat = float(coords[1].strip())
            return {'longitude': lon, 'latitude': lat}
    except Exception as e:
        print(f"Warning: Could not parse point string '{point_str}': {e}")
    return None

def format_location_for_db(location_str: str) -> str:
    """ Ensures the location string is in the format POINT(lon lat) for DB insertion.
        Assumes input is like '(lon,lat)' """
    try:
        coords = location_str.strip('()').split(',')
        if len(coords) == 2:
            lon = float(coords[0].strip())
            lat = float(coords[1].strip())
            # PostgreSQL POINT format is typically 'lon,lat' or '(lon,lat)' when casting ::point
            # Let's stick to the '(lon,lat)' format which seems to work with ::point cast
            return f'({lon},{lat})'
        else:
             print(f"Warning: Invalid location string format '{location_str}'. Using default.")
             return '(0,0)' # Default point
    except Exception as e:
         print(f"Warning: Error parsing location string '{location_str}': {e}. Using default.")
         return '(0,0)' # Default point

def delete_from_minio(object_name: str) -> bool:
    """Deletes an object from the configured MinIO bucket."""
    if not minio_client or not object_name:
        print(f"MinIO delete skipped: Client not ready or no object name provided ({object_name}).")
        return False
    try:
        print(f"Attempting to delete MinIO object: {object_name} from bucket {MINIO_BUCKET}")
        minio_client.remove_object(MINIO_BUCKET, object_name)
        print(f"✅ Successfully deleted MinIO object: {object_name}")
        return True
    except S3Error as e:
        print(f"❌ MinIO S3 Error during delete of {object_name}: {e}")
        # Depending on error (e.g., NoSuchKey), you might still return True or log differently
        if "NoSuchKey" in str(e):
             print(f"  (Object {object_name} not found in MinIO, possibly already deleted)")
             return True # Treat as success if already gone
        return False
    except Exception as e:
        print(f"❌ General error during MinIO delete of {object_name}: {e}")
        return False
