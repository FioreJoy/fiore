# backend/src/routers/communities.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File
from typing import List, Optional, Dict, Any # Added Dict, Any
import psycopg2
from datetime import datetime
import traceback # Ensure import
from .. import utils # Ensure import
import uuid # <-- ADD IMPORT

# Use the central crud import
from .. import schemas, crud, auth, utils
from ..database import get_db_connection
from ..utils import upload_file_to_minio, get_minio_url, delete_from_minio, delete_media_item_db_and_file

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
        primary_location: str = Form("(0,0)"),
        interest: Optional[str] = Form(None),
        logo: Optional[UploadFile] = File(None)
):
    """ Creates a new community (relational + graph), optionally uploads/links a logo. """
    conn = None
    community_id = None
    upload_result_dict: Optional[Dict[str, Any]] = None # To store result from MinIO upload
    created_media_id: Optional[int] = None

    try:
        # 1. Handle Logo Upload to MinIO first (if provided)
        if logo and utils.minio_client:
            safe_name = name.replace(' ', '_').lower()
            safe_name = ''.join(c for c in safe_name if c.isalnum() or c in ['_','-']) or f"comm_{uuid.uuid4()}"
            object_name_prefix = f"communities/{safe_name}/logo"
            # Store the dict returned by upload_file_to_minio
            upload_result_dict = await utils.upload_file_to_minio(logo, object_name_prefix)
            if upload_result_dict is None or 'minio_object_name' not in upload_result_dict:
                print(f"⚠️ Warning: MinIO community logo upload failed for {name}. Proceeding without logo.")
                upload_result_dict = None # Ensure it's None if upload failed

        # 2. Format location string for DB
        db_location_str = utils.format_location_for_db(primary_location)

        # --- Start DB Transaction ---
        conn = get_db_connection()
        cursor = conn.cursor()

        # 3. Create Community base record (DB + Graph)
        community_id = crud.create_community_db(
            cursor, name=name, description=description, created_by=current_user_id,
            primary_location_str=db_location_str, interest=interest
            # REMOVE logo_path=... from this call
        )
        if community_id is None:
            # If community creation fails, cleanup potential upload BEFORE raising error
            if upload_result_dict and 'minio_object_name' in upload_result_dict:
                delete_from_minio(upload_result_dict['minio_object_name'])
            raise HTTPException(status_code=500, detail="Community base creation failed in database")

        # 4. Create Media Item record and Link logo (if upload succeeded)
        if upload_result_dict and 'minio_object_name' in upload_result_dict:
            # Use the dictionary returned by the upload function
            created_media_id = crud.create_media_item(
                cursor, uploader_user_id=current_user_id, **upload_result_dict
            )
            if created_media_id:
                crud.set_community_logo(cursor, community_id, created_media_id)
                print(f"Linked logo media {created_media_id} to community {community_id}")
            else:
                # If DB record for media fails, cleanup MinIO upload
                print(f"WARN CreateCommunity: Failed to create media record for logo {upload_result_dict['minio_object_name']}")
                delete_from_minio(upload_result_dict['minio_object_name'])
                # Allow community creation to succeed, but log the warning
                created_media_id = None # Ensure no attempt to delete it later

        # 5. Fetch created community details for response
        # get_community_details_db includes counts
        created_community_db = crud.get_community_details_db(cursor, community_id)
        if not created_community_db:
            # This means fetching failed right after creation - indicates a problem
            conn.rollback() # Rollback the creation
            if upload_result_dict and 'minio_object_name' in upload_result_dict:
                delete_from_minio(upload_result_dict['minio_object_name']) # Cleanup upload too
            raise HTTPException(status_code=500, detail="Could not retrieve created community details after creation")

        # Fetch logo media info again to get URL for response object
        logo_media_for_response = None
        if created_media_id: # If we successfully linked a new logo
            logo_media_for_response = crud.get_media_item_by_id(cursor, created_media_id)

        conn.commit() # Commit successful creation and potential logo link

        # 6. Prepare response data
        response_data = dict(created_community_db)
        location_value = response_data.get('primary_location')
        if isinstance(location_value, dict) and 'longitude' in location_value and 'latitude' in location_value:
            # It's a dict, format it back to string
            lon = location_value['longitude']
            lat = location_value['latitude']
            response_data['primary_location'] = f"({lon},{lat})"
        elif isinstance(location_value, (str, type(None))):
            # It's already a string (or None), or it's some other DB point type representation.
            # If it's a DB point type, str(point_obj) usually gives "(x,y)"
            response_data['primary_location'] = str(location_value) if location_value else None
        else:
            # Fallback if it's an unexpected type
            print(f"WARN: Unexpected primary_location type: {type(location_value)}. Setting to None for response.")
            response_data['primary_location'] = None
        # --- END FIX ---
        response_data['logo_url'] = utils.get_minio_url(logo_media_for_response.get('minio_object_name')) if logo_media_for_response else None
        response_data.setdefault('is_member_by_viewer', True) # Creator is automatically a member

        print(f"✅ Community '{name}' (ID: {community_id}) created by User {current_user_id}")
        return schemas.CommunityDisplay(**response_data) # Validate

    except psycopg2.IntegrityError as e:
        if conn: conn.rollback()
        # Cleanup potential upload if DB fails due to constraint (e.g., name exists)
        if upload_result_dict and 'minio_object_name' in upload_result_dict: delete_from_minio(upload_result_dict['minio_object_name'])
        print(f"❌ Community Creation Integrity Error: {e}")
        detail="Community name may already exist or invalid data provided."
        # Check specific constraint if needed
        if hasattr(e, 'diag') and e.diag.constraint_name == 'communities_name_key': detail = "Community name already taken."
        elif hasattr(e, 'pgcode') and e.pgcode == '23503': detail = "Invalid creator user or other foreign key."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback()
        # Cleanup only if upload happened but DB steps failed before commit
        if upload_result_dict and 'minio_object_name' in upload_result_dict and community_id is None:
            delete_from_minio(upload_result_dict['minio_object_name'])
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        if upload_result_dict and 'minio_object_name' in upload_result_dict and community_id is None:
            delete_from_minio(upload_result_dict['minio_object_name'])
        print(f"❌ Error creating community: {e}")
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
            comm_data['logo_url'] = utils.get_minio_url(comm_data.get('logo_path'))

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
            data['logo_url'] = utils.get_minio_url(comm.get('logo_path'))
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
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Fetches relational data + graph counts
        community_db = crud.get_community_details_db(cursor, community_id)
        if not community_db:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")

        response_data = dict(community_db)
        loc_point_str = response_data.get('primary_location')
        response_data['primary_location'] = str(loc_point_str) if loc_point_str else None

        # --- Explicitly fetch CURRENT logo media AFTER fetching base details ---
        logo_media = crud.get_community_logo_media(cursor, community_id)
        response_data['logo_url'] = logo_media.get('url') if logo_media else None
        print(f"DEBUG GET /details C:{community_id}: Fetched logo URL: {response_data['logo_url']}") # Log fetched URL
        # --- End Logo Fetch ---

        # Add defaults/viewer status
        response_data.setdefault('member_count', 0); response_data.setdefault('online_count', 0)
        response_data.setdefault('is_member_by_viewer', False) # Default
        if current_user_id:
            try: response_data['is_member_by_viewer'] = crud.check_is_member(cursor, current_user_id, community_id)
            except Exception as e: print(f"WARN GET /details C:{community_id}: Check member failed: {e}")

        print(f"✅ Details fetched for community {community_id}")
        return schemas.CommunityDisplay(**response_data)
    # ... (keep existing error handling) ...
    except Exception as e:
        print(f"❌ Error fetching community details {community_id}: {e}")
        traceback.print_exc() # Print traceback on error
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
        response_data['logo_url'] = utils.get_minio_url(response_data.get('logo_path'))
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
        current_user_id: int = Depends(auth.get_current_user),
        logo: UploadFile = File(...),
):
    """ Updates a community's logo. Requires creator permission. """
    conn = None
    old_logo_media_info = None
    new_minio_object_name = None
    new_media_id = None
    try:
        conn = get_db_connection(); cursor = conn.cursor() # Use single cursor for transaction

        # 1. Check Permissions & Get Old Media Info
        # ... (same as before) ...
        community_check = crud.get_community_by_id(cursor, community_id)
        if not community_check: raise HTTPException(status_code=404, detail="Community not found")
        if community_check['created_by'] != current_user_id: raise HTTPException(status_code=403, detail="Not authorized")
        community_name = community_check.get('name', f'community_{community_id}')
        old_logo_media_info = crud.get_community_logo_media(cursor, community_id)

        # 2. Upload New Logo to MinIO
        # ... (same as before) ...
        if not utils.minio_client: raise HTTPException(status_code=500, detail="MinIO not configured")
        safe_name = community_name.replace(' ', '_').lower()
        safe_name = ''.join(c for c in safe_name if c.isalnum() or c in ['_','-'])
        object_name_prefix = f"communities/{safe_name}/logo"
        upload_info = await utils.upload_file_to_minio(logo, object_name_prefix)
        if not upload_info or 'minio_object_name' not in upload_info:
            raise HTTPException(status_code=500, detail="Failed to upload new logo to storage")
        new_minio_object_name = upload_info['minio_object_name']
        print(f"Router: Uploaded new logo to MinIO: {new_minio_object_name}")

        # --- Transaction Start ---
        # 3. Create new media item record in DB
        new_media_id = crud.create_media_item(
            cursor, uploader_user_id=current_user_id, **upload_info
        )
        if not new_media_id:
            delete_from_minio(new_minio_object_name) # Cleanup upload
            raise HTTPException(status_code=500, detail="Failed to record uploaded logo in database")
        print(f"Router: Created media item record ID: {new_media_id}")

        # 4. Update the community_logo link table using the NEW media_id
        print(f"Router: Attempting to link C:{community_id} with M:{new_media_id}...")
        # This call will now raise psycopg2.Error on failure
        crud.set_community_logo(cursor, community_id, new_media_id)
        print(f"Router: Link successful (set_community_logo executed without error).")

        # If we reach here without exception, commit the transaction
        conn.commit()
        print(f"Router: DB transaction committed (new media item created, link set).")
        # --- Transaction End ---

        # 5. Delete Old Logo (Media Item record and MinIO file) AFTER successful commit
        if old_logo_media_info and 'id' in old_logo_media_info and 'minio_object_name' in old_logo_media_info:
            old_media_id_to_delete = old_logo_media_info['id']
            old_minio_path_to_delete = old_logo_media_info['minio_object_name']
            print(f"Router: Attempting to delete old logo ...")
            # Use the explicitly imported helper function with await
            deleted_old = utils.delete_media_item_db_and_file(old_media_id_to_delete, old_minio_path_to_delete) # <--- Use directly
            print(f"Router: Old logo deletion result (DB success reported): {deleted_old}")


        # 6. Fetch and Return Updated Community Data
        # ... (same as before, using new connection) ...
        conn_fetch = None
        try:
            conn_fetch = get_db_connection(); cursor_fetch = conn_fetch.cursor()
            updated_community_db = crud.get_community_details_db(cursor_fetch, community_id)
            logo_media = crud.get_community_logo_media(cursor_fetch, community_id) # Fetch new logo media details
        finally:
            if conn_fetch: conn_fetch.close()
        # ... (rest of fetch and response preparation) ...
        if not updated_community_db:
            print(f"ERROR: Could not fetch community details after successful logo update for C:{community_id}")
            raise HTTPException(status_code=500, detail="Could not retrieve updated details after logo update")

        response_data = dict(updated_community_db)
        loc = response_data.get('primary_location'); response_data['primary_location'] = str(loc) if loc else None
        response_data['logo_url'] = logo_media.get('url') if logo_media else None
        response_data.setdefault('member_count', 0); response_data.setdefault('online_count', 0)
        response_data.setdefault('is_member_by_viewer', False)

        print(f"✅ Community {community_id} logo updated by User {current_user_id}")
        return schemas.CommunityDisplay(**response_data)

    except HTTPException as http_exc:
        if conn: conn.rollback()
        if new_minio_object_name and new_media_id is None: delete_from_minio(new_minio_object_name)
        print(f"Router LOGO UPDATE HTTP Exception: {http_exc.detail}")
        raise http_exc
    except psycopg2.Error as db_err: # Catch specific DB errors raised from CRUD
        if conn: conn.rollback()
        if new_minio_object_name and new_media_id is None: delete_from_minio(new_minio_object_name)
        print(f"Router LOGO UPDATE DB Error: {db_err} (Code: {db_err.pgcode})")
        # Log the detailed traceback for DB errors during the critical link step
        traceback.print_exc()
        # Provide a more specific message if possible based on pgcode
        detail = "Database error during logo update."
        if db_err.pgcode == '23503': # Foreign Key Violation
            detail = "Failed to link logo: Invalid community or media reference."
        # Use the original error detail from the test
        raise HTTPException(status_code=500, detail="Failed to link new logo in database")
    except Exception as e:
        if conn: conn.rollback()
        if new_minio_object_name and new_media_id is None: delete_from_minio(new_minio_object_name)
        print(f"❌ Unexpected Error updating community logo {community_id}: {e}")
        traceback.print_exc(); # Now traceback is defined
        raise HTTPException(status_code=500, detail="An internal error occurred while updating the logo.")
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
# --- Add Event in Community ---
@router.post("/{community_id}/events", status_code=status.HTTP_201_CREATED, response_model=schemas.EventDisplay)
async def create_event_in_community(
        community_id: int,
        current_user_id: int = Depends(auth.get_current_user),
        # Form data for event
        title: str = Form(...),
        description: Optional[str] = Form(None),
        location: str = Form(...),
        event_timestamp: datetime = Form(...),
        max_participants: int = Form(100),
        image: Optional[UploadFile] = File(None)
):
    conn = None
    minio_object_name = None
    event_id = None
    upload_info = None

    try:
        # --- Define object_name_prefix BEFORE using it ---
        object_name_prefix = f"media/events/unknown_community/{uuid.uuid4()}" # Default path

        # 1. Handle Image Upload
        if image and utils.minio_client:
            # Fetch community name for path prefix (use temporary connection)
            temp_conn_comm = None
            try:
                temp_conn_comm = get_db_connection(); temp_cursor_comm = temp_conn_comm.cursor()
                comm_info = crud.get_community_by_id(temp_cursor_comm, community_id)
                community_name_for_path = comm_info.get('name', f'c_{community_id}') if comm_info else f'c_{community_id}'
                # Sanitize community name for path
                safe_community_name = community_name_for_path.replace(' ', '_').lower()
                safe_community_name = ''.join(c for c in safe_community_name if c.isalnum() or c in ['_','-'])
                object_name_prefix = f"media/communities/{safe_community_name}/events" # Define path using community name
            except Exception as comm_fetch_err:
                print(f"WARN: Failed to fetch community name for event image path: {comm_fetch_err}. Using default path.")
                # Keep the default object_name_prefix defined above
            finally:
                if temp_conn_comm: temp_conn_comm.close()

            upload_info = await utils.upload_file_to_minio(image, object_name_prefix) # NOW prefix is defined
            if upload_info and 'minio_object_name' in upload_info:
                minio_object_name = upload_info['minio_object_name']
            else:
                print(f"⚠️ Event image upload failed")
                minio_object_name = None

        # 2. Create Event in DB
        conn = get_db_connection(); cursor = conn.cursor()
        event_info = crud.create_event_db(
            cursor, community_id=community_id, creator_id=current_user_id, title=title,
            description=description, location=location, event_timestamp=event_timestamp,
            max_participants=max_participants,
            image_url=minio_object_name # Pass the object NAME string or None
        )
        # ... (rest of the success path and error handling as before) ...
        if not event_info or 'id' not in event_info:
            if minio_object_name: delete_from_minio(minio_object_name);
            raise HTTPException(status_code=500, detail="Event creation failed in database")
        event_id = event_info['id']
        event_details_db = crud.get_event_details_db(cursor, event_id)
        if not event_details_db:
            conn.rollback();
            if minio_object_name: delete_from_minio(minio_object_name)
            raise HTTPException(status_code=500, detail="Could not retrieve created event details")
        conn.commit()
        response_data = dict(event_details_db)
        response_data['image_url'] = utils.get_minio_url(response_data.get('image_url'))
        print(f"✅ Event {event_id} created...")
        return schemas.EventDisplay(**response_data)

    # ... (keep existing except blocks, ensure traceback is imported if used) ...
    except psycopg2.Error as e:
        if conn: conn.rollback()
        if minio_object_name: delete_from_minio(minio_object_name)
        print(f"❌ DB Error creating event: {e}")
        detail = f"Database error: {e.pgerror}" if hasattr(e, 'pgerror') and e.pgerror else "Database error creating event"
        raise HTTPException(status_code=500, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback()
        if minio_object_name: delete_from_minio(minio_object_name)
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        if minio_object_name: delete_from_minio(minio_object_name)
        print(f"❌ Error creating event: {e}")
        traceback.print_exc() # Make sure traceback is imported
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()