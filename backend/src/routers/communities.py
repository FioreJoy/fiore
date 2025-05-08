# backend/src/routers/communities.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File, Query
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
        current_user_id: int = Depends(auth.get_current_user),
        name: str = Form(...),
        description: Optional[str] = Form(None),
        interest: Optional[str] = Form(None),
        logo: Optional[UploadFile] = File(None),
        # New location fields
        location_address: Optional[str] = Form(None),
        latitude: Optional[float] = Form(None),
        longitude: Optional[float] = Form(None)
):
    conn = None
    community_id = None
    upload_result_dict: Optional[Dict[str, Any]] = None
    created_media_id: Optional[int] = None
    location_coords_wkt: Optional[str] = None

    if latitude is not None and longitude is not None:
        location_coords_wkt = f"POINT({longitude} {latitude})"
    elif latitude is not None or longitude is not None:
        raise HTTPException(status_code=422, detail="Both latitude and longitude must be provided if one is set.")

    try:
        if logo and utils.minio_client:
            safe_name = name.replace(' ', '_').lower()
            safe_name = ''.join(c for c in safe_name if c.isalnum() or c in ['_','-']) or f"comm_{uuid.uuid4()}"
            object_name_prefix = f"communities/{safe_name}/logo"
            upload_result_dict = await utils.upload_file_to_minio(logo, object_name_prefix)
            if upload_result_dict is None or 'minio_object_name' not in upload_result_dict:
                print(f"⚠️ Warning: MinIO community logo upload failed for {name}. Proceeding without logo.")
                upload_result_dict = None

        conn = get_db_connection(); cursor = conn.cursor()
        community_id = crud.create_community_db(
            cursor, name=name, description=description, created_by=current_user_id,
            interest=interest,
            location_address=location_address,
            location_coords_wkt=location_coords_wkt
        )
        if community_id is None:
            if upload_result_dict and 'minio_object_name' in upload_result_dict:
                delete_from_minio(upload_result_dict['minio_object_name'])
            raise HTTPException(status_code=500, detail="Community base creation failed in database")

        if upload_result_dict and 'minio_object_name' in upload_result_dict:
            created_media_id = crud.create_media_item(
                cursor, uploader_user_id=current_user_id, **upload_result_dict
            )
            if created_media_id:
                crud.set_community_logo(cursor, community_id, created_media_id)
            else:
                print(f"WARN CreateCommunity: Failed to create media record for logo {upload_result_dict['minio_object_name']}")
                delete_from_minio(upload_result_dict['minio_object_name'])
                created_media_id = None

        created_community_db = crud.get_community_details_db(cursor, community_id)
        if not created_community_db:
            conn.rollback()
            if upload_result_dict and 'minio_object_name' in upload_result_dict:
                delete_from_minio(upload_result_dict['minio_object_name'])
            raise HTTPException(status_code=500, detail="Could not retrieve created community details after creation")

        logo_media_for_response = None
        if created_media_id:
            logo_media_for_response = crud.get_media_item_by_id(cursor, created_media_id)
        conn.commit()

        response_data = dict(created_community_db)
        # Convert raw lon/lat from DB (if present) to LocationDataOutput for response
        if response_data.get('longitude') is not None and response_data.get('latitude') is not None:
            response_data['location'] = schemas.LocationDataOutput(
                longitude=response_data['longitude'],
                latitude=response_data['latitude'],
                address=response_data.get('location_address')
            )
        elif 'longitude' in response_data: # Clean up if they were fetched as None
            del response_data['longitude']
            del response_data['latitude']

        response_data['logo_url'] = utils.get_minio_url(logo_media_for_response.get('minio_object_name')) if logo_media_for_response else None
        response_data.setdefault('is_member_by_viewer', True)

        print(f"✅ Community '{name}' (ID: {community_id}) created by User {current_user_id}")
        return schemas.CommunityDisplay(**response_data)

    except psycopg2.IntegrityError as e:
        if conn: conn.rollback()
        if upload_result_dict and 'minio_object_name' in upload_result_dict: delete_from_minio(upload_result_dict['minio_object_name'])
        print(f"❌ Community Creation Integrity Error: {e}")
        detail="Community name may already exist or invalid data provided."
        if hasattr(e, 'diag') and e.diag.constraint_name == 'communities_name_key': detail = "Community name already taken."
        elif hasattr(e, 'pgcode') and e.pgcode == '23503': detail = "Invalid creator user or other foreign key."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback()
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


