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
        # Auth optional - public might view events, but counts are fetched regardless
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    """ Fetches details for a specific event, including participant count from graph. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # crud.get_event_details_db now fetches relational data + graph count
        event_db = crud.get_event_details_db(cursor, event_id)
        if not event_db:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        response_data = dict(event_db)
        # Generate image URL (assuming image_url in DB is full URL from MinIO)
        # No extra generation needed here if crud.create/update store the full URL
        # response_data['image_url'] = get_minio_url(response_data.get('image_path')) # Only if storing path

        # TODO: Add user's participation status if authenticated
        # is_participating = False
        # if current_user_id is not None:
        #     # Query graph: RETURN EXISTS((:User {id:..})-[:PARTICIPATED_IN]->(:Event {id:..}))
        #     pass
        # response_data['is_participating'] = is_participating # Add to schema if needed

        print(f"✅ Fetched details for event {event_id}")
        return schemas.EventDisplay(**response_data) # Validate
    except psycopg2.Error as e:
        print(f"❌ DB Error fetching event details {event_id}: {e}")
        raise HTTPException(status_code=500, detail="Database error fetching event")
    except Exception as e:
        print(f"❌ Error fetching event details {event_id}: {e}")
        raise HTTPException(status_code=500, detail="Error fetching event details")
    finally:
        if conn: conn.close()


@router.put("/{event_id}", response_model=schemas.EventDisplay)
async def update_event(
        event_id: int,
        current_user_id: int = Depends(auth.get_current_user), # Require auth for update
        # Form data for update
        title: Optional[str] = Form(None),
        description: Optional[str] = Form(None),
        location: Optional[str] = Form(None),
        event_timestamp: Optional[datetime] = Form(None), # FastAPI parses ISO string from form
        max_participants: Optional[int] = Form(None),
        image: Optional[UploadFile] = File(None) # Optional new image
):
    """ Updates an event (only creator can update). Handles optional image update. """
    conn = None
    update_data = {} # Collect fields that are actually provided
    minio_image_path = None
    old_image_path = None # Store old path if replacing image

    # Build update_data dict
    if title is not None: update_data['title'] = title
    # Allow sending empty string to clear description
    if description is not None: update_data['description'] = description
    if location is not None: update_data['location'] = location
    if event_timestamp is not None: update_data['event_timestamp'] = event_timestamp
    if max_participants is not None: update_data['max_participants'] = max_participants

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check ownership and get current event data
        event = crud.get_event_by_id(cursor, event_id) # Fetch relational data
        if not event:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        if event['creator_id'] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to update this event")
        # Store old image path/URL for potential deletion
        # Assuming image_url column stores the MinIO path/object name
        old_image_path = event.get('image_url') # Adjust if column name differs

        # 2. Handle Image Upload/Update (if new image provided)
        if image and utils.minio_client:
            # Fetch community name for path prefix (optional, better structure)
            comm_info = crud.get_community_by_id(cursor, event['community_id'])
            community_name = comm_info.get('name', f'community_{event["community_id"]}') if comm_info else f'community_{event["community_id"]}'

            object_name_prefix = f"communities/{community_name.replace(' ', '_').lower()}/events/"
            minio_image_path = await upload_file_to_minio(image, object_name_prefix)

            if minio_image_path:
                # Assuming we store the MinIO PATH in the image_url column
                update_data['image_url'] = minio_image_path # Add new path to update dict
                print(f"✅ Event image updated in MinIO: {minio_image_path}")
            else:
                print(f"⚠️ Warning: MinIO event image update failed for event {event_id}")
                # Decide: raise error or continue without image update? Continue for now.
                pass
        elif image is None and 'image_url' in update_data:
            # Prevent accidentally setting image_url via text field if image File is not provided
            del update_data['image_url']
            print("Info: 'image_url' removed from update data as no image file was provided.")


        # 3. Check if there's anything to update
        if not update_data:
            if image and not minio_image_path:
                raise HTTPException(status_code=500, detail="Image upload failed, no other data provided")
            elif not image:
                # Return current data if nothing changed
                print(f"No update data provided for event {event_id}")
                current_details = crud.get_event_details_db(cursor, event_id) # Fetch combined data
                if not current_details: raise HTTPException(status_code=404, detail="Event not found")
                response_data = dict(current_details)
                # Generate presigned URL for display if storing path
                # response_data['image_url'] = get_minio_url(response_data.get('image_url'))
                return schemas.EventDisplay(**response_data)

        # 4. Call CRUD update function (handles relational + graph)
        updated_event_db = crud.update_event_db(cursor, event_id, update_data)
        if not updated_event_db:
            # This implies event not found during update or update failed silently
            conn.rollback()
            # If a new image was uploaded, try to delete it
            if minio_image_path: delete_from_minio(minio_image_path)
            raise HTTPException(status_code=500, detail="Event update failed in database")

        conn.commit() # Commit successful DB updates

        # 5. Delete old MinIO image AFTER DB commit is successful
        if minio_image_path and old_image_path: # If new image replaced an old one
            delete_from_minio(old_image_path)

        # 6. Prepare and return response
        response_data = dict(updated_event_db) # Already contains counts
        # Generate presigned URL if storing path, otherwise use stored URL
        # response_data['image_url'] = get_minio_url(response_data.get('image_url'))
        print(f"✅ Event {event_id} updated successfully by User {current_user_id}")
        return schemas.EventDisplay(**response_data) # Validate

    except HTTPException as http_exc:
        if conn: conn.rollback()
        # Cleanup potential upload if error occurred after upload but before commit
        if minio_image_path and old_image_path is None: delete_from_minio(minio_image_path)
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback()
        if minio_image_path and old_image_path is None: delete_from_minio(minio_image_path)
        print(f"❌ DB Error updating event {event_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except Exception as e:
        if conn: conn.rollback()
        if minio_image_path and old_image_path is None: delete_from_minio(minio_image_path)
        print(f"❌ Error updating event {event_id}: {e}")
        import traceback
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
        current_user_id: int = Depends(auth.get_current_user) # Require auth
):
    """ Allows the current user to join an event, checking capacity first. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # crud.join_event_db now checks capacity and creates graph edge
        success = crud.join_event_db(cursor, event_id=event_id, user_id=current_user_id)
        conn.commit()

        # Fetch updated counts for response
        counts = crud.get_event_participant_count(cursor, event_id) # Use specific count func

        print(f"✅ User {current_user_id} join attempt for event {event_id} completed.")
        return {
            "message": "Successfully joined event",
            "success": success, # Will be true if no exception was raised
            "new_participant_count": counts
        }
    except ValueError as ve: # Catch specific "Event is full" or "Event not found"
        if conn: conn.rollback()
        print(f"❌ Join Event Error: {ve}")
        status_code = status.HTTP_404_NOT_FOUND if "not found" in str(ve).lower() else status.HTTP_409_CONFLICT
        raise HTTPException(status_code=status_code, detail=str(ve))
    except psycopg2.Error as e:
        if conn: conn.rollback()
        # Check for unique constraint violation if MERGE somehow failed (unlikely)
        # Or FK violation if user/event node doesn't exist
        print(f"❌ DB Error joining event {event_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Database error joining event")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error joining event {event_id}: {e}")
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