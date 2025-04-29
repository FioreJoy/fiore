# backend/src/routers/communities.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File
from typing import List, Optional
import psycopg2
from datetime import datetime

from .. import schemas, crud, auth, utils
from ..database import get_db_connection
from ..utils import upload_file_to_minio, get_minio_url, delete_from_minio # Import delete helper

router = APIRouter(
    prefix="/communities",
    tags=["Communities"],
)

@router.post("", status_code=status.HTTP_201_CREATED, response_model=schemas.CommunityDisplay)
async def create_community(
        current_user_id: int = Depends(auth.get_current_user),
        name: str = Form(...),
        description: Optional[str] = Form(None),
        primary_location: str = Form("(0,0)"), # Expecting "(lon,lat)" string
        interest: Optional[str] = Form(None),
        logo: Optional[UploadFile] = File(None)
):
    """
    Creates a new community, optionally with a logo uploaded to MinIO.
    """
    conn = None
    minio_logo_path = None
    try:
        # Handle Logo Upload to MinIO
        if logo and utils.minio_client:
            # Define a prefix for community logos
            object_name_prefix = f"communities/{name.replace(' ', '_').lower()}/logo" # Sanitize name for path
            minio_logo_path = await upload_file_to_minio(logo, object_name_prefix)
            if minio_logo_path is None:
                print(f"⚠️ Warning: MinIO community logo upload failed for {name}")
                # Continue without logo path
            else:
                print(f"✅ Community logo uploaded to MinIO: {minio_logo_path}")

        conn = get_db_connection()
        cursor = conn.cursor()
        # Format location string if needed (assuming CRUD handles 'POINT(lon lat)' or similar)
        db_location_str = utils.format_location_for_db(primary_location) # Use helper

        community_id = crud.create_community_db(
            cursor,
            name=name,
            description=description,
            created_by=current_user_id,
            primary_location_str=db_location_str,
            interest=interest,
            logo_path=minio_logo_path # Pass MinIO path
        )
        if community_id is None:
            raise HTTPException(status_code=500, detail="Community creation failed in database")

        # Fetch the created community details to return
        created_community_db = crud.get_community_details_db(cursor, community_id)
        conn.commit() # Commit after successful insert and fetch

        if not created_community_db:
            conn.rollback() # Rollback if fetch failed
            raise HTTPException(status_code=500, detail="Could not retrieve created community details")

        # Prepare response data
        processed_data = dict(created_community_db)
        processed_data['primary_location'] = str(created_community_db.get('primary_location')) # Return as string
        processed_data['logo_url'] = get_minio_url(created_community_db.get('logo_path'))

        print(f"✅ Community '{name}' (ID: {community_id}) created by User {current_user_id}")
        return schemas.CommunityDisplay(**processed_data)

    except psycopg2.IntegrityError as e:
        if conn: conn.rollback()
        # Consider deleting uploaded MinIO logo on DB error?
        print(f"❌ Community Creation Integrity Error: {e}")
        detail="Community name may already exist or invalid data provided."
        if 'communities_created_by_fkey' in str(e):
            detail = "Creator user not found."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error creating community: {e}")
        raise HTTPException(status_code=500, detail=f"Could not create community: {e}")
    finally:
        if conn: conn.close()

@router.get("", response_model=List[schemas.CommunityDisplay])
async def get_communities():
    """ Fetches a list of all communities with logo URLs. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        communities_db = crud.get_communities_db(cursor)

        processed_communities = []
        for comm in communities_db:
            data = dict(comm)
            loc_str = comm.get('primary_location')
            data['primary_location'] = str(loc_str) if loc_str else None
            data['logo_url'] = get_minio_url(comm.get('logo_path'))
            # Add online_count (defaults to 0 if not present in this query)
            data['online_count'] = data.get('online_count', 0)
            processed_communities.append(schemas.CommunityDisplay(**data)) # Validate

        print(f"✅ Fetched {len(processed_communities)} communities")
        return processed_communities
    except Exception as e:
        print(f"❌ Error fetching communities: {e}")
        raise HTTPException(status_code=500, detail="Error fetching communities")
    finally:
        if conn: conn.close()

@router.get("/trending", response_model=List[schemas.CommunityDisplay])
async def get_trending_communities():
    """ Fetches trending communities with logo URLs. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        communities_db = crud.get_trending_communities_db(cursor)

        processed_communities = []
        for comm in communities_db:
            data = dict(comm)
            loc_str = comm.get('primary_location')
            data['primary_location'] = str(loc_str) if loc_str else None
            data['logo_url'] = get_minio_url(comm.get('logo_path'))
            # Add online_count (defaults to 0 if not present in this query)
            data['online_count'] = data.get('online_count', 0)
            processed_communities.append(schemas.CommunityDisplay(**data)) # Validate

        print(f"✅ Fetched {len(processed_communities)} trending communities")
        return processed_communities
    except Exception as e:
        print(f"❌ Error fetching trending communities: {e}")
        raise HTTPException(status_code=500, detail="Error fetching trending communities")
    finally:
        if conn: conn.close()

