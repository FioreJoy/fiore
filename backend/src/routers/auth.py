# backend/src/routers/auth.py
from fastapi import (
    APIRouter, Depends, HTTPException, status,
    Form, UploadFile, File, Body
)
from typing import List, Optional, Dict, Any # Added Dict, Any
import psycopg2
import bcrypt
import os
import traceback # <-- ADDED IMPORT

# Use BaseMode for JSON body if not using Forms
from pydantic import BaseModel, Field

# Use the central crud import AND import specific auth functions
from .. import schemas, crud, utils, auth # Relative imports
from ..database import get_db_connection
# Ensure MINIO related config/client is accessible
from ..utils import ( # Import specific utils needed
    upload_file_to_minio,
    get_minio_url,
    delete_from_minio,
    delete_media_item_db_and_file,
    format_location_for_db,
    parse_point_string,
    minio_client, # Import the client instance
    MINIO_BUCKET, # Import specific config vars if needed for checks
    MINIO_ENDPOINT
)


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)

# Alternative: JSON body login
@router.post("/login", response_model=schemas.TokenData)
async def login(request: schemas.LoginRequest):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        user = crud.get_user_by_email(cursor, request.email)

        if not user or not bcrypt.checkpw(request.password.encode('utf-8'), user["password_hash"].encode('utf-8')):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials",
            )

        user_id = user["id"]
        access_token = auth.create_access_token(data={"user_id": user_id})

        # Update last seen on login
        crud.update_user_last_seen(cursor, user_id)
        conn.commit()

        # Fetch current profile pic for login response
        profile_media = crud.get_user_profile_picture_media(cursor, user_id)
        image_url = profile_media.get('url') if profile_media else None

        print(f"✅ Token generated for user {user_id}")
        return {"token": access_token, "user_id": user_id, "image_url": image_url}

    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Login Error: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Login failed")
    finally:
        if conn: conn.close()

