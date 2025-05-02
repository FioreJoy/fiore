# backend/src/routers/communities.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File
from typing import List, Optional, Dict, Any # Added Dict, Any
import psycopg2
from datetime import datetime
import os

# Use the central crud import
from .. import schemas, crud, auth, utils
from ..database import get_db_connection
from ..utils import upload_file_to_minio, get_minio_url, delete_from_minio

# Import JWT for optional auth dependency
import jwt
from fastapi import Header # For optional auth header

router = APIRouter(
    prefix="/communities",
    tags=["Communities"],
    # dependencies=[Depends(auth.get_current_user)] # Apply auth per-route as needed
)

@router.post("", status_code=status.HTTP_201_CREATED, response_model=schemas.CommunityDisplay)
async def create_community(
        current_user_id: int = Depends(auth.get_current_user), # Require auth to create
        name: str = Form(...),
        description: Optional[str] = Form(None),
        primary_location: str = Form("(0,0)"), # Expecting "(lon,lat)" string
        interest: Optional[str] = Form(None), # Now optional, ensure DB allows NULL
        logo: Optional[UploadFile] = File(None)
):
    """ Creates a new community (relational + graph), optionally with a logo. """
    conn = None
    minio_logo_path = None
    community_id = None
    try:
        # 1. Handle Logo Upload to MinIO first
        if logo and utils.minio_client:
            # Sanitize name for path prefix
            safe_name = name.replace(' ', '_').lower()
            safe_name = ''.join(c for c in safe_name if c.isalnum() or c in ['_','-']) # Basic sanitize
            object_name_prefix = f"communities/{safe_name}/logo"
            minio_logo_path = await upload_file_to_minio(logo, object_name_prefix)
            if minio_logo_path is None:
                print(f"⚠️ Warning: MinIO community logo upload failed for {name}")
                # Proceed without logo path
        else:
            minio_logo_path = None

        # 2. Format location string for DB
        db_location_str = utils.format_location_for_db(primary_location)

        # 3. Create Community in DB (relational + graph)
        conn = get_db_connection()
        cursor = conn.cursor()
        # crud.create_community_db handles relational insert, graph vertex, and edges
        community_id = crud.create_community_db(
            cursor, name=name, description=description, created_by=current_user_id,
            primary_location_str=db_location_str, interest=interest, logo_path=minio_logo_path
        )
        if community_id is None:
            if minio_logo_path: delete_from_minio(minio_logo_path) # Cleanup upload
            raise HTTPException(status_code=500, detail="Community creation failed in database")

        # 4. Fetch created community details for response (includes counts)
        created_community_db = crud.get_community_details_db(cursor, community_id)
        if not created_community_db:
            conn.rollback() # Rollback if fetch failed
            if minio_logo_path: delete_from_minio(minio_logo_path)
            raise HTTPException(status_code=500, detail="Could not retrieve created community details")

        conn.commit() # Commit successful creation

        # 5. Prepare response data
        response_data = dict(created_community_db)
        # Location needs parsing from POINT string for display schema
        loc_point_str = response_data.get('primary_location')
        response_data['primary_location'] = str(loc_point_str) if loc_point_str else None # Send as string
        # Generate logo URL
        response_data['logo_url'] = get_minio_url(response_data.get('logo_path'))

        print(f"✅ Community '{name}' (ID: {community_id}) created by User {current_user_id}")
        return schemas.CommunityDisplay(**response_data) # Validate

    except psycopg2.IntegrityError as e:
        if conn: conn.rollback()
        if minio_logo_path: delete_from_minio(minio_logo_path)
        print(f"❌ Community Creation Integrity Error: {e}")
        detail="Community name may already exist or invalid data provided."
        if 'communities_created_by_fkey' in str(e): detail = "Creator user not found."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback() # Rollback on HTTP errors if transaction started
        if minio_logo_path and community_id is None: delete_from_minio(minio_logo_path) # Cleanup if raised early
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        if minio_logo_path and community_id is None: delete_from_minio(minio_logo_path)
        print(f"❌ Error creating community: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Could not create community: {e}")
    finally:
        if conn: conn.close()


