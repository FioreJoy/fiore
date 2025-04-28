# backend/routers/auth.py
from fastapi import (
    APIRouter, Depends, HTTPException, status,
    Form, UploadFile, File, Body
)
from typing import List, Optional
import psycopg2
import bcrypt
import os

# Use BaseMode for JSON body if not using Forms
from pydantic import BaseModel # <--- ADD THIS IMPORT

from .. import schemas, crud, utils, auth
from ..database import get_db_connection
from ..utils import upload_file_to_minio, get_minio_url

from .. import schemas, crud, utils, auth # Relative imports
from ..database import get_db_connection

router = APIRouter(
    prefix="/auth", # Changed prefix to /auth
    tags=["Authentication"],
)

# Use standard OAuth2 form for login if preferred
# @router.post("/token", response_model=schemas.Token)
# async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
#     conn = get_db_connection()
#     cursor = conn.cursor()
#     user = crud.get_user_by_email(cursor, form_data.username) # email is username here
#     conn.close()
#     if not user or not bcrypt.checkpw(form_data.password.encode('utf-8'), user["password_hash"].encode('utf-8')):
#         raise HTTPException(
#             status_code=status.HTTP_401_UNAUTHORIZED,
#             detail="Incorrect username or password",
#             headers={"WWW-Authenticate": "Bearer"},
#         )
#     access_token = auth.create_access_token(data={"user_id": user["id"]})
#     return {"access_token": access_token, "token_type": "bearer"}


# Alternative: JSON body login
@router.post("/login", response_model=schemas.TokenData) # Return user_id along with token
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
        print(f"✅ Token generated for user {user_id}")
        return {"token": access_token, "user_id": user_id} # Changed response model

    except HTTPException as http_exc:
         if conn: conn.rollback()
         raise http_exc
    except Exception as e:
         if conn: conn.rollback()
         print(f"❌ Login Error: {e}")
         raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Login failed")
    finally:
        if conn: conn.close()


