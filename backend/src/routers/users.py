# backend/src/routers/users.py

from fastapi import APIRouter, Depends, HTTPException, status, Header
from typing import List, Optional, Dict, Any
import psycopg2
from datetime import datetime, timezone
import jwt
import traceback # Added for logging

from .. import schemas, crud, utils, auth, database
from ..auth import get_current_user, get_current_user_optional
from ..database import get_db_connection
from ..utils import get_minio_url, parse_point_string # parse_point_string is key here

router = APIRouter(
    prefix="/users",
    tags=["Users"],
)

@router.get("/{user_id}", response_model=schemas.UserDisplay)
async def get_user_profile_route(
        user_id: int,
        requesting_user_id: Optional[int] = Depends(get_current_user_optional)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        user_db = crud.get_user_by_id(cursor, user_id)
        if not user_db:
            raise HTTPException(status_code=404, detail="User not found")

        user_data_dict = dict(user_db)
        counts = {"followers_count": 0, "following_count": 0}
        try: counts = crud.get_user_graph_counts(cursor, user_id)
        except Exception as e: print(f"WARNING: Failed graph counts for user {user_id}: {e}")
        user_data_dict.update(counts)

        is_following = False
        if requesting_user_id is not None and requesting_user_id != user_id:
            try: is_following = crud.check_is_following(cursor, requesting_user_id, user_id)
            except Exception as e: print(f"WARNING: Check follow status failed for {requesting_user_id}->{user_id}: {e}")
        user_data_dict['is_following'] = is_following

        # Get profile picture
        profile_media = crud.get_user_profile_picture_media(cursor, user_id)
        user_data_dict['image_url'] = profile_media.get('url') if profile_media else None
        # user_data_dict['image_path'] = profile_media.get('minio_object_name') if profile_media else None # Not needed by UserDisplay

        # Parse location string to dict
        loc_str = user_data_dict.get('current_location')
        user_data_dict['current_location'] = parse_point_string(str(loc_str)) if loc_str else None

        # Handle interests (assuming 'interest' is comma-sep and 'interests' is JSONB)
        # UserDisplay now expects 'interests' (list) not 'interest' (string)
        interests_jsonb = user_data_dict.get('interests') # This should be a list if from JSONB
        if isinstance(interests_jsonb, list):
            user_data_dict['interests'] = interests_jsonb
        elif isinstance(user_data_dict.get('interest'), str) and user_data_dict['interest'].strip():
            user_data_dict['interests'] = [i.strip() for i in user_data_dict['interest'].split(',')]
        else:
            user_data_dict['interests'] = []

        # Ensure all fields for UserDisplay are present or have defaults
        user_data_dict.setdefault('last_seen', None)

        return schemas.UserDisplay(**user_data_dict)

    except HTTPException as http_exc: raise http_exc
    except psycopg2.Error as db_err:
        print(f"DB Error GET /users/{user_id} (base fetch): {db_err}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Database error fetching profile base")
    except Exception as e:
        print(f"Error GET /users/{user_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Internal server error fetching profile")
    finally:
        if conn: conn.close()

@router.post("/{user_id}/follow", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def follow_user_route(
        user_id: int, # This is the user_id to be followed
        current_user_id: int = Depends(get_current_user) # This is the actor
):
    if user_id == current_user_id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")

    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        target_user = crud.get_user_by_id(cursor, user_id) # Check if user to follow exists
        if not target_user: raise HTTPException(status_code=404, detail="User to follow not found.")

        print(f"Router follow_user: Calling crud.follow_user for {current_user_id} -> {user_id}")
        success = crud.follow_user(cursor, follower_id=current_user_id, following_id=user_id)
        print(f"Router follow_user: crud.follow_user returned: {success}")

        if not success:
            # This might happen if MERGE failed or returned an unexpected value.
            # crud.follow_user should ideally raise on DB error.
            # If it returns False for "already following", the router should handle that.
            # For now, assume False means a general failure in the CRUD operation.
            conn.rollback() # Rollback if CRUD indicates failure but didn't raise
            raise Exception("Follow operation failed at CRUD level.")

        conn.commit()
        print(f"Router follow_user: Commit successful.")

        counts = {"followers_count": 0, "following_count": 0}
        try:
            counts = crud.get_user_graph_counts(cursor, user_id) # Counts of the user being followed
        except Exception as count_err:
            print(f"WARNING: Failed to get counts after follow for user {user_id}: {count_err}")

        print(f"✅ User {current_user_id} followed user {user_id}. Success: {success}")
        return {
            "message": "User followed successfully",
            "success": success,
            "new_follower_count": counts.get('followers_count') # Follower count of the TARGET user
        }
    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        print(f"Database error following user: {db_err}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Database error processing follow request")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error in follow_user_route: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Could not process follow request: {e}")
    finally:
        if conn: conn.close()

@router.delete("/{user_id}/follow", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def unfollow_user_route(
        user_id: int, # User to unfollow
        current_user_id: int = Depends(get_current_user)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()

        # Optional: Check if currently following before attempting to unfollow
        # is_currently_following = crud.check_is_following(cursor, current_user_id, user_id)
        # if not is_currently_following:
        #     counts = crud.get_user_graph_counts(cursor, user_id) # Counts of the user being unfollowed
        #     return {"message": "You were not following this user.", "success": True, "new_follower_count": counts.get('followers_count')}

        deleted = crud.unfollow_user(cursor, follower_id=current_user_id, following_id=user_id)
        conn.commit()

        counts = {"followers_count": 0, "following_count": 0}
        try:
            counts = crud.get_user_graph_counts(cursor, user_id) # Counts of the user being unfollowed
        except Exception as count_err:
            print(f"WARNING: Failed to get counts after unfollow for user {user_id}: {count_err}")

        print(f"✅ User {current_user_id} unfollowed user {user_id}. CRUD reported: {deleted}")
        # crud.unfollow_user might return True even if no edge was deleted (if MATCH finds nothing).
        # The message should reflect this.
        return {
            "message": "User unfollowed successfully" if deleted else "You were not following this user or unfollow failed.",
            "success": deleted, # This reflects the DB operation attempt.
            "new_follower_count": counts.get('followers_count')
        }
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        print(f"Database error unfollowing user: {db_err}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Database error processing unfollow request")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error unfollowing user: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Could not process unfollow request: {e}")
    finally:
        if conn: conn.close()

@router.get("/{user_id}/followers", response_model=List[schemas.UserBase])
async def get_followers_route(
        user_id: int,
        requesting_user_id: Optional[int] = Depends(get_current_user_optional)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # crud.get_followers now returns list of full user dicts from relational table, ordered by username
        followers_db = crud.get_followers(cursor, user_id)
        processed_followers = []
        for user_data_dict in followers_db: # user_data_dict is already a dict
            # Profile picture URL needs to be generated
            # Ensure 'id' exists before trying to fetch profile media
            current_follower_id = user_data_dict.get('id')
            if current_follower_id is None:
                print(f"WARN: Follower data missing ID: {user_data_dict}")
                continue

            profile_media = crud.get_user_profile_picture_media(cursor, current_follower_id)
            user_data_dict['image_url'] = profile_media.get('url') if profile_media else None

            loc_str = user_data_dict.get('current_location')
            user_data_dict['current_location'] = parse_point_string(str(loc_str)) if loc_str else None

            # Ensure all fields expected by UserBase are present or have defaults
            # UserBase expects 'name', 'username', 'email', 'gender'.
            # 'college', 'interest', 'image_path', 'image_url', 'current_location' are Optional.
            user_data_dict.setdefault('email', f"default_follower_{current_follower_id}@example.com") # Pydantic EmailStr needs valid format
            user_data_dict.setdefault('gender', 'Others') # Default gender
            user_data_dict.setdefault('college', None)
            user_data_dict.setdefault('interest', None)
            user_data_dict.setdefault('image_path', None) # Not in UserBase, but good to have consistent keys

            try:
                processed_followers.append(schemas.UserBase(**user_data_dict))
            except Exception as pyd_err:
                print(f"Pydantic validation error for follower ID {current_follower_id}: {pyd_err}")
                print(f"Data: {user_data_dict}")
                # Optionally skip this user or re-raise
        return processed_followers
    except Exception as e:
        print(f"Error GET /users/{user_id}/followers: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Error fetching followers")
    finally:
        if conn: conn.close()

@router.get("/{user_id}/following", response_model=List[schemas.UserBase])
async def get_following_route(
        user_id: int,
        requesting_user_id: Optional[int] = Depends(get_current_user_optional)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # crud.get_following now returns list of full user dicts from relational table
        following_db_list = crud.get_following(cursor, user_id)

        print(f"Router get_following_route: CRUD returned {len(following_db_list)} users. Data from CRUD: {following_db_list}") # Detailed log

        processed_following = []
        for user_data_from_crud in following_db_list:
            # Ensure it's a dict, as expected from RealDictCursor conversion in CRUD
            if not isinstance(user_data_from_crud, dict):
                print(f"WARN: Item from crud.get_following is not a dict: {user_data_from_crud}")
                continue

            data_dict = user_data_from_crud.copy() # Work with a copy

            current_following_id = data_dict.get('id')
            if current_following_id is None:
                print(f"WARN: Following data missing ID: {data_dict}")
                continue

            # Fetch profile picture for this user
            profile_media = crud.get_user_profile_picture_media(cursor, current_following_id)
            data_dict['image_url'] = profile_media.get('url') if profile_media else None

            # Parse location string to dict
            loc_obj_from_db = data_dict.get('current_location') # This might be a Point object or string
            data_dict['current_location'] = parse_point_string(str(loc_obj_from_db)) if loc_obj_from_db else None

            # Ensure all fields for UserBase are present or have defaults
            # UserBase requires 'name', 'username', 'email', 'gender'.
            # Others are optional or derived.
            data_dict.setdefault('name', 'Unknown Name')
            data_dict.setdefault('username', f'user{current_following_id}')
            data_dict.setdefault('email', f"default_following_{current_following_id}@example.com")
            data_dict.setdefault('gender', 'Others')
            data_dict.setdefault('college', None)
            data_dict.setdefault('interest', None) # For UserBase 'interest' text field
            # image_path is not in UserBase schema, but image_url is.

            try:
                # This is where Pydantic validation happens
                processed_following.append(schemas.UserBase(**data_dict))
            except Exception as pyd_err:
                print(f"Pydantic validation error for /following list, user ID {current_following_id}: {pyd_err}")
                print(f"Data that failed validation: {data_dict}")
                # Optionally skip this user or re-raise depending on strictness

        print(f"Router get_following_route: Processed {len(processed_following)} users to return. Processed Data: {processed_following}") # Detailed log
        return processed_following
    except Exception as e:
        print(f"Error GET /users/{user_id}/following: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Error fetching following list")
    finally:
        if conn: conn.close()

@router.get("/me/communities", response_model=List[schemas.CommunityDisplay])
async def get_my_joined_communities(current_user_id: int = Depends(auth.get_current_user)):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # This gets IDs and basic info from graph
        communities_basic_info = crud.get_user_joined_communities_graph(cursor, current_user_id, limit=500, offset=0)
        augmented_list = []
        for comm_basic in communities_basic_info:
            if not isinstance(comm_basic, dict) or 'id' not in comm_basic: continue
            comm_id = comm_basic['id']
            try:
                # Fetch full details (includes counts) and logo for each
                comm_details = crud.get_community_details_db(cursor, comm_id)
                logo_media = crud.get_community_logo_media(cursor, comm_id)

                if comm_details:
                    response_data = dict(comm_details)
                    loc = response_data.get('primary_location'); response_data['primary_location'] = str(loc) if loc else None
                    response_data['logo_url'] = logo_media.get('url') if logo_media else None
                    response_data['is_member_by_viewer'] = True # User is member
                    response_data.setdefault('member_count', 0); response_data.setdefault('online_count', 0)
                    augmented_list.append(schemas.CommunityDisplay(**response_data))
                else:
                    print(f"Warning: Community details not found for ID {comm_id} in /me/communities.")
            except Exception as detail_err:
                print(f"WARNING: Failed processing community {comm_id} in /me/communities: {detail_err}")
        return augmented_list
    except psycopg2.Error as db_err:
        print(f"DB Error GET /me/communities for user {current_user_id}: {db_err}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Database error fetching joined communities")
    except Exception as e:
        print(f"Error GET /me/communities for user {current_user_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Failed to fetch joined communities")
    finally:
        if conn: conn.close()

@router.get("/me/events", response_model=List[schemas.EventDisplay])
async def get_my_joined_events(current_user_id: int = Depends(auth.get_current_user)):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        events_basic_info = crud.get_user_participated_events_graph(cursor, current_user_id, limit=500, offset=0)
        events_list = []
        for event_basic in events_basic_info:
            if not isinstance(event_basic, dict) or 'id' not in event_basic: continue
            event_id = event_basic['id']
            try:
                event_details = crud.get_event_details_db(cursor, event_id) # Includes participant_count
                if event_details:
                    response_data = dict(event_details)
                    response_data['is_participating_by_viewer'] = True # User is participant
                    response_data.setdefault('participant_count', 0)
                    # get_event_details_db stores object name in 'image_url', convert it
                    response_data['image_url'] = utils.get_minio_url(response_data.get('image_url'))
                    events_list.append(schemas.EventDisplay(**response_data))
                else:
                    print(f"Warning: Event details not found for ID {event_id} in /me/events.")
            except Exception as detail_err:
                print(f"WARNING: Failed processing event {event_id} in /me/events: {detail_err}")
        return events_list
    except psycopg2.Error as db_err:
        print(f"DB Error GET /me/events for user {current_user_id}: {db_err}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Database error fetching joined events")
    except Exception as e:
        print(f"Error GET /me/events for user {current_user_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Failed to fetch joined events")
    finally:
        if conn: conn.close()

@router.get("/me/stats", response_model=schemas.UserStats)
async def get_user_stats(current_user_id: int = Depends(get_current_user)):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        communities_joined = 0; events_attended = 0; posts_created = 0
        try: communities_joined = crud.get_user_joined_communities_count(cursor, current_user_id)
        except Exception as e: print(f"Warning: Failed getting joined communities count for stats: {e}")
        try: events_attended = crud.get_user_participated_events_count(cursor, current_user_id)
        except Exception as e: print(f"Warning: Failed getting participated events count for stats: {e}")
        try:
            cursor.execute("SELECT COUNT(*) as count FROM public.posts WHERE user_id = %s;", (current_user_id,))
            posts_created_result = cursor.fetchone()
            posts_created = posts_created_result['count'] if posts_created_result else 0
        except Exception as e: print(f"Warning: Failed getting posts count for stats: {e}")

        stats_data = {
            "communities_joined": communities_joined,
            "events_attended": events_attended,
            "posts_created": posts_created
        }
        return schemas.UserStats(**stats_data)
    except Exception as e:
        print(f"Error GET /me/stats: {e}"); traceback.print_exc()
        raise HTTPException(status_code=500, detail="Failed to fetch user statistics") from e
    finally:
        if conn: conn.close()