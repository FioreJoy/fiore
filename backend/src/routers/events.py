# backend/src/routers/events.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File
from typing import List, Optional, Dict, Any # Added Dict, Any
import psycopg2
from datetime import datetime
import os

# Use the central crud import
from .. import schemas, crud, auth, utils
from ..database import get_db_connection
from ..utils import get_minio_url, delete_from_minio, upload_file_to_minio # Added upload/delete

# Import JWT for optional auth dependency
import jwt
from fastapi import Header # For optional auth header

router = APIRouter(
    prefix="/events",
    tags=["Events"],
    # dependencies=[Depends(auth.get_current_user)] # Apply auth dependency to specific routes
)


@router.get("/{event_id}", response_model=schemas.EventDisplay)
async def get_event_details(
        event_id: int,
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # crud.get_event_details_db fetches combined data
        event_db = crud.get_event_details_db(cursor, event_id)
        if not event_db:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        response_data = dict(event_db)
        response_data['image_url'] = utils.get_minio_url(response_data.get('image_url')) # Generate URL if path stored

        # Check participation status
        is_participating = False
        if current_user_id is not None:
            try:
                is_participating = crud.check_is_participating(cursor, current_user_id, event_id)
            except Exception as check_err:
                print(f"WARNING: Failed checking participation status for E:{event_id} U:{current_user_id}: {check_err}")
        response_data['is_participating_by_viewer'] = is_participating # Add to schema if not present

        # Add defaults for safety
        response_data.setdefault('participant_count', 0)

        print(f"✅ Fetched details for event {event_id}")
        return schemas.EventDisplay(**response_data)
    except HTTPException as http_exc:
        raise http_exc # Re-raise explicit exceptions
    except psycopg2.Error as db_err:
        print(f"❌ DB Error fetching event details {event_id}: {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching event")
    except Exception as e:
        print(f"❌ Error fetching event details {event_id}: {e}")
        import traceback; traceback.print_exc();
        raise HTTPException(status_code=500, detail="Error fetching event details")
    finally:
        if conn: conn.close()


@router.put("/{event_id}", response_model=schemas.EventDisplay)
async def update_event(
        event_id: int,
        current_user_id: int = Depends(auth.get_current_user),
        # Form data for update
        title: Optional[str] = Form(None),
        description: Optional[str] = Form(None),
        location: Optional[str] = Form(None),
        event_timestamp: Optional[datetime] = Form(None),
        max_participants: Optional[int] = Form(None),
        image: Optional[UploadFile] = File(None) # Optional new image
):
    conn = None
    update_data = {}
    new_minio_object_name = None # Store the name/path of the newly uploaded file
    old_minio_object_name = None # Store the name/path of the old file
    upload_info = None # Store the dict from upload_file_to_minio if needed

    # Build update_data dict for text fields
    if title is not None: update_data['title'] = title
    if description is not None: update_data['description'] = description
    if location is not None: update_data['location'] = location
    if event_timestamp is not None: update_data['event_timestamp'] = event_timestamp
    if max_participants is not None: update_data['max_participants'] = max_participants

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check ownership and get current event data / old image path
        event = crud.get_event_by_id(cursor, event_id)
        if not event: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        if event['creator_id'] != current_user_id: raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
        # Assuming image_url column stores the MinIO object name
        old_minio_object_name = event.get('image_url') # Get the current object name

        # 2. Handle Image Upload/Update (if new image provided)
        if image and utils.minio_client:
            comm_info = crud.get_community_by_id(cursor, event['community_id'])
            community_name = comm_info.get('name', f'community_{event["community_id"]}') if comm_info else f'community_{event["community_id"]}'
            object_name_prefix = f"communities/{community_name.replace(' ', '_').lower()}/events"

            upload_info = await utils.upload_file_to_minio(image, object_name_prefix) # Returns dict

            if upload_info and 'minio_object_name' in upload_info:
                new_minio_object_name = upload_info['minio_object_name'] # Get the new object name string
                # --- FIX: Add the object name STRING to update_data ---
                update_data['image_url'] = new_minio_object_name
                # -----------------------------------------------------
                print(f"✅ Event image updated in MinIO: {new_minio_object_name}")
            else:
                print(f"⚠️ Warning: MinIO event image update failed for event {event_id}")
                # Do not add 'image_url' to update_data if upload failed

        elif image is None and 'image_url' in update_data:
            # This case should not happen if image_url comes only from file upload
            del update_data['image_url']


        # 3. Check if there's anything to update
        # Check if text fields changed OR if a new image was successfully uploaded
        if not update_data:
            # If only image was provided but upload failed
            if image and not new_minio_object_name:
                raise HTTPException(status_code=500, detail="Image upload failed, no other data provided")
            # If no image and no text fields provided
            elif not image:
                print(f"No update data provided for event {event_id}")
                # Just return current data
                current_details = crud.get_event_details_db(cursor, event_id)
                if not current_details: raise HTTPException(status_code=404, detail="Event not found")
                response_data = dict(current_details)
                response_data['image_url'] = get_minio_url(response_data.get('image_url')) # Generate URL from stored path
                return schemas.EventDisplay(**response_data)


        # 4. Call CRUD update function (passing object name string in image_url field)
        # Now update_data['image_url'] contains the STRING or is absent
        updated_event_db = crud.update_event_db(cursor, event_id, update_data)
        if not updated_event_db:
            conn.rollback()
            if new_minio_object_name: delete_from_minio(new_minio_object_name) # Cleanup upload
            raise HTTPException(status_code=500, detail="Event update failed in database")

        conn.commit()

        # 5. Delete old MinIO image AFTER DB commit is successful
        # Check if a new image was uploaded AND there was an old one AND they are different
        if new_minio_object_name and old_minio_object_name and new_minio_object_name != old_minio_object_name:
            print(f"Attempting to delete old event image: {old_minio_object_name}")
            # Fetch the media item ID for the old object name before deleting
            # This step is complex and maybe unnecessary if just deleting the file is okay
            delete_from_minio(old_minio_object_name)

        # 6. Prepare and return response
        response_data = dict(updated_event_db)
        response_data['image_url'] = get_minio_url(response_data.get('image_url')) # Generate URL from stored path
        print(f"✅ Event {event_id} updated successfully by User {current_user_id}")
        return schemas.EventDisplay(**response_data)

    # ... (keep existing except blocks) ...
    except HTTPException as http_exc:
        if conn: conn.rollback()
        if new_minio_object_name: delete_from_minio(new_minio_object_name) # Cleanup if failed before commit
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback()
        if new_minio_object_name: delete_from_minio(new_minio_object_name)
        print(f"❌ DB Error updating event {event_id}: {e}")
        detail = f"Database error: {e.pgerror}" if hasattr(e, 'pgerror') and e.pgerror else "Database error updating event"
        raise HTTPException(status_code=500, detail=detail) # Pass detail
    except Exception as e:
        if conn: conn.rollback()
        if new_minio_object_name: delete_from_minio(new_minio_object_name)
        print(f"❌ Error updating event {event_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_event(
        event_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Require auth
):
    """ Deletes an event (only creator can delete). Deletes relational, graph, and MinIO image. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check ownership and get image path/URL BEFORE deleting
        event = crud.get_event_by_id(cursor, event_id) # Fetch relational data
        if not event:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        if event['creator_id'] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to delete this event")
        # Assuming image_url column stores the MinIO object name/path
        minio_image_to_delete = event.get("image_url")

        # 2. Call the combined delete function (handles graph + relational)
        deleted = crud.delete_event_db(cursor, event_id)

        if not deleted:
            conn.rollback()
            print(f"⚠️ Event {event_id} delete function returned false.")
            raise HTTPException(status_code=404, detail="Event not found during deletion")

        conn.commit() # Commit successful DB deletion

        # 3. Attempt to delete image from MinIO AFTER successful DB deletion
        if minio_image_to_delete:
            delete_from_minio(minio_image_to_delete)

        print(f"✅ Event {event_id} deleted successfully by User {current_user_id}")
        return None # Return None for 204 No Content

    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ SQL Error deleting event {event_id}: {e}")
        raise HTTPException(status_code=500, detail="Database error during deletion")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Unexpected Error deleting event {event_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not delete event")
    finally:
        if conn: conn.close()

# --- Event Participation ---
@router.post("/{event_id}/join", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def join_event(
        event_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # crud.join_event_db checks capacity and creates graph edge
        success = crud.join_event_db(cursor, event_id=event_id, user_id=current_user_id)
        conn.commit()

        # Fetch updated counts for response
        count = 0
        try:
            count = crud.get_event_participant_count(cursor, event_id)
        except Exception as count_err:
            print(f"WARN: Failed getting participant count after join for E:{event_id}: {count_err}")

        print(f"✅ User {current_user_id} join attempt for event {event_id} completed.")
        return {
            "message": "Successfully joined event",
            "success": success,
            "new_participant_count": count # Changed key name slightly for clarity
        }
    except ValueError as ve: # Catch specific "Event is full" or "Event not found" from CRUD
        if conn: conn.rollback()
        print(f"❌ Join Event Business Logic Error: {ve}")
        status_code = status.HTTP_404_NOT_FOUND if "not found" in str(ve).lower() else status.HTTP_409_CONFLICT # 409 for full
        raise HTTPException(status_code=status_code, detail=str(ve))
    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ DB Error joining event {event_id}: {e} (Code: {e.pgcode})")
        # Check for specific codes if needed, e.g., FK violation means user/event node missing in graph
        raise HTTPException(status_code=500, detail=f"Database error joining event")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Unexpected Error joining event {event_id}: {e}")
        import traceback; traceback.print_exc();
        raise HTTPException(status_code=500, detail="Could not join event")
    finally:
        if conn: conn.close()


@router.delete("/{event_id}/leave", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def leave_event(
        event_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Require auth
):
    """ Allows the current user to leave an event. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # crud.leave_event_db deletes graph edge
        deleted = crud.leave_event_db(cursor, event_id=event_id, user_id=current_user_id)
        conn.commit()

        # Fetch updated counts for response
        counts = crud.get_event_participant_count(cursor, event_id)

        print(f"✅ User {current_user_id} left event {event_id}. Deleted: {deleted}")
        return {
            "message": "Successfully left event" if deleted else "Not participating in this event",
            "success": deleted,
            "new_participant_count": counts
        }
    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ DB Error leaving event {event_id}: {e}")
        raise HTTPException(status_code=500, detail="Database error leaving event")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error leaving event {event_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not leave event")
    finally:
        if conn: conn.close()