@router.post("/signup", status_code=status.HTTP_201_CREATED, response_model=schemas.TokenData) # Return token+userid on signup
async def signup(
    name: str = Form(...),
    username: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    gender: str = Form(...),
    # Expect frontend to send POINT string e.g., '(lon,lat)'
    current_location: str = Form("(0,0)"),
    college: str = Form(...),
    interests: List[str] = Form(...), # Use Form for lists from multipart
    image: Optional[UploadFile] = File(None)
):
    conn = None
    image_path = None
    try:
        # Handle Image Upload
        if image:
            image_path = await utils.save_image_multipart(image, username)
            if image_path is None:
                 print(f"⚠️ Warning: Image saving failed for {username}")
                 # Decide if signup should fail or continue without image

        # Prepare data for DB
        interests_str = ",".join(interests) if interests else None
        # Ensure location format is correct for DB insertion if needed
        # db_location_str = utils.format_location_for_db(current_location) # Use helper if needed

        conn = get_db_connection()
        cursor = conn.cursor()

        # Create user using CRUD function
        user_id = crud.create_user(
            cursor, name, username, email, password, gender,
            current_location, # Pass raw string, assuming ::point cast handles it
            college, interests_str, image_path
        )

        if user_id is None:
             raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="User creation failed")

        conn.commit()
        print(f"✅ User created with ID: {user_id}, Image: {image_path}")

        # Create token for the new user
        access_token = auth.create_access_token(data={"user_id": user_id})
        return {
            "message": "User signed up successfully", # Can customize response schema if needed
            "user_id": user_id,
            "image_path": image_path,
            "token": access_token
        }

    except psycopg2.IntegrityError as e:
        if conn: conn.rollback()
        print(f"❌ Signup Error (Integrity): {e}")
        detail = "Username or email already exists."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Signup Error: {e}")
        # Clean up saved image if user creation failed after saving image
        if image_path and os.path.exists(image_path):
             try:
                  os.remove(image_path)
                  print(f"🧹 Cleaned up image {image_path} after signup failure.")
             except OSError as rm_err:
                  print(f"⚠️ Error cleaning up image {image_path}: {rm_err}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
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

        # Process data for display model
        user_display_data = dict(user_db) # Convert RealDictRow to dict

        # Parse location point string
        location_str = user_db.get('current_location')
        if location_str:
             user_display_data['current_location'] = utils.parse_point_string(str(location_str))
        else:
             user_display_data['current_location'] = None # Explicitly set to None if DB value is NULL

        # Split interests string
        interests_db = user_db.get('interest')
        user_display_data['interests'] = interests_db.split(',') if interests_db else []

        # Construct full image path URL if needed (adjust based on how you serve static files)
        img_path = user_db.get('image_path')
        if img_path and img_path.startswith('/'):
            # Assuming 'user_images' is served statically at the root
            # This might need adjustment based on your static file setup in server.py
            # Prepend '/' if served from root
            # Or use full base URL if needed:
            # from .. import app_constants
            # user_display_data['image_path'] = f"{app_constants.baseUrl}/{img_path}"
            img_path_for_minio = img_path[1:] # Remove leading slash
            print(f"DEBUG: Removed leading slash from image_path: {img_path_for_minio}")
        else:
            img_path_for_minio = img_path
        
        user_display_data['image_url'] = get_minio_url(img_path_for_minio)
        # Keep the original path from DB if needed by schema (optional)
        user_display_data['image_path'] = img_path
        # --- *** END FIX *** ---

        print(f"DEBUG: User data prepared for response: {user_display_data}") # Log before returning
	# Validate and return using the Pydantic model
        return schemas.UserDisplay(**user_display_data)

    except Exception as e:
         print(f"❌ Error fetching /me: {e}")
         raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to fetch user details")
    finally:
        if conn: conn.close()
@router.put("/me", response_model=schemas.UserDisplay)
async def update_user_profile_endpoint( # Renamed function slightly to avoid clash if imported directly
        current_user_id: int = Depends(auth.get_current_user),
        # Using Form data because we need to handle potential File upload
        name: Optional[str] = Form(None),
        username: Optional[str] = Form(None),
        gender: Optional[str] = Form(None),
        current_location: Optional[str] = Form(None), # Expect '(lon,lat)' string
        college: Optional[str] = Form(None),
        interests: Optional[List[str]] = Form(None), # Receive as list from form
        image: Optional[UploadFile] = File(None), # Image upload
):
    """
    Updates the profile for the currently authenticated user.
    Handles optional image upload to MinIO.
    """
    conn = None
    minio_image_path = None
    update_data = {} # Dictionary to pass to CRUD function

    # Build update_data dictionary from provided form fields
    if name is not None: update_data['name'] = name
    if username is not None: update_data['username'] = username
    if gender is not None: update_data['gender'] = gender
    if current_location is not None:
        # Basic validation or formatting for location if needed here
        # Assuming format_location_for_db handles "(lon,lat)" -> Point compatible string
        update_data['current_location'] = utils.format_location_for_db(current_location)
        # Note: crud.update_user_profile expects 'current_location' key now
    if college is not None: update_data['college'] = college
    if interests is not None: update_data['interest'] = ",".join(interests) # Join list into comma-separated string for DB

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # --- Handle Image Upload ---
        if image: # If a new image file is provided
            if not utils.minio_client:
                raise HTTPException(status_code=500, detail="MinIO client not configured on server.")

            # 1. Get current user info to find old image path and username
            user_info = crud.get_user_by_id(cursor, current_user_id)
            if not user_info:
                # Should not happen if Depends(auth.get_current_user) worked
                raise HTTPException(status_code=404, detail="User not found for image update")
            current_username = user_info.get('username', f'user_{current_user_id}')
            old_image_path = user_info.get('image_path')

            # 2. (Optional but recommended) Delete old image from MinIO
            if old_image_path:
                try:
                    print(f"Attempting to delete old MinIO image: {old_image_path}")
                    utils.minio_client.remove_object(utils.MINIO_BUCKET, old_image_path)
                    print(f"✅ Successfully deleted old MinIO image: {old_image_path}")
                except Exception as del_err:
                    # Log error but don't fail the update process just for this
                    print(f"⚠️ Warning: Failed to delete old MinIO image {old_image_path}: {del_err}")

            # 3. Upload new image
            object_name_prefix = f"users/{current_username}/profile"
            minio_image_path = await utils.upload_file_to_minio(image, object_name_prefix)

            if minio_image_path:
                update_data['image_path'] = minio_image_path # Add new path to fields to update in DB
                print(f"✅ New profile image uploaded to MinIO: {minio_image_path}")
            else:
                # Handle upload failure - maybe raise exception or just log warning?
                print(f"⚠️ Warning: MinIO profile image upload failed for user {current_user_id}")
                # Decide: raise HTTPException(500, "Image upload failed") or just skip image update?
                # For now, let's skip the image update if upload fails
                pass
        # --- End Image Handling ---


        # Check if there's anything to update (text fields or new image path)
        if not update_data:
            # If image was provided but upload failed AND no other fields changed
            if image and not minio_image_path:
                raise HTTPException(status_code=500, detail="Profile update failed due to image upload error.")
            # If no image was provided AND no text fields changed
            elif not image:
                print(f"No data provided for profile update for user {current_user_id}")
                # Return current data without making DB call? Or raise 400?
                # Let's return current data - fetch it if not already available
                if 'user_info' not in locals(): # Check if user_info was fetched for image handling
                    user_info = crud.get_user_by_id(cursor, current_user_id)
                    if not user_info: raise HTTPException(status_code=404, detail="User not found")

                user_display = dict(user_info)
                # Format location/interests/image_url for display schema
                loc_str = user_display.get('current_location')
                user_display['current_location'] = utils.parse_point_string(str(loc_str)) if loc_str else None
                interests_db = user_display.get('interest')
                user_display['interests'] = interests_db.split(',') if interests_db else []
                img_path = user_display.get('image_path')
                user_display['image_url'] = get_minio_url(img_path)

                return schemas.UserDisplay(**user_display)
                # Alternatively: raise HTTPException(status_code=400, detail="No update data provided")


        # --- Update user in DB ---
        # Note: crud.update_user_profile needs adjustment if it expects 'current_location_str'
        # Let's assume it now directly handles 'current_location' with the formatted string
        success = crud.update_user_profile(cursor, current_user_id, update_data)

        if not success and cursor.rowcount == 0:
            # This might mean the user ID was wrong, or no actual change was needed for the UPDATE statement
            # Let's assume it's okay if rowcount is 0 but no error occurred (e.g., username was the same)
            print(f"Profile update for user {current_user_id} resulted in 0 rows affected (no change or user not found?).")
            # Proceed to fetch and return current data

        conn.commit()

        # --- Fetch updated user data to return ---
        updated_user_db = crud.get_user_by_id(cursor, current_user_id)
        if not updated_user_db:
            # This would be unusual if the update didn't error and the user exists
            raise HTTPException(status_code=500, detail="Failed to fetch updated user data after update.")

        # Process data for display model (reuse logic from GET /me)
        user_display_data = dict(updated_user_db)
        location_str = updated_user_db.get('current_location')
        user_display_data['current_location'] = utils.parse_point_string(str(location_str)) if location_str else None
        interests_db = updated_user_db.get('interest')
        user_display_data['interests'] = interests_db.split(',') if interests_db else []
        img_path = updated_user_db.get('image_path') # Should be the new path if updated
        user_display_data['image_url'] = get_minio_url(img_path)
        # user_display_data['image_path'] = img_path # Keep path if schema includes it

        print(f"✅ Profile updated for user {current_user_id}")
        return schemas.UserDisplay(**user_display_data)

    except psycopg2.IntegrityError as e:
        if conn: conn.rollback()
        print(f"❌ Profile Update Integrity Error: {e}")
        detail = "Database integrity error."
        # Check for unique constraint violation (e.g., username)
        if "users_username_key" in str(e):
            detail = "Username already taken."
        elif "users_email_key" in str(e): # Should not happen here, but good check
            detail = "Email already taken."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        import traceback
        print(f"❌ Error updating profile for user {current_user_id}:")
        print(traceback.format_exc())
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to update profile: An unexpected error occurred.")
    finally:
        if conn: conn.close()
# --- *** END OF PUT /me ROUTE *** ---
# --- PUT /me/password --- (Keep existing)
class PasswordChangeRequest(BaseModel): # Define inside or import if defined globally
    old_password: str
    new_password: str

@router.put("/me/password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
        request: PasswordChangeRequest, # Use the Pydantic model for JSON body
        current_user_id: int = Depends(auth.get_current_user)
):
    # ... existing change_password code ...
    pass # Added pass for brevity in example


# --- DELETE /me --- (Keep existing)
@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
        current_user_id: int = Depends(auth.get_current_user)
):
    # ... existing delete_account code ...
    # Consider adding MinIO data deletion here as well (can be complex)
    pass # Added pass for brevity in example

