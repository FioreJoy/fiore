# backend/src/routers/events.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File
from typing import List, Optional
import psycopg2
from datetime import datetime
import os

from .. import schemas, crud, auth, utils
from ..database import get_db_connection
from ..utils import upload_file_to_minio, get_minio_url

router = APIRouter(
    prefix="/events",
    tags=["Events"],
)

@router.get("/{event_id}", response_model=schemas.EventDisplay)
async def get_event_details(event_id: int):
    """ Fetches details for a specific event. Image URL is included directly. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        event_db = crud.get_event_details_db(cursor, event_id)
        if not event_db:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        print(f"✅ Fetched details for event {event_id}")
        # EventDisplay schema expects image_url, which is directly in event_db
        return schemas.EventDisplay(**event_db) # Validate
    except Exception as e:
        print(f"❌ Error fetching event details {event_id}: {e}")
        raise HTTPException(status_code=500, detail="Error fetching event details")
    finally:
        if conn: conn.close()


@router.put("/{event_id}", response_model=schemas.EventDisplay)
async def update_event(
        event_id: int,
        current_user_id: int = Depends(auth.get_current_user),
        # Use Form data for potential image update
        title: Optional[str] = Form(None),
        description: Optional[str] = Form(None),
        location: Optional[str] = Form(None),
        event_timestamp: Optional[datetime] = Form(None),
        max_participants: Optional[int] = Form(None),
        image: Optional[UploadFile] = File(None)
):
    """ Updates an event (only creator can update). Handles optional image update. """
    conn = None
    update_data = {}
    minio_image_url = None # Store new image URL if uploaded

    # Build update_data dict from provided fields
    if title is not None: update_data['title'] = title
    if description is not None: update_data['description'] = description
    if location is not None: update_data['location'] = location
    if event_timestamp is not None: update_data['event_timestamp'] = event_timestamp
    if max_participants is not None: update_data['max_participants'] = max_participants

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Check ownership and get current event data (including community name for path)
        event = crud.get_event_details_db(cursor, event_id)
        if not event:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        if event['creator_id'] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to update this event")

        # Handle Image Upload/Update
        if image and utils.minio_client:
            # TODO: Delete old image from MinIO? Need the old URL/path
            # old_image_url = event.get('image_url')
            # if old_image_url: delete_minio_object_from_url(old_image_url) # Need helper

            # Fetch community name for path prefix
            temp_conn_comm = get_db_connection()
            temp_cursor_comm = temp_conn_comm.cursor()
            community_info = crud.get_community_by_id(temp_cursor_comm, event['community_id'])
            community_name = community_info.get('name', f'community_{event["community_id"]}') if community_info else f'community_{event["community_id"]}'
            temp_cursor_comm.close()
            temp_conn_comm.close()

            object_name_prefix = f"communities/{community_name.replace(' ', '_').lower()}/events/"
            minio_image_path = await upload_file_to_minio(image, object_name_prefix)
            if minio_image_path:
                minio_image_url = get_minio_url(minio_image_path)
                update_data['image_url'] = minio_image_url # Add new URL to update dict
                print(f"✅ Event image updated in MinIO: {minio_image_path}, URL: {minio_image_url}")
            else:
                print(f"⚠️ Warning: MinIO event image update failed for event {event_id}")
                # Continue without updating image URL if upload failed

        if not update_data:
            # Check if only image was intended but failed
            if image and not minio_image_url:
                raise HTTPException(status_code=400, detail="Image upload failed, no other data provided")
            elif not image:
                raise HTTPException(status_code=400, detail="No update data provided")
            # If image uploaded successfully but no other fields, update_data will contain image_url

        # Update event in DB using the collected data
        updated_event_db = crud.update_event_db(cursor, event_id, update_data)
        if not updated_event_db:
            conn.rollback()
            raise HTTPException(status_code=500, detail="Event update failed in database")

        # Fetch participant count separately if update_event_db doesn't return it
        participant_count = crud.get_event_participant_count(cursor, event_id)
        conn.commit()
        print(f"✅ Event {event_id} updated successfully by User {current_user_id}")

        # Add participant count to the response dict before validation
        response_data = dict(updated_event_db)
        response_data['participant_count'] = participant_count
        return schemas.EventDisplay(**response_data)

    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ DB Error updating event {event_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error updating event {event_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_event(
        event_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Deletes an event (only creator can delete). Optionally deletes image. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Check ownership and get image URL
        event = crud.get_event_details_db(cursor, event_id)
        if not event:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        if event['creator_id'] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to delete this event")

        # TODO: Get object path from URL to delete from MinIO
        minio_image_url_to_delete = event.get("image_url")
        # object_path = extract_path_from_url(minio_image_url_to_delete) # Need helper

        # Delete from DB first
        rows_deleted = crud.delete_event_db(cursor, event_id)
        conn.commit()

        if rows_deleted == 0:
            print(f"⚠️ Event {event_id} not found during delete.")
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        # Attempt to delete image from MinIO
        # if object_path and utils.minio_client:
        #     try:
        #         utils.minio_client.remove_object(utils.MINIO_BUCKET, object_path)
        #         print(f"🗑️ Deleted MinIO object for event {event_id}: {object_path}")
        #     except Exception as minio_del_err:
        #         print(f"⚠️ Warning: Failed to delete MinIO object {object_path}: {minio_del_err}")

        print(f"✅ Event {event_id} deleted successfully by User {current_user_id}")
        return None
    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error deleting event {event_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

# --- Event Participation (No image handling needed here) ---
@router.post("/{event_id}/join", status_code=status.HTTP_200_OK)
async def join_event(
        event_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Allows the current user to join an event, checking capacity first. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Check if event is full BEFORE attempting insert
        event_details = crud.get_event_details_db(cursor, event_id)
        if not event_details:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        # Use participant_count returned by get_event_details_db
        current_participant_count = event_details.get('participant_count', 0)
        max_participants = event_details.get('max_participants', 0)

        if current_participant_count >= max_participants:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Event is full")

        participant_id = crud.join_event_db(cursor, event_id, current_user_id)
        conn.commit()
        if participant_id:
            print(f"✅ User {current_user_id} joined event {event_id}")
            return {"message": "Successfully joined event"}
        else:
            print(f"ℹ️ User {current_user_id} already participant in event {event_id}")
            return {"message": "Already joined this event"}
    except psycopg2.Error as e:
        if conn: conn.rollback()
        if e.pgcode == '23503': # FK violation
            raise HTTPException(status_code=404, detail="Event not found")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except HTTPException as http_exc: # Catch specific 409/404 from checks
        if conn: conn.rollback()
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error joining event {event_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()


@router.delete("/{event_id}/leave", status_code=status.HTTP_200_OK)
async def leave_event(
        event_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Allows the current user to leave an event. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        deleted_id = crud.leave_event_db(cursor, event_id, current_user_id)
        conn.commit()
        if deleted_id:
            print(f"✅ User {current_user_id} left event {event_id}")
            return {"message": "Successfully left event"}
        else:
            print(f"ℹ️ User {current_user_id} not participant in event {event_id}")
            return {"message": "Not currently participating in this event"}
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error leaving event {event_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()