@router.get("", response_model=List[schemas.CommunityDisplay])
async def get_communities(
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional) # Optional auth
):
    """ Fetches a list of all communities, augmented with counts. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Fetch relational data first
        communities_relational = crud.get_communities_db(cursor)

        processed_communities = []
        # Augment with graph counts
        for comm_rel in communities_relational:
            comm_data = dict(comm_rel)
            comm_id = comm_data['id']
            try:
                counts = crud.get_community_counts(cursor, comm_id)
                comm_data.update(counts)
            except Exception as e:
                print(f"Warning: Failed to get counts for community {comm_id}: {e}")
                comm_data.update({'member_count': 0, 'online_count': 0}) # Add defaults

            # Format location and logo URL
            loc_point_str = comm_data.get('primary_location')
            comm_data['primary_location'] = str(loc_point_str) if loc_point_str else None
            comm_data['logo_url'] = get_minio_url(comm_data.get('logo_path'))

            # TODO: Add user join status if authenticated
            # is_joined = False
            # if current_user_id is not None:
            #     # Query graph: RETURN EXISTS((:User {id:..})-[:MEMBER_OF]->(:Community {id:..}))
            #     pass
            # comm_data['is_joined'] = is_joined # Add to schema if needed

            processed_communities.append(schemas.CommunityDisplay(**comm_data)) # Validate

        print(f"✅ Fetched {len(processed_communities)} communities")
        return processed_communities
    except Exception as e:
        print(f"❌ Error fetching communities: {e}")
        raise HTTPException(status_code=500, detail="Error fetching communities")
    finally:
        if conn: conn.close()


@router.get("/trending", response_model=List[schemas.CommunityDisplay])
async def get_trending_communities(
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional) # Optional auth
):
    """ Fetches trending communities (currently uses relational counts). """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # This still uses the relational-based query for trending logic
        communities_db = crud.get_trending_communities_db(cursor)

        processed_communities = []
        for comm in communities_db:
            data = dict(comm)
            loc_point_str = comm.get('primary_location')
            data['primary_location'] = str(loc_point_str) if loc_point_str else None
            data['logo_url'] = get_minio_url(comm.get('logo_path'))
            # Fetch graph online count (member_count is from the SQL query)
            try:
                graph_counts = crud.get_community_counts(cursor, data['id'])
                data['online_count'] = graph_counts.get('online_count', 0) # Get only online count
            except Exception as e:
                print(f"Warning: Failed fetching online count for trending comm {data['id']}: {e}")
                data['online_count'] = 0

            # TODO: Add join status if authenticated
            # data['is_joined'] = ...

            processed_communities.append(schemas.CommunityDisplay(**data))

        print(f"✅ Fetched {len(processed_communities)} trending communities")
        return processed_communities
    except Exception as e:
        print(f"❌ Error fetching trending communities: {e}")
        raise HTTPException(status_code=500, detail="Error fetching trending communities")
    finally:
        if conn: conn.close()

@router.get("/{community_id}/details", response_model=schemas.CommunityDisplay)
async def get_community_details(
        community_id: int,
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional) # Optional auth
):
    """ Fetches details for a specific community (relational + graph counts). """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # get_community_details_db fetches combined data
        community_db = crud.get_community_details_db(cursor, community_id)
        if not community_db:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")

        response_data = dict(community_db)
        loc_point_str = response_data.get('primary_location')
        response_data['primary_location'] = str(loc_point_str) if loc_point_str else None
        response_data['logo_url'] = get_minio_url(response_data.get('logo_path'))

        # TODO: Add user join status if authenticated
        # response_data['is_joined'] = ...

        print(f"✅ Details fetched for community {community_id}")
        return schemas.CommunityDisplay(**response_data)
    except Exception as e:
        print(f"❌ Error fetching community details {community_id}: {e}")
        raise HTTPException(status_code=500, detail="Error fetching community details")
    finally:
        if conn: conn.close()

@router.put("/{community_id}", response_model=schemas.CommunityDisplay)
async def update_community_details(
        community_id: int,
        update_data_schema: schemas.CommunityUpdate, # Use schema for JSON body validation
        current_user_id: int = Depends(auth.get_current_user) # Require auth
):
    """ Updates a community's details (name, description, etc.). Requires creator permission. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check Permissions: Verify current user is the creator
        community = crud.get_community_by_id(cursor, community_id) # Fetch relational data for creator check
        if not community:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")
        if community['created_by'] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to update this community")

        # 2. Prepare update data (only non-null fields from schema)
        update_dict = update_data_schema.model_dump(exclude_unset=True) # Pydantic v2
        if not update_dict:
            raise HTTPException(status_code=400, detail="No update data provided")

        # Format location if present
        if 'primary_location' in update_dict and update_dict['primary_location']:
            update_dict['primary_location'] = utils.format_location_for_db(update_dict['primary_location'])

        # 3. Attempt Update (handles relational + graph)
        updated = crud.update_community_details_db(cursor, community_id, update_dict)

        if not updated:
            # Could mean community not found during update or no rows affected
            conn.rollback()
            raise HTTPException(status_code=500, detail="Failed to update community in database")

        conn.commit() # Commit successful update

        # 4. Fetch and return updated data (includes counts)
        updated_community_db = crud.get_community_details_db(cursor, community_id)
        if not updated_community_db:
            # Should not happen if update succeeded, but handle defensively
            raise HTTPException(status_code=500, detail="Could not retrieve updated community details")

        # Format response
        response_data = dict(updated_community_db)
        loc_point_str = response_data.get('primary_location')
        response_data['primary_location'] = str(loc_point_str) if loc_point_str else None
        response_data['logo_url'] = get_minio_url(response_data.get('logo_path'))
        print(f"✅ Community {community_id} details updated by User {current_user_id}")
        return schemas.CommunityDisplay(**response_data)

    except psycopg2.IntegrityError as e:
        if conn: conn.rollback()
        print(f"❌ Community Update Integrity Error: {e}")
        detail="Database integrity error. Name might already exist."
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