@router.get("/{community_id}/details", response_model=schemas.CommunityDisplay)
async def get_community_details(community_id: int):
    """ Fetches details for a specific community with logo URL. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        community_db = crud.get_community_details_db(cursor, community_id)
        if not community_db:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")

        data = dict(community_db)
        loc_str = community_db.get('primary_location')
        data['primary_location'] = str(loc_str) if loc_str else None
        data['logo_url'] = get_minio_url(community_db.get('logo_path'))

        print(f"✅ Details fetched for community {community_id}")
        return schemas.CommunityDisplay(**data)
    except Exception as e:
        print(f"❌ Error fetching community details {community_id}: {e}")
        raise HTTPException(status_code=500, detail="Error fetching community details")
    finally:
        if conn: conn.close()

@router.put("/{community_id}", response_model=schemas.CommunityDisplay)
async def update_community_details(
    community_id: int,
    update_data: schemas.CommunityUpdate, # Expect JSON body for text updates
    current_user_id: int = Depends(auth.get_current_user) # Still need user_id for permission check
    # API Key dependency is handled by the router
):
    """ Updates a community's details (name, description, interest, location). Requires creator permission. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check Permissions: Verify current user is the creator
        community = crud.get_community_by_id(cursor, community_id)
        if not community:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")
        if community['created_by'] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to update this community")

        # 2. Attempt Update
        updated = crud.update_community_details_db(cursor, community_id, update_data)
        if not updated and cursor.rowcount == 0:
             # This could happen if the ID was valid but nothing changed, or update failed silently
             print(f"Community {community_id} update resulted in 0 rows affected.")
             # Proceed to fetch current data as if update succeeded (no change needed)

        conn.commit()

        # 3. Fetch and return updated data
        updated_community_db = crud.get_community_details_db(cursor, community_id)
        if not updated_community_db:
             raise HTTPException(status_code=500, detail="Could not retrieve updated community details")

        # Format response
        response_data = dict(updated_community_db)
        response_data['primary_location'] = str(updated_community_db.get('primary_location'))
        response_data['logo_url'] = get_minio_url(updated_community_db.get('logo_path'))
        return schemas.CommunityDisplay(**response_data)

    except psycopg2.IntegrityError as e: # Catch potential duplicate name error
        if conn: conn.rollback()
        print(f"❌ Community Update Integrity Error: {e}")
        detail="Database integrity error during update."
        if "communities_name_key" in str(e):
             detail = "Community name already exists."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error updating community details {community_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not update community details")
    finally:
        if conn: conn.close()


# --- NEW: POST /communities/{id}/logo (Update Logo) ---
# Using POST for file upload is common, could also use PUT
@router.post("/{community_id}/logo", response_model=schemas.CommunityDisplay)
async def update_community_logo(
    community_id: int,
    current_user_id: int = Depends(auth.get_current_user), # Permission check
    logo: UploadFile = File(...), # Require a file
    # API Key dependency handled by router
):
    """ Updates a community's logo. Requires creator permission. """
    conn = None
    old_logo_path = None
    new_logo_path = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check Permissions & Get Old Path
        community = crud.get_community_by_id(cursor, community_id)
        if not community:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")
        if community['created_by'] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to update this community's logo")
        old_logo_path = community.get('logo_path')
        community_name = community.get('name', f'community_{community_id}') # For path prefix

        # 2. Upload New Logo to MinIO
        if not utils.minio_client:
             raise HTTPException(status_code=500, detail="MinIO client not configured on server.")

        object_name_prefix = f"communities/{community_name.replace(' ', '_').lower()}/logo"
        new_logo_path = await utils.upload_file_to_minio(logo, object_name_prefix)

        if not new_logo_path:
             raise HTTPException(status_code=500, detail="Failed to upload new logo")

        # 3. Update Database Path
        updated_db = crud.update_community_logo_path_db(cursor, community_id, new_logo_path)
        if not updated_db:
            # Should not happen if community exists, but handle defensively
            conn.rollback()
             # Clean up newly uploaded file if DB update fails
            if new_logo_path: delete_from_minio(new_logo_path)
            raise HTTPException(status_code=500, detail="Failed to update logo path in database")

        conn.commit()

        # 4. Delete Old Logo from MinIO (AFTER DB commit)
        if old_logo_path:
             deleted_minio = delete_from_minio(old_logo_path)
             if not deleted_minio:
                 # Log warning, but don't fail the request
                 print(f"⚠️ Warning: Failed to delete old MinIO logo: {old_logo_path}")

        # 5. Fetch and Return Updated Community Data
        updated_community_db = crud.get_community_details_db(cursor, community_id)
        if not updated_community_db:
             # This is unlikely but possible
             raise HTTPException(status_code=500, detail="Could not retrieve updated community details after logo update")

        response_data = dict(updated_community_db)
        response_data['primary_location'] = str(updated_community_db.get('primary_location'))
        response_data['logo_url'] = get_minio_url(updated_community_db.get('logo_path')) # Should use new_logo_path
        return schemas.CommunityDisplay(**response_data)

    except HTTPException as http_exc:
        if conn: conn.rollback()
         # Clean up newly uploaded file if an HTTP error occurs during DB update phase
        if new_logo_path and not updated_db: delete_from_minio(new_logo_path)
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
         # Clean up newly uploaded file on general error
        if new_logo_path and 'updated_db' not in locals(): delete_from_minio(new_logo_path)
        print(f"❌ Error updating community logo {community_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not update community logo")
    finally:
        if conn: conn.close()


@router.delete("/{community_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_community(
        community_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Deletes a community (only creator can delete). Optionally deletes logo. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Check ownership and get logo path
        community = crud.get_community_by_id(cursor, community_id) # Basic info is enough
        if not community:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")
        if community["created_by"] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to delete this community")

        minio_logo_path_to_delete = community.get("logo_path")

        # Delete from DB first
        rows_deleted = crud.delete_community_db(cursor, community_id)
        conn.commit()

        if rows_deleted == 0:
            print(f"⚠️ Community {community_id} not found during delete (race condition?).")
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")

        # Attempt to delete logo from MinIO
        if minio_logo_path_to_delete and utils.minio_client:
            try:
                utils.minio_client.remove_object(utils.MINIO_BUCKET, minio_logo_path_to_delete)
                print(f"🗑️ Deleted MinIO object: {minio_logo_path_to_delete}")
            except Exception as minio_del_err:
                print(f"⚠️ Warning: Failed to delete MinIO object {minio_logo_path_to_delete}: {minio_del_err}")


        print(f"✅ Community {community_id} deleted by User {current_user_id}")
        return None
    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error deleting community {community_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not delete community")
    finally:
        if conn: conn.close()

# --- Membership ---
@router.post("/{community_id}/join", status_code=status.HTTP_200_OK)
async def join_community(
        community_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Allows the current user to join a community. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        member_id = crud.join_community_db(cursor, current_user_id, community_id)
        conn.commit()
        if member_id:
            print(f"✅ User {current_user_id} joined community {community_id}")
            return {"message": "Joined community successfully"}
        else:
            # User was already a member (ON CONFLICT DO NOTHING)
            print(f"ℹ️ User {current_user_id} already member of community {community_id}")
            return {"message": "Already a member"}
    except psycopg2.IntegrityError as e:
        if conn: conn.rollback()
        print(f"❌ Join Community Integrity Error: {e}")
        detail = "Could not join community."
        if 'community_members_community_id_fkey' in str(e):
            detail = "Community not found."
        elif 'community_members_user_id_fkey' in str(e):
            detail = "User not found." # Should not happen if token is valid
        raise HTTPException(status_code=400, detail=detail)
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error joining community {community_id} for user {current_user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Could not join community: {e}")
    finally:
        if conn: conn.close()

@router.delete("/{community_id}/leave", status_code=status.HTTP_200_OK)
async def leave_community(
        community_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Allows the current user to leave a community. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        deleted_id = crud.leave_community_db(cursor, current_user_id, community_id)
        conn.commit()
        if deleted_id:
            print(f"✅ User {current_user_id} left community {community_id}")
            return {"message": "Left community successfully"}
        else:
            # User was not a member
            print(f"ℹ️ User {current_user_id} not member of community {community_id}")
        return {"message": "Not a member of this community"}
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error leaving community {community_id} for user {current_user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Could not leave community: {e}")
    finally:
        if conn: conn.close()

# --- Community Post Management (Remains the same, doesn't involve images directly) ---
@router.post("/{community_id}/add_post/{post_id}", status_code=status.HTTP_201_CREATED)
async def add_post_to_community(
        community_id: int,
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Added auth dependency
):
    # TODO: Add permission check (e.g., is user a member/moderator?)
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        link_id = crud.add_post_to_community_db(cursor, community_id, post_id)
        conn.commit()
        if link_id:
            return {"message": "Post added to community"}
        else:
            # Could be duplicate or invalid IDs
            return {"message": "Post already in community or invalid IDs"}
    except psycopg2.IntegrityError:
        if conn: conn.rollback()
        raise HTTPException(status_code=404, detail="Community or Post not found")
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@router.delete("/{community_id}/remove_post/{post_id}", status_code=status.HTTP_200_OK)
async def remove_post_from_community(
        community_id: int,
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Added auth dependency
):
    # TODO: Add permission check (e.g., is user moderator or post author?)
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        deleted_id = crud.remove_post_from_community_db(cursor, community_id, post_id)
        conn.commit()
        if deleted_id:
            return {"message": "Post removed from community"}
        else:
            return {"message": "Post was not found in this community"}
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()


# --- Event routes scoped under community ---
# Moved event creation here for better context, includes image upload
@router.post("/{community_id}/events", status_code=status.HTTP_201_CREATED, response_model=schemas.EventDisplay)
async def create_event_in_community(
        community_id: int,
        current_user_id: int = Depends(auth.get_current_user),
        title: str = Form(...),
        description: Optional[str] = Form(None),
        location: str = Form(...),
        event_timestamp: datetime = Form(...), # FastAPI handles parsing ISO string from form
        max_participants: int = Form(100),
        image: Optional[UploadFile] = File(None)
):
    """
    Creates a new event within a specific community, optionally with an image.
    Stores the full image URL in the database.
    """
    conn = None
    minio_image_path = None
    minio_image_url = None
    try:
        # Handle Image Upload to MinIO
        if image and utils.minio_client:
            # Fetch community name for path prefix (optional)
            temp_conn_comm = get_db_connection()
            temp_cursor_comm = temp_conn_comm.cursor()
            community_info = crud.get_community_by_id(temp_cursor_comm, community_id)
            community_name = community_info.get('name', f'community_{community_id}') if community_info else f'community_{community_id}'
            temp_cursor_comm.close()
            temp_conn_comm.close()

            object_name_prefix = f"communities/{community_name.replace(' ', '_').lower()}/events/"
            minio_image_path = await upload_file_to_minio(image, object_name_prefix)
            if minio_image_path is None:
                print(f"⚠️ Warning: MinIO event image upload failed for community {community_id}")
            else:
                # Generate the full URL immediately for storing in DB
                minio_image_url = get_minio_url(minio_image_path)
                print(f"✅ Event image uploaded to MinIO: {minio_image_path}, URL: {minio_image_url}")

        conn = get_db_connection()
        cursor = conn.cursor()
        # TODO: Optional: Check if user is member/admin of the community before allowing creation

        event_info = crud.create_event_db(
            cursor,
            community_id=community_id,
            creator_id=current_user_id,
            title=title,
            description=description,
            location=location,
            event_timestamp=event_timestamp,
            max_participants=max_participants,
            image_url=minio_image_url # Pass the generated URL to CRUD
        )
        if not event_info:
            raise HTTPException(status_code=500, detail="Event creation failed in database")

        conn.commit()
        event_id = event_info['id']
        created_at = event_info['created_at']
        print(f"✅ Event {event_id} created in community {community_id} by user {current_user_id}")

        # Fetch full details for response (including participant count)
        event_details_db = crud.get_event_details_db(cursor, event_id)
        if not event_details_db:
            # This could happen if the create_event_db logic doesn't add the creator
            # or if the details fetch fails for some reason.
            print(f"⚠️ Warning: Could not fetch details for newly created event {event_id}")
            # Return basic info based on creation data as fallback
            return schemas.EventDisplay(
                id=event_id, community_id=community_id, creator_id=current_user_id,
                created_at=created_at, title=title, description=description, location=location,
                event_timestamp=event_timestamp, max_participants=max_participants,
                image_url=minio_image_url, participant_count=1 # Assume creator joined
            )

        # Return the full EventDisplay structure using fetched details
        # Ensure image_url is handled correctly (it should be in event_details_db)
        return schemas.EventDisplay(**event_details_db)

    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ DB Error creating event: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error creating event: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

@router.get("/{community_id}/events", response_model=List[schemas.EventDisplay])
async def list_community_events(community_id: int):
    """ Lists events for a specific community. Image URLs are included directly. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        events_db = crud.get_events_for_community_db(cursor, community_id)
        print(f"✅ Fetched {len(events_db)} events for community {community_id}")
        # EventDisplay schema expects image_url, which is directly in events_db
        return [schemas.EventDisplay(**event) for event in events_db] # Validate list items
    except Exception as e:
        print(f"❌ Error fetching community events {community_id}: {e}")
        raise HTTPException(status_code=500, detail="Error fetching events")
    finally:
        if conn: conn.close()