# --- SIGNUP ---
# This endpoint needs review - currently saves image locally using utils.save_image_multipart
# which likely doesn't exist anymore. Should use MinIO.
@router.post("/signup", status_code=status.HTTP_201_CREATED, response_model=schemas.TokenData)
async def signup(
        name: str = Form(...),
        username: str = Form(...),
        email: str = Form(...),
        password: str = Form(...),
        gender: str = Form(...),
        current_location: str = Form("(0,0)"),
        college: str = Form(...),
        interests: List[str] = Form(...),
        image: Optional[UploadFile] = File(None)
):
    """Creates a new user and returns login token data."""
    conn = None
    minio_object_name = None
    new_media_id = None
    user_id = None

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # --- Create User first (relational + graph vertex) ---
        interests_str = ",".join(interests) if interests else None
        db_location_str = format_location_for_db(current_location)

        # create_user no longer handles image_path
        user_id = crud.create_user(
            cursor, name=name, username=username, email=email, password=password,
            gender=gender, current_location_str=db_location_str, college=college,
            interests_str=interests_str, current_location_address=None # Add address if available from form
        )

        if user_id is None:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="User creation failed in database")
        print(f"Signup: User base created with ID: {user_id}")

        # --- Handle Image Upload and Linking (if image provided) ---
        final_image_url = None
        if image:
            minio_properly_configured = (
                    utils.minio_client is not None and
                    MINIO_ENDPOINT and
                    MINIO_BUCKET
            )
            if not minio_properly_configured:
                # Log warning but allow signup without image
                print("WARN Signup: MinIO not configured, skipping image upload.")
            else:
                object_name_prefix = f"users/{username}/profile" # Use username for path
                upload_info = await upload_file_to_minio(image, object_name_prefix)

                if upload_info and 'minio_object_name' in upload_info:
                    minio_object_name = upload_info['minio_object_name']
                    # Create media item record
                    new_media_id = crud.create_media_item(cursor, uploader_user_id=user_id, **upload_info)
                    if new_media_id:
                        # Link user to media item
                        crud.set_user_profile_picture(cursor, user_id, new_media_id)
                        final_image_url = get_minio_url(minio_object_name) # Get URL for response
                        print(f"Signup: Profile picture uploaded and linked for user {user_id}")
                    else:
                        # Cleanup MinIO if DB record failed
                        print(f"WARN Signup: Failed to create media_item record for {minio_object_name}")
                        if minio_object_name: delete_from_minio(minio_object_name)
                else:
                    print(f"WARN Signup: MinIO upload failed for user {user_id}")

        # --- Commit transaction ---
        conn.commit()
        print(f"✅ User created with ID: {user_id}, Image URL: {final_image_url}")

        # Create token for the new user
        access_token = auth.create_access_token(data={"user_id": user_id})
        return {
            "user_id": user_id,
            "token": access_token,
            "image_url": final_image_url # Return the actual URL if uploaded
        }

    except psycopg2.IntegrityError as e:
        if conn: conn.rollback()
        # Cleanup MinIO upload if DB fails (e.g., username exists)
        if minio_object_name: delete_from_minio(minio_object_name)
        print(f"❌ Signup Error (Integrity): {e}")
        detail = "Username or email already exists."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback()
        if minio_object_name and new_media_id is None: delete_from_minio(minio_object_name)
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        if minio_object_name and new_media_id is None: delete_from_minio(minio_object_name)
        print(f"❌ Signup Error: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        if conn: conn.close()


@router.get("/me", response_model=schemas.UserDisplay)
async def read_users_me(current_user_id: int = Depends(auth.get_current_user)):
    """Fetches details for the currently authenticated user."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        user_db = crud.get_user_by_id(cursor, current_user_id)
        if user_db is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

        user_display_data = dict(user_db)

        # Parse location point string
        location_str = user_db.get('current_location')
        user_display_data['current_location'] = parse_point_string(str(location_str)) if location_str else None

        # Split interests string
        interests_db = user_db.get('interest')
        user_display_data['interests'] = interests_db.split(',') if interests_db and interests_db.strip() else []

        # Get profile picture URL from media tables
        profile_media = crud.get_user_profile_picture_media(cursor, current_user_id)
        user_display_data['image_url'] = profile_media.get('url') if profile_media else None
        user_display_data['image_path'] = profile_media.get('minio_object_name') if profile_media else None # Pass path if schema needs it

        # Add defaults for potentially missing counts/status if schema expects them
        user_display_data.setdefault('followers_count', 0)
        user_display_data.setdefault('following_count', 0)
        user_display_data.setdefault('is_following', False) # Relevant for viewing other profiles

        print(f"DEBUG GET /me: User data prepared: {user_display_data}")
        return schemas.UserDisplay(**user_display_data)

    except Exception as e:
        print(f"❌ Error fetching /me: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to fetch user details")
    finally:
        if conn: conn.close()


@router.put("/me", response_model=schemas.UserDisplay)
async def update_user_profile_endpoint(
        current_user_id: int = Depends(auth.get_current_user),
        name: Optional[str] = Form(None),
        username: Optional[str] = Form(None),
        gender: Optional[str] = Form(None),
        current_location: Optional[str] = Form(None), # Expect '(lon,lat)' string
        college: Optional[str] = Form(None),
        interests: Optional[List[str]] = Form(None), # Receive as list from form
        image: Optional[UploadFile] = File(None),
):
    """
    Updates the profile for the currently authenticated user.
    Handles optional image upload to MinIO.
    """
    conn = None
    # Initialize variables used in 'finally' or across 'try' blocks
    new_minio_object_name = None
    new_media_id = None
    old_media_id = None
    old_minio_object_name = None
    update_data = {} # Dictionary to pass to CRUD function

    # Build update_data dictionary from provided form fields
    if name is not None: update_data['name'] = name
    if username is not None: update_data['username'] = username
    if gender is not None: update_data['gender'] = gender
    if current_location is not None: update_data['current_location'] = format_location_for_db(current_location)
    if college is not None: update_data['college'] = college
    if interests is not None: update_data['interest'] = ",".join(interests)

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # --- Handle Image Upload ---
        if image:
            # --- Refined Check ---
            minio_properly_configured = (
                    utils.minio_client is not None and
                    MINIO_ENDPOINT and # Check config directly too
                    MINIO_BUCKET
            )
            print(f"DEBUG PUT /auth/me: Image provided. Checking MinIO config. Client exists: {utils.minio_client is not None}. Endpoint set: {bool(MINIO_ENDPOINT)}. Bucket set: {bool(MINIO_BUCKET)}")

            if not minio_properly_configured:
                print("ERROR PUT /auth/me: MinIO check failed. Client or config missing.")
                raise HTTPException(status_code=500, detail="MinIO client not configured on server.")
            # --- End Refined Check ---

            # 1. Get current user info and old media details
            user_info = crud.get_user_by_id(cursor, current_user_id)
            if not user_info: raise HTTPException(status_code=404, detail="User not found")
            current_username = user_info.get('username', f'user_{current_user_id}')
            old_media_info = crud.get_user_profile_picture_media(cursor, current_user_id)
            old_minio_object_name = old_media_info.get("minio_object_name") if old_media_info else None
            old_media_id = old_media_info.get("id") if old_media_info else None
            print(f"DEBUG PUT /auth/me: Old profile pic info: MediaID={old_media_id}, Path={old_minio_object_name}")

            # 2. Upload new image
            object_name_prefix = f"users/{current_username}/profile"
            upload_info = await upload_file_to_minio(image, object_name_prefix)

            if upload_info and 'minio_object_name' in upload_info:
                new_minio_object_name = upload_info['minio_object_name']
                print(f"✅ New profile image uploaded to MinIO: {new_minio_object_name}")

                # --- Start Transaction for DB changes related to new image ---
                # 3. Create new media_items record
                new_media_id = crud.create_media_item(
                    cursor, uploader_user_id=current_user_id, **upload_info
                )
                if not new_media_id:
                    if new_minio_object_name: delete_from_minio(new_minio_object_name)
                    raise HTTPException(status_code=500, detail="Failed to save uploaded image metadata to database.")
                print(f"DEBUG PUT /auth/me: Created media_item record ID: {new_media_id}")

                # 4. Link the new media item to the user profile
                crud.set_user_profile_picture(cursor, current_user_id, new_media_id)
                print(f"DEBUG PUT /auth/me: Linked user {current_user_id} to media {new_media_id}")
                # --- End Transaction part for new image (commit happens later) ---

            else: # Upload failed
                print(f"⚠️ Warning: MinIO profile image upload failed for user {current_user_id}")
                # Skip image update, proceed with text fields if any

        # --- Update user text fields in DB (if any) ---
        if update_data:
            print(f"DEBUG PUT /auth/me: Updating relational fields: {list(update_data.keys())}")
            success = crud.update_user_profile(cursor, current_user_id, update_data)
            if not success and cursor.rowcount == 0:
                print(f"Profile text update for user {current_user_id} resulted in 0 rows affected.")
        elif not image: # No text fields changed AND no image provided
            print(f"No update data provided for profile for user {current_user_id}")
            # Just fetch and return current data - no commit needed
            current_user_db = crud.get_user_by_id(cursor, current_user_id)
            if not current_user_db: raise HTTPException(status_code=404, detail="User not found")
            current_pic_media = crud.get_user_profile_picture_media(cursor, current_user_id)
            user_display_data = dict(current_user_db); loc_str = user_display_data.get('current_location'); user_display_data['current_location'] = parse_point_string(str(loc_str)) if loc_str else None; interests_db = user_display_data.get('interest'); user_display_data['interests'] = interests_db.split(',') if interests_db else []; user_display_data['image_url'] = current_pic_media.get('url') if current_pic_media else None; user_display_data.setdefault('last_seen', None); user_display_data.setdefault('image_path', None)
            return schemas.UserDisplay(**user_display_data)

        # --- Commit ---
        # Commit transaction if text fields updated OR new image was successfully linked
        if update_data or (image and new_media_id):
            conn.commit()
            print(f"DEBUG PUT /auth/me: Transaction committed.")
        else:
            print(f"DEBUG PUT /auth/me: No DB changes to commit.")

        # --- Delete Old Media (AFTER commit) ---
        if image and new_media_id and old_media_id and old_minio_object_name:
            if old_media_id != new_media_id:
                print(f"DEBUG PUT /auth/me: Deleting old profile media (ID: {old_media_id}, Path: {old_minio_object_name})")
                # --- Call synchronously ---
                delete_media_item_db_and_file(old_media_id, old_minio_object_name)
            else:
                print(f"DEBUG PUT /auth/me: Old media ID ({old_media_id}) is same as new; skipping delete.")

        # --- Fetch updated user data to return ---
        # Use a new cursor/connection potentially, or the same one if transaction state is fine
        updated_user_db = crud.get_user_by_id(cursor, current_user_id)
        if not updated_user_db: raise HTTPException(status_code=500, detail="Failed to fetch updated user data")
        updated_pic_media = crud.get_user_profile_picture_media(cursor, current_user_id)

        user_display_data = dict(updated_user_db); loc_str = user_display_data.get('current_location'); user_display_data['current_location'] = parse_point_string(str(loc_str)) if loc_str else None; interests_db = user_display_data.get('interest'); user_display_data['interests'] = interests_db.split(',') if interests_db else [];
        user_display_data['image_url'] = updated_pic_media.get('url') if updated_pic_media else None
        user_display_data.setdefault('last_seen', None); user_display_data.setdefault('image_path', None)

        print(f"✅ Profile updated for user {current_user_id}")
        return schemas.UserDisplay(**user_display_data)

    except psycopg2.IntegrityError as e:
        if conn: conn.rollback()
        if new_minio_object_name and new_media_id is None: delete_from_minio(new_minio_object_name)
        print(f"❌ Profile Update Integrity Error: {e}")
        detail = "Database integrity error.";
        if "users_username_key" in str(e): detail = "Username already taken."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback()
        # Cleanup only if upload happened but DB steps failed before commit
        if new_minio_object_name and new_media_id is None: delete_from_minio(new_minio_object_name)
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        # Cleanup only if upload happened but DB steps failed before commit
        if new_minio_object_name and new_media_id is None: delete_from_minio(new_minio_object_name)
        print(f"❌ Error updating profile for user {current_user_id}:")
        traceback.print_exc() # Ensure traceback is imported
        raise HTTPException(status_code=500, detail=f"Failed to update profile: An unexpected error occurred.")
    finally:
        if conn: conn.close()


# --- PUT /me/password ---
class PasswordChangeRequest(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=6)

@router.put("/me/password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
        request: PasswordChangeRequest,
        current_user_id: int = Depends(auth.get_current_user)
):
    """Changes the current user's password."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Get current password hash
        cursor.execute("SELECT password_hash FROM public.users WHERE id = %s", (current_user_id,))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

        # Verify old password
        if not bcrypt.checkpw(request.old_password.encode('utf-8'), user["password_hash"].encode('utf-8')):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Incorrect old password")

        # Hash new password
        new_hashed_password = bcrypt.hashpw(request.new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        # Update password in DB
        cursor.execute("UPDATE public.users SET password_hash = %s WHERE id = %s", (new_hashed_password, current_user_id))
        conn.commit()
        print(f"Password updated successfully for user {current_user_id}")
        return None # Return None for 204 No Content

    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error changing password for user {current_user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to change password")
    finally:
        if conn: conn.close()


# --- DELETE /me ---
@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
        current_user_id: int = Depends(auth.get_current_user)
):
    """Deletes the current user's account."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Get user profile picture info BEFORE deleting user
        profile_media = crud.get_user_profile_picture_media(cursor, current_user_id)
        minio_path_to_delete = profile_media.get('minio_object_name') if profile_media else None
        media_id_to_delete = profile_media.get('id') if profile_media else None

        # TODO: Get list of all other media items uploaded by user (posts, replies, chat)
        # This requires a query on media_items table WHERE uploader_user_id = current_user_id
        # This can be complex and potentially slow if not indexed well.

        # 2. Delete user (handles relational + graph via crud.delete_user)
        # crud.delete_user raises error on failure
        deleted = crud.delete_user(cursor, current_user_id)
        if not deleted:
            # Should not happen if user exists from Depends(auth.get_current_user)
            raise HTTPException(status_code=404, detail="User not found during deletion")

        conn.commit() # Commit successful DB deletion

        # 3. Delete profile picture media (DB record handled by CASCADE or needs explicit delete)
        # and MinIO file
        if media_id_to_delete:
            print(f"Attempting post-delete cleanup for profile pic media ID: {media_id_to_delete}, Path: {minio_path_to_delete}")
            await delete_media_item_db_and_file(media_id_to_delete, minio_path_to_delete)

        # TODO: Loop through other user-uploaded media and delete them

        print(f"User account {current_user_id} deleted successfully.")
        return None

    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error deleting account for user {current_user_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Failed to delete account")
    finally:
        if conn: conn.close()