@router.post("/{community_id}/logo", response_model=schemas.CommunityDisplay)
async def update_community_logo(
        community_id: int,
        current_user_id: int = Depends(auth.get_current_user), # Require auth
        logo: UploadFile = File(...), # Require logo file
):
    """ Updates a community's logo. Requires creator permission. """
    conn = None
    old_logo_path = None
    new_logo_path = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check Permissions & Get Old Path/Name
        community = crud.get_community_by_id(cursor, community_id)
        if not community: raise HTTPException(status_code=404, detail="Community not found")
        if community['created_by'] != current_user_id: raise HTTPException(status_code=403, detail="Not authorized")
        old_logo_path = community.get('logo_path')
        community_name = community.get('name', f'community_{community_id}')

        # 2. Upload New Logo to MinIO
        if not utils.minio_client: raise HTTPException(status_code=500, detail="MinIO not configured")
        safe_name = community_name.replace(' ', '_').lower()
        safe_name = ''.join(c for c in safe_name if c.isalnum() or c in ['_','-'])
        object_name_prefix = f"communities/{safe_name}/logo"
        new_logo_path = await upload_file_to_minio(logo, object_name_prefix)
        if not new_logo_path: raise HTTPException(status_code=500, detail="Failed to upload new logo")

        # 3. Update Database Path (Relational only, graph node doesn't store path)
        updated_db = crud.update_community_logo_path_db(cursor, community_id, new_logo_path)
        if not updated_db:
            conn.rollback()
            delete_from_minio(new_logo_path) # Cleanup upload
            raise HTTPException(status_code=500, detail="Failed to update logo path in database")

        conn.commit() # Commit DB change

        # 4. Delete Old Logo from MinIO (AFTER DB commit)
        if old_logo_path: delete_from_minio(old_logo_path)

        # 5. Fetch and Return Updated Community Data (includes counts)
        updated_community_db = crud.get_community_details_db(cursor, community_id)
        if not updated_community_db: raise HTTPException(status_code=500, detail="Could not retrieve updated details")

        response_data = dict(updated_community_db)
        loc_point_str = response_data.get('primary_location')
        response_data['primary_location'] = str(loc_point_str) if loc_point_str else None
        response_data['logo_url'] = get_minio_url(response_data.get('logo_path')) # Should be new path
        print(f"✅ Community {community_id} logo updated by User {current_user_id}")
        return schemas.CommunityDisplay(**response_data)

    except HTTPException as http_exc:
        if conn: conn.rollback()
        # Cleanup potential upload if error occurred after upload but before commit
        if new_logo_path and old_logo_path is None: delete_from_minio(new_logo_path)
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        if new_logo_path and old_logo_path is None: delete_from_minio(new_logo_path)
        print(f"❌ Error updating community logo {community_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not update community logo")
    finally:
        if conn: conn.close()


