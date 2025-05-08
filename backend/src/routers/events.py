# backend/src/routers/events.py
import traceback

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
        conn = get_db_connection(); cursor = conn.cursor()
        event_db = crud.get_event_details_db(cursor, event_id)
        if not event_db:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        response_data = dict(event_db)
        response_data['image_url'] = utils.get_minio_url(response_data.get('image_url'))

        # Convert lon/lat from DB to EventDisplay.location_coords
        if response_data.get('longitude') is not None and response_data.get('latitude') is not None:
            response_data['location_coords'] = schemas.LocationPointInput(
                longitude=response_data['longitude'],
                latitude=response_data['latitude']
            )
        # Clean up raw lon/lat if they were fetched (as they are now in location_coords)
        if 'longitude' in response_data: del response_data['longitude']
        if 'latitude' in response_data: del response_data['latitude']


        is_participating = False
        if current_user_id is not None:
            try:
                is_participating = crud.check_is_participating(cursor, current_user_id, event_id)
            except Exception as check_err:
                print(f"WARNING: Failed checking participation status for E:{event_id} U:{current_user_id}: {check_err}")
        response_data['is_participating_by_viewer'] = is_participating

        response_data.setdefault('participant_count', 0)

        return schemas.EventDisplay(**response_data)
    except HTTPException as http_exc:
        raise http_exc
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
        title: Optional[str] = Form(None),
        description: Optional[str] = Form(None),
        location_address: Optional[str] = Form(None), # Renamed from 'location'
        event_timestamp: Optional[datetime] = Form(None),
        max_participants: Optional[int] = Form(None),
        image: Optional[UploadFile] = File(None),
        latitude: Optional[float] = Form(None),
        longitude: Optional[float] = Form(None)
):
    conn = None
    update_data_for_crud = {} # Use a different name to avoid confusion with 'update_data' FastAPI uses
    new_minio_object_name = None
    old_minio_object_name = None

    if title is not None: update_data_for_crud['title'] = title
    if description is not None: update_data_for_crud['description'] = description
    if location_address is not None: update_data_for_crud['location_address'] = location_address # Maps to DB 'location'
    if event_timestamp is not None: update_data_for_crud['event_timestamp'] = event_timestamp
    if max_participants is not None: update_data_for_crud['max_participants'] = max_participants

    if latitude is not None and longitude is not None:
        update_data_for_crud['location_coords_wkt'] = f"POINT({longitude} {latitude})"
    elif latitude is not None or longitude is not None:
        raise HTTPException(status_code=422, detail="Both latitude and longitude must be provided for coordinate update.")

    try:
        conn = get_db_connection(); cursor = conn.cursor()
        event_db = crud.get_event_by_id(cursor, event_id)
        if not event_db: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        if event_db['creator_id'] != current_user_id: raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
        old_minio_object_name = event_db.get('image_url')

        if image and utils.minio_client:
            comm_info = crud.get_community_by_id(cursor, event_db['community_id'])
            community_name = comm_info.get('name', f'community_{event_db["community_id"]}') if comm_info else f'community_{event_db["community_id"]}'
            object_name_prefix = f"media/communities/{community_name.replace(' ', '_').lower()}/events"
            upload_info = await utils.upload_file_to_minio(image, object_name_prefix)

            if upload_info and 'minio_object_name' in upload_info:
                new_minio_object_name = upload_info['minio_object_name']
                update_data_for_crud['image_url'] = new_minio_object_name
            else:
                print(f"⚠️ Warning: MinIO event image update failed for event {event_id}")

        if not update_data_for_crud and not new_minio_object_name:
            current_details = crud.get_event_details_db(cursor, event_id)
            if not current_details: raise HTTPException(status_code=404, detail="Event not found")
            response_data = dict(current_details)
            response_data['image_url'] = get_minio_url(response_data.get('image_url'))
            if response_data.get('longitude') is not None and response_data.get('latitude') is not None:
                response_data['location_coords'] = {"longitude": response_data['longitude'], "latitude": response_data['latitude']}
            return schemas.EventDisplay(**response_data)

        participant_ids_before_update = crud.get_event_participant_ids(cursor, event_id, limit=10000, offset=0)
        updated_event_db = crud.update_event_db(cursor, event_id, update_data_for_crud)
        if not updated_event_db:
            conn.rollback()
            if new_minio_object_name: delete_from_minio(new_minio_object_name)
            raise HTTPException(status_code=500, detail="Event update failed in database")

        if participant_ids_before_update:
            event_title_for_notif = updated_event_db.get('title', event_db.get('title', 'your event'))
            content_preview = f"Event Updated: \"{event_title_for_notif[:50]}...\" Details may have changed."
            print(f"Attempting to notify {len(participant_ids_before_update)} participants of event {event_id} update.")
            for p_id in participant_ids_before_update:
                if p_id != current_user_id:
                    crud.create_notification(
                        cursor=cursor, recipient_user_id=p_id, actor_user_id=current_user_id,
                        type='event_update', related_entity_type='event', related_entity_id=event_id,
                        content_preview=content_preview
                    )
        conn.commit()

        if new_minio_object_name and old_minio_object_name and new_minio_object_name != old_minio_object_name:
            delete_from_minio(old_minio_object_name)

        response_data = dict(updated_event_db)
        response_data['image_url'] = get_minio_url(response_data.get('image_url'))

        if response_data.get('longitude') is not None and response_data.get('latitude') is not None:
            response_data['location_coords'] = schemas.LocationPointInput(longitude=response_data['longitude'], latitude=response_data['latitude'])
        if 'longitude' in response_data: del response_data['longitude'] # clean up raw fields
        if 'latitude' in response_data: del response_data['latitude']

        print(f"✅ Event {event_id} updated successfully by User {current_user_id}")
        return schemas.EventDisplay(**response_data)

    except HTTPException as http_exc:
        if conn: conn.rollback()
        if new_minio_object_name and not updated_event_db: delete_from_minio(new_minio_object_name)
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback()
        if new_minio_object_name and not updated_event_db: delete_from_minio(new_minio_object_name)
        print(f"❌ DB Error updating event {event_id}: {e}")
        detail = f"Database error: {e.pgerror}" if hasattr(e, 'pgerror') and e.pgerror else "Database error updating event"
        raise HTTPException(status_code=500, detail=detail)
    except Exception as e:
        if conn: conn.rollback()
        if new_minio_object_name and not updated_event_db: delete_from_minio(new_minio_object_name)
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