@router.get("/{community_id}/details", response_model=schemas.CommunityDisplay)
async def get_community_details(
        community_id: int,
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        community_db = crud.get_community_details_db(cursor, community_id)
        if not community_db:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")

        response_data = dict(community_db)

        # Convert raw lon/lat from DB to LocationDataOutput for response
        if response_data.get('longitude') is not None and response_data.get('latitude') is not None:
            response_data['location'] = schemas.LocationDataOutput(
                longitude=response_data['longitude'],
                latitude=response_data['latitude'],
                address=response_data.get('location_address')
            )
        elif 'longitude' in response_data:
            del response_data['longitude']
            del response_data['latitude']

        logo_media = crud.get_community_logo_media(cursor, community_id)
        response_data['logo_url'] = logo_media.get('url') if logo_media else None

        response_data.setdefault('member_count', 0); response_data.setdefault('online_count', 0)
        response_data.setdefault('is_member_by_viewer', False)
        if current_user_id:
            try: response_data['is_member_by_viewer'] = crud.check_is_member(cursor, current_user_id, community_id)
            except Exception as e: print(f"WARN GET /details C:{community_id}: Check member failed: {e}")

        return schemas.CommunityDisplay(**response_data)
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        print(f"❌ Error fetching community details {community_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Error fetching community details")
    finally:
        if conn: conn.close()


@router.put("/{community_id}", response_model=schemas.CommunityDisplay)
async def update_community_details(
        community_id: int,
        # Use Form data for PUT to match create and logo update
        name: Optional[str] = Form(None),
        description: Optional[str] = Form(None),
        interest: Optional[str] = Form(None),
        location_address: Optional[str] = Form(None),
        latitude: Optional[float] = Form(None),
        longitude: Optional[float] = Form(None),
        current_user_id: int = Depends(auth.get_current_user)
):
    conn = None
    update_dict = {}
    if name is not None: update_dict['name'] = name
    if description is not None: update_dict['description'] = description # Allow empty string to clear
    if interest is not None: update_dict['interest'] = interest
    if location_address is not None: update_dict['location_address'] = location_address

    if latitude is not None and longitude is not None:
        update_dict['location_coords_wkt'] = f"POINT({longitude} {latitude})"
    elif latitude is not None or longitude is not None:
        raise HTTPException(status_code=422, detail="Both latitude and longitude must be provided if one is set for coordinate update.")


    if not update_dict:
        raise HTTPException(status_code=400, detail="No update data provided")

    try:
        conn = get_db_connection(); cursor = conn.cursor()
        community = crud.get_community_by_id(cursor, community_id)
        if not community:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")
        if community['created_by'] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to update this community")

        updated = crud.update_community_details_db(cursor, community_id, update_dict)
        if not updated:
            conn.rollback()
            raise HTTPException(status_code=500, detail="Failed to update community in database")
        conn.commit()

        updated_community_db = crud.get_community_details_db(cursor, community_id)
        if not updated_community_db:
            raise HTTPException(status_code=500, detail="Could not retrieve updated community details")

        response_data = dict(updated_community_db)
        if response_data.get('longitude') is not None and response_data.get('latitude') is not None:
            response_data['location'] = schemas.LocationDataOutput(
                longitude=response_data['longitude'],
                latitude=response_data['latitude'],
                address=response_data.get('location_address')
            )
        elif 'longitude' in response_data:
            del response_data['longitude']
            del response_data['latitude']

        logo_media = crud.get_community_logo_media(cursor, community_id) # Fetch current logo
        response_data['logo_url'] = logo_media.get('url') if logo_media else None

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
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Could not update community details")
    finally:
        if conn: conn.close()


@router.get("", response_model=List[schemas.CommunityDisplay])
async def get_communities(
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional),
        limit: int = Query(50, ge=1, le=200), # Added limit/offset
        offset: int = Query(0, ge=0)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        communities_relational = crud.get_communities_db(cursor, limit=limit, offset=offset)
        processed_communities = []
        for comm_rel_dict in communities_relational:
            comm_data = dict(comm_rel_dict) # Ensure it's a mutable dict
            comm_id = comm_data['id']

            counts = crud.get_community_counts(cursor, comm_id)
            comm_data.update(counts)

            logo_media = crud.get_community_logo_media(cursor, comm_id)
            comm_data['logo_url'] = logo_media.get('url') if logo_media else None

            if comm_data.get('longitude') is not None and comm_data.get('latitude') is not None:
                comm_data['location'] = schemas.LocationDataOutput(
                    longitude=comm_data['longitude'],
                    latitude=comm_data['latitude'],
                    address=comm_data.get('location_address')
                )
            elif 'longitude' in comm_data:
                del comm_data['longitude']
                del comm_data['latitude']

            if current_user_id:
                comm_data['is_member_by_viewer'] = crud.check_is_member(cursor, current_user_id, comm_id)
            else:
                comm_data['is_member_by_viewer'] = False

            processed_communities.append(schemas.CommunityDisplay(**comm_data))

        return processed_communities
    except Exception as e:
        print(f"❌ Error fetching communities: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Error fetching communities")
    finally:
        if conn: conn.close()

@router.get("/trending", response_model=List[schemas.CommunityDisplay])
async def get_trending_communities(
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional),
        limit: int = Query(15, ge=1, le=50) # Added limit
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        communities_db = crud.get_trending_communities_db(cursor, limit=limit)
        processed_communities = []
        for comm_dict_db in communities_db:
            comm_data = dict(comm_dict_db)
            comm_id = comm_data['id']

            counts = crud.get_community_counts(cursor, comm_id) # Get member/online from graph
            comm_data.update(counts)

            logo_media = crud.get_community_logo_media(cursor, comm_id)
            comm_data['logo_url'] = logo_media.get('url') if logo_media else None

            if comm_data.get('longitude') is not None and comm_data.get('latitude') is not None:
                comm_data['location'] = schemas.LocationDataOutput(
                    longitude=comm_data['longitude'],
                    latitude=comm_data['latitude'],
                    address=comm_data.get('location_address')
                )
            elif 'longitude' in comm_data:
                del comm_data['longitude']
                del comm_data['latitude']

            if current_user_id:
                comm_data['is_member_by_viewer'] = crud.check_is_member(cursor, current_user_id, comm_id)
            else:
                comm_data['is_member_by_viewer'] = False

            processed_communities.append(schemas.CommunityDisplay(**comm_data))
        return processed_communities
    except Exception as e:
        print(f"❌ Error fetching trending communities: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Error fetching trending communities")
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
        title: str = Form(...),
        description: Optional[str] = Form(None),
        location: str = Form(...), # This is the address string
        event_timestamp: datetime = Form(...),
        max_participants: int = Form(100),
        image: Optional[UploadFile] = File(None),
        # New form fields for coordinates (optional for now)
        latitude: Optional[float] = Form(None),
        longitude: Optional[float] = Form(None),
):
    """ Creates a new event within a community. Notifies community members. """
    conn = None
    minio_object_name = None
    event_id = None
    upload_info = None
    community_db_info = None # To store fetched community details

    try:
        object_name_prefix = f"media/events/unknown_community/{uuid.uuid4()}"

        conn = get_db_connection(); cursor = conn.cursor()

        # Validate community
        community_db_info = crud.get_community_by_id(cursor, community_id)
        if not community_db_info:
            raise HTTPException(status_code=404, detail=f"Community {community_id} not found.")
        community_name_for_path = community_db_info.get('name', f'c_{community_id}')
        safe_community_name = community_name_for_path.replace(' ', '_').lower()
        safe_community_name = ''.join(c for c in safe_community_name if c.isalnum() or c in ['_','-'])
        object_name_prefix = f"media/communities/{safe_community_name}/events"

        if image and utils.minio_client:
            upload_info = await utils.upload_file_to_minio(image, object_name_prefix)
            if upload_info and 'minio_object_name' in upload_info:
                minio_object_name = upload_info['minio_object_name']
            else:
                print(f"⚠️ Event image upload failed for event in community {community_id}")
                minio_object_name = None

        # Prepare event data, including optional PostGIS point
        event_point_wkt = None
        if latitude is not None and longitude is not None:
            event_point_wkt = f"POINT({longitude} {latitude})"


        # Create Event in DB (CRUD needs to handle event_point_wkt for location_coords)
        # crud.create_event_db now expects location_coords_wkt parameter
        event_info_dict = crud.create_event_db(
            cursor, community_id=community_id, creator_id=current_user_id, title=title,
            description=description, location_address=location, # Corrected parameter name
            event_timestamp=event_timestamp,
            max_participants=max_participants,
            image_url=minio_object_name,
            location_coords_wkt=event_point_wkt
        )

        if not event_info_dict or 'id' not in event_info_dict:
            if minio_object_name: delete_from_minio(minio_object_name);
            raise HTTPException(status_code=500, detail="Event creation failed in database")

        event_id = event_info_dict['id']

        # --- Notify Community Members ---
        # CAVEAT: This can be slow for large communities. Consider async fan-out.
        community_member_ids = crud.get_community_member_ids(cursor, community_id, limit=10000, offset=0)
        if community_member_ids: # Check if there are members to notify
            community_name_for_notif = community_db_info.get('name', 'your community')
            content_preview = f"New event in {community_name_for_notif}: \"{title[:50]}...\""
            print(f"Attempting to notify {len(community_member_ids)} members of community {community_id} about new event {event_id}")
            for member_id in community_member_ids:
                if member_id != current_user_id:
                    crud.create_notification(
                        cursor=cursor,
                        recipient_user_id=member_id,
                        actor_user_id=current_user_id,
                        type='new_community_event', # <-- USE THE CORRECT ENUM VALUE
                        related_entity_type='event',
                        related_entity_id=event_id,
                        content_preview=content_preview
                    )
        # --- End Notify Community Members ---

        event_details_db = crud.get_event_details_db(cursor, event_id)
        if not event_details_db:
            conn.rollback();
            if minio_object_name: delete_from_minio(minio_object_name)
            raise HTTPException(status_code=500, detail="Could not retrieve created event details")

        conn.commit() # Commit event creation and notifications

        response_data = dict(event_details_db)
        response_data['image_url'] = utils.get_minio_url(response_data.get('image_url'))

        # Handle location_coords for output, it should be a dict if present
        if response_data.get('longitude') is not None and response_data.get('latitude') is not None:
            response_data['location_coords'] = {
                "longitude": response_data['longitude'],
                "latitude": response_data['latitude']
            }
        elif 'longitude' in response_data: # Clean up if they were None but present
            del response_data['longitude']
            del response_data['latitude']

        print(f"✅ Event {event_id} created in community {community_id}")
        return schemas.EventDisplay(**response_data)

    except psycopg2.Error as e:
        if conn: conn.rollback()
        if minio_object_name: delete_from_minio(minio_object_name)
        print(f"❌ DB Error creating event in community {community_id}: {e}")
        detail = f"Database error: {e.pgerror}" if hasattr(e, 'pgerror') and e.pgerror else "Database error creating event"
        raise HTTPException(status_code=500, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback()
        if minio_object_name: delete_from_minio(minio_object_name)
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        if minio_object_name: delete_from_minio(minio_object_name)
        print(f"❌ Error creating event in community {community_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()