@router.delete("/{community_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_community(
        community_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Require auth
):
    """ Deletes a community (requires ownership). Deletes relational, graph, and logo. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # 1. Check ownership and get logo path BEFORE deleting
        community = crud.get_community_by_id(cursor, community_id)
        if not community: raise HTTPException(status_code=404, detail="Community not found")
        if community["created_by"] != current_user_id: raise HTTPException(status_code=403, detail="Not authorized")
        minio_logo_path_to_delete = community.get("logo_path")

        # 2. Delete from DB (relational + graph)
        deleted = crud.delete_community_db(cursor, community_id)
        if not deleted:
            conn.rollback()
            raise HTTPException(status_code=404, detail="Community not found during deletion")

        conn.commit() # Commit successful DB deletion

        # 3. Attempt to delete logo from MinIO
        if minio_logo_path_to_delete: delete_from_minio(minio_logo_path_to_delete)

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


# --- Membership (Graph Operations) ---
@router.post("/{community_id}/join", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def join_community(
        community_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Require auth
):
    """ Allows the current user to join a community (creates graph edge). """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        success = crud.join_community_db(cursor, current_user_id, community_id)
        conn.commit()

        counts = crud.get_community_counts(cursor, community_id) # Get updated counts

        print(f"✅ User {current_user_id} joined community {community_id}")
        return {
            "message": "Joined community successfully",
            "success": success,
            "new_counts": counts
        }
    except psycopg2.Error as e: # Catch potential MATCH failure if nodes don't exist
        if conn: conn.rollback()
        print(f"❌ DB Error joining community {community_id}: {e}")
        raise HTTPException(status_code=404, detail="Community or User not found")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error joining community {community_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not join community")
    finally:
        if conn: conn.close()


@router.delete("/{community_id}/leave", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def leave_community(
        community_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Require auth
):
    """ Allows the current user to leave a community (deletes graph edge). """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        deleted = crud.leave_community_db(cursor, current_user_id, community_id)
        conn.commit()

        counts = crud.get_community_counts(cursor, community_id) # Get updated counts

        print(f"✅ User {current_user_id} left community {community_id}. Deleted: {deleted}")
        return {
            "message": "Left community successfully" if deleted else "Not a member of this community",
            "success": deleted,
            "new_counts": counts
        }
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error leaving community {community_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not leave community")
    finally:
        if conn: conn.close()


# --- Community Post Linking (Graph Operations) ---
@router.post("/{community_id}/posts/{post_id}", status_code=status.HTTP_201_CREATED, response_model=Dict[str, Any]) # Changed endpoint slightly
async def add_post_to_community(
        community_id: int,
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Require auth & maybe check membership/ownership
):
    """Links an existing post to a community (creates graph edge)."""
    # TODO: Add permission check (e.g., is user member? is user post author?)
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # This creates :HAS_POST edge
        success = crud.add_post_to_community_db(cursor, community_id, post_id)
        conn.commit()
        print(f"✅ Post {post_id} linked to community {community_id}")
        return {"message": "Post added to community", "success": success}
    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ DB Error linking post {post_id} to comm {community_id}: {e}")
        raise HTTPException(status_code=404, detail="Community or Post not found")
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()


@router.delete("/{community_id}/posts/{post_id}", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def remove_post_from_community(
        community_id: int,
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Require auth & permission check
):
    """Unlinks a post from a community (deletes graph edge)."""
    # TODO: Add permission check (e.g., user is moderator or post author?)
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # This deletes :HAS_POST edge
        deleted = crud.remove_post_from_community_db(cursor, community_id, post_id)
        conn.commit()
        print(f"✅ Post {post_id} unlinked from community {community_id}. Deleted: {deleted}")
        return {"message": "Post removed from community" if deleted else "Post was not linked to this community", "success": deleted}
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error unlinking post {post_id} from comm {community_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

# --- List Events for Community (Moved from events router, uses updated CRUD) ---
@router.get("/{community_id}/events", response_model=List[schemas.EventDisplay])
async def list_community_events(
        community_id: int,
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional) # Optional auth
):
    """ Lists events for a specific community. Includes participant counts. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # This now gets relational data + participant count from graph
        events_db = crud.get_events_for_community_db(cursor, community_id)

        processed_events = []
        for event in events_db:
            event_data = dict(event)
            # TODO: Add user participation status if authenticated
            # event_data['is_participating'] = ... # Query graph: EXISTS((:User)-[:PART..]->(:Event))
            processed_events.append(schemas.EventDisplay(**event_data)) # Validate

        print(f"✅ Fetched {len(processed_events)} events for community {community_id}")
        return processed_events
    except Exception as e:
        print(f"❌ Error fetching community events {community_id}: {e}")
        raise HTTPException(status_code=500, detail="Error fetching events")
    finally:
        if conn: conn.close()

# --- Create Event in Community (Moved from events router, uses updated CRUD) ---
@router.post("/{community_id}/events", status_code=status.HTTP_201_CREATED, response_model=schemas.EventDisplay)
async def create_event_in_community(
        community_id: int,
        current_user_id: int = Depends(auth.get_current_user), # Require auth to create
        # Form data for event
        title: str = Form(...),
        description: Optional[str] = Form(None),
        location: str = Form(...),
        event_timestamp: datetime = Form(...),
        max_participants: int = Form(100),
        image: Optional[UploadFile] = File(None)
):
    """ Creates a new event within a specific community (relational + graph). """
    conn = None
    minio_image_path = None
    event_id = None
    try:
        # 1. Handle Image Upload
        image_url_or_path = None # Store path or URL based on decision
        if image and utils.minio_client:
            # Fetch community name for path prefix
            temp_conn_comm = get_db_connection(); temp_cursor_comm = temp_conn_comm.cursor()
            comm_info = crud.get_community_by_id(temp_cursor_comm, community_id)
            community_name = comm_info.get('name', f'c_{community_id}') if comm_info else f'c_{community_id}'
            temp_cursor_comm.close(); temp_conn_comm.close()

            object_name_prefix = f"communities/{community_name.replace(' ', '_').lower()}/events/"
            image_url_or_path = await upload_file_to_minio(image, object_name_prefix)
            if image_url_or_path is None: print(f"⚠️ Event image upload failed") # Continue without image

        # 2. Create Event in DB (Relational + Graph)
        conn = get_db_connection()
        cursor = conn.cursor()
        # create_event_db handles relational insert, graph vertex, and edges
        event_info = crud.create_event_db(
            cursor, community_id=community_id, creator_id=current_user_id, title=title,
            description=description, location=location, event_timestamp=event_timestamp,
            max_participants=max_participants, image_url=image_url_or_path # Pass MinIO path/name
        )
        if not event_info or 'id' not in event_info:
            if image_url_or_path: delete_from_minio(image_url_or_path) # Cleanup
            raise HTTPException(status_code=500, detail="Event creation failed in database")
        event_id = event_info['id']

        # 3. Fetch full details for response (includes participant count)
        event_details_db = crud.get_event_details_db(cursor, event_id)
        if not event_details_db:
            conn.rollback(); # Rollback if fetch failed
            if image_url_or_path: delete_from_minio(image_url_or_path)
            raise HTTPException(status_code=500, detail="Could not retrieve created event details")

        conn.commit() # Commit successful creation

        # 4. Prepare and return response
        response_data = dict(event_details_db)
        # Generate URL from path if needed
        response_data['image_url'] = get_minio_url(response_data.get('image_url')) # Use stored path/name
        print(f"✅ Event {event_id} created in community {community_id} by user {current_user_id}")
        return schemas.EventDisplay(**response_data)

    # --- Error Handling (similar to create_community) ---
    except psycopg2.Error as e:
        if conn: conn.rollback()
        if image_url_or_path and event_id is None: delete_from_minio(image_url_or_path)
        print(f"❌ DB Error creating event: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except HTTPException as http_exc:
        if conn: conn.rollback()
        if image_url_or_path and event_id is None: delete_from_minio(image_url_or_path)
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        if image_url_or_path and event_id is None: delete_from_minio(image_url_or_path)
        print(f"❌ Error creating event: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()