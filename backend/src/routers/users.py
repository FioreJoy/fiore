# backend/src/routers/users.py

from fastapi import APIRouter, Depends, HTTPException, status, Header
from typing import List, Optional, Dict, Any
import psycopg2
from datetime import datetime, timezone # Ensure datetime is imported if used directly
import jwt # For optional auth dependency decoding if needed

# Use the central crud import AND import specific auth functions
from .. import schemas, crud, utils, auth, database
from ..auth import get_current_user, get_current_user_optional # Specific imports for Depends
from ..database import get_db_connection
from ..utils import get_minio_url, parse_point_string

router = APIRouter(
    prefix="/users",
    tags=["Users"],
    # No global dependency here, apply per route
)

# --- GET /users/{user_id} ---
@router.get("/{user_id}", response_model=schemas.UserDisplay)
async def get_user_profile_route(
        user_id: int,
        requesting_user_id: Optional[int] = Depends(get_current_user_optional) # Use imported optional auth
):
    """ Fetches a user's profile, handling potential graph count errors. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Fetch relational data
        user_db = crud.get_user_by_id(cursor, user_id)
        if not user_db:
            raise HTTPException(status_code=404, detail="User not found")

        # 2. Fetch graph counts - Wrap in try/except
        counts = {"followers_count": 0, "following_count": 0} # Default counts
        try:
            counts = crud.get_user_graph_counts(cursor, user_id)
        except psycopg2.Error as graph_err:
            print(f"WARNING: Failed to get graph counts for user {user_id}: {graph_err}")
        except Exception as e:
            print(f"WARNING: Unexpected error getting graph counts for user {user_id}: {e}")

        # 3. Check follow status - Wrap in try/except
        is_following = False
        if requesting_user_id is not None and requesting_user_id != user_id:
            try:
                # Call the specific CRUD function
                is_following = crud.check_is_following(cursor, requesting_user_id, user_id)
            except psycopg2.Error as graph_err:
                print(f"WARNING: Failed to check follow status for {requesting_user_id}->{user_id}: {graph_err}")
            except Exception as e:
                print(f"WARNING: Unexpected error checking follow status for {requesting_user_id}->{user_id}: {e}")

        # 4. Combine and process data
        user_data_dict = dict(user_db)
        user_data_dict.update(counts)
        # Ensure the is_following key exists before assignment if schema requires it
        user_data_dict.setdefault('is_following', False)
        user_data_dict['is_following'] = is_following

        # Format fields
        user_data_dict['image_url'] = utils.get_minio_url(user_data_dict.get('image_path'))
        loc_str = user_data_dict.get('current_location')
        user_data_dict['current_location'] = utils.parse_point_string(str(loc_str)) if loc_str else None
        interests_db = user_data_dict.get('interest')
        user_data_dict['interests'] = interests_db.split(',') if interests_db and interests_db.strip() else []

        # Validate and return
        # Make sure schemas.UserDisplay has is_following field
        return schemas.UserDisplay(**user_data_dict)

    except HTTPException as http_exc:
        # Don't rollback here, connection might be closed already or error is pre-DB
        raise http_exc
    except psycopg2.Error as db_err:
        # Error likely from initial get_user_by_id
        print(f"DB Error GET /users/{user_id} (base fetch): {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching profile base")
    except Exception as e:
        print(f"Error GET /users/{user_id}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Internal server error fetching profile")
    finally:
        if conn: conn.close()


# --- POST /users/{user_id}/follow ---
@router.post("/{user_id}/follow", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def follow_user_route(
        user_id: int,
        current_user_id: int = Depends(get_current_user) # Use imported required auth
):
    if user_id == current_user_id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")

    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Check target user exists first
        target_user = crud.get_user_by_id(cursor, user_id)
        if not target_user:
            raise HTTPException(status_code=404, detail="User to follow not found")

        success = crud.follow_user(cursor, current_user_id, user_id)
        conn.commit() # Commit if crud call didn't raise error

        # Fetch updated counts for the followed user (wrap in try/except)
        counts = {"followers_count": 0, "following_count": 0}
        try:
            counts = crud.get_user_graph_counts(cursor, user_id)
        except Exception as count_err:
            print(f"WARNING: Failed to get counts after follow for user {user_id}: {count_err}")

        print(f"✅ User {current_user_id} followed user {user_id}. Success: {success}")
        return {
            "message": "User followed successfully",
            "success": success, # Reflects if MERGE executed without DB error
            "new_follower_count": counts.get('followers_count')
        }
    except HTTPException as http_exc:
        # Handle specific exceptions like 404 before generic ones
        if conn: conn.rollback()
        raise http_exc
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        print(f"Database error following user: {db_err}")
        raise HTTPException(status_code=500, detail="Database error processing follow request")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error in follow_user_route: {e}")
        raise HTTPException(status_code=500, detail="Could not process follow request")
    finally:
        if conn: conn.close()


# --- DELETE /users/{user_id}/follow ---
@router.delete("/{user_id}/follow", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def unfollow_user_route(
        user_id: int,
        current_user_id: int = Depends(get_current_user) # Use imported required auth
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        deleted = crud.unfollow_user(cursor, current_user_id, user_id)
        conn.commit() # Commit if delete attempt didn't raise error

        counts = {"followers_count": 0, "following_count": 0}
        try:
            counts = crud.get_user_graph_counts(cursor, user_id)
        except Exception as count_err:
            print(f"WARNING: Failed to get counts after unfollow for user {user_id}: {count_err}")

        print(f"✅ User {current_user_id} unfollowed user {user_id}. Deleted reported: {deleted}")
        # Report success based on 'deleted' flag from CRUD
        return {
            "message": "User unfollowed successfully" if deleted else "You were not following this user",
            "success": deleted,
            "new_follower_count": counts.get('followers_count')
        }
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        print(f"Database error unfollowing user: {db_err}")
        raise HTTPException(status_code=500, detail="Database error processing unfollow request")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error unfollowing user: {e}")
        raise HTTPException(status_code=500, detail="Could not process unfollow request")
    finally:
        if conn: conn.close()


# --- GET /users/{user_id}/followers ---
@router.get("/{user_id}/followers", response_model=List[schemas.UserBase])
async def get_followers_route(
        user_id: int,
        requesting_user_id: Optional[int] = Depends(get_current_user_optional) # Use imported optional auth
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        followers_db = crud.get_followers(cursor, user_id) # Fetches graph data
        processed_followers = []
        for follower_data in followers_db:
            if not isinstance(follower_data, dict): continue
            # Augment with necessary fields for UserBase schema
            follower_data['image_url'] = utils.get_minio_url(follower_data.get('image_path'))
            # Fetch full details if UserBase requires more than id/name/username/image
            # full_details = crud.get_user_by_id(cursor, follower_data['id']) # N+1
            # if full_details: follower_data.update(full_details)
            # Add defaults for simplicity now
            follower_data.setdefault('email', ''); follower_data.setdefault('gender', 'PreferNotSay')
            follower_data.setdefault('college', None); follower_data.setdefault('interest', None)
            follower_data.setdefault('current_location', None); follower_data.setdefault('current_location_address', None)
            processed_followers.append(schemas.UserBase(**follower_data))
        return processed_followers
    except Exception as e: print(f"Error GET /followers: {e}"); raise HTTPException(status_code=500, detail="Error fetching followers")
    finally:
        if conn: conn.close()


# --- GET /users/{user_id}/following ---
@router.get("/{user_id}/following", response_model=List[schemas.UserBase])
async def get_following_route(
        user_id: int,
        requesting_user_id: Optional[int] = Depends(get_current_user_optional) # Use imported optional auth
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        following_db = crud.get_following(cursor, user_id) # Fetches graph data
        processed_following = []
        for following_data in following_db:
            if not isinstance(following_data, dict): continue
            following_data['image_url'] = utils.get_minio_url(following_data.get('image_path'))
            # Add defaults for UserBase schema
            following_data.setdefault('email', ''); following_data.setdefault('gender', 'PreferNotSay')
            following_data.setdefault('college', None); following_data.setdefault('interest', None)
            following_data.setdefault('current_location', None); following_data.setdefault('current_location_address', None)
            processed_following.append(schemas.UserBase(**following_data))
        return processed_following
    except Exception as e: print(f"Error GET /following: {e}"); raise HTTPException(status_code=500, detail="Error fetching following list")
    finally:
        if conn: conn.close()


# --- GET /users/me/communities ---
@router.get("/me/communities", response_model=List[schemas.CommunityDisplay])
async def get_my_joined_communities(current_user_id: int = Depends(auth.get_current_user)):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        communities_basic_info = crud.get_user_joined_communities_graph(cursor, current_user_id, limit=500, offset=0)
        augmented_list = []
        for comm_basic in communities_basic_info:
            if not isinstance(comm_basic, dict) or 'id' not in comm_basic: continue
            comm_id = comm_basic['id']
            try: # Wrap the fetching of details for each community
                comm_details = crud.get_community_details_db(cursor, comm_id)
                logo_media = crud.get_community_logo_media(cursor, comm_id) # Fetch logo info

                if comm_details:
                    response_data = dict(comm_details)
                    loc = response_data.get('primary_location'); response_data['primary_location'] = str(loc) if loc else None
                    response_data['logo_url'] = logo_media.get('url') if logo_media else None # Use fetched URL
                    response_data['is_member_by_viewer'] = True
                    # Add defaults for safety before validation
                    response_data.setdefault('member_count', 0); response_data.setdefault('online_count', 0)

                    try: # Wrap pydantic validation
                        augmented_list.append(schemas.CommunityDisplay(**response_data))
                    except Exception as pydantic_err:
                        print(f"ERROR: Pydantic validation failed for comm {comm_id} in /me/communities: {pydantic_err}")
                        print(f"      Data: {response_data}")
                else:
                    print(f"Warning: Community details not found for ID {comm_id} during /me/communities fetch.")

            except Exception as detail_err:
                print(f"WARNING: Failed processing community {comm_id} in /me/communities: {detail_err}")
                # Continue to the next community

        return augmented_list
    except psycopg2.Error as db_err: # Catch DB errors from the initial graph query
        print(f"DB Error GET /me/communities for user {current_user_id}: {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching joined communities")
    except Exception as e: # Catch any other errors
        print(f"Error GET /me/communities for user {current_user_id}: {e}")
        import traceback; traceback.print_exc();
        raise HTTPException(status_code=500, detail="Failed to fetch joined communities")
    finally:
        if conn: conn.close()


# --- GET /users/me/events ---
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
            try: # Wrap detail fetching
                event_details = crud.get_event_details_db(cursor, event_id)
                if event_details:
                    response_data = dict(event_details)
                    response_data['is_participating_by_viewer'] = True
                    # Add defaults for safety
                    response_data.setdefault('participant_count', 0)
                    # Image URL is already handled by get_event_details_db (assumed)
                    response_data['image_url'] = utils.get_minio_url(response_data.get('image_url')) # Generate URL if path stored

                    try: # Wrap pydantic validation
                        events_list.append(schemas.EventDisplay(**response_data))
                    except Exception as pydantic_err:
                        print(f"ERROR: Pydantic validation failed for event {event_id} in /me/events: {pydantic_err}")
                        print(f"      Data: {response_data}")
                else:
                    print(f"Warning: Event details not found for ID {event_id} during /me/events fetch.")

            except Exception as detail_err:
                print(f"WARNING: Failed processing event {event_id} in /me/events: {detail_err}")

        return events_list
    except psycopg2.Error as db_err: # Catch DB errors from the initial graph query
        print(f"DB Error GET /me/events for user {current_user_id}: {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching joined events")
    except Exception as e: # Catch any other errors
        print(f"Error GET /me/events for user {current_user_id}: {e}")
        import traceback; traceback.print_exc();
        raise HTTPException(status_code=500, detail="Failed to fetch joined events")
    finally:
        if conn: conn.close()


# --- GET /users/me/stats ---
@router.get("/me/stats", response_model=schemas.UserStats)
async def get_user_stats(
        current_user_id: int = Depends(get_current_user) # Use imported required auth
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Call corrected CRUD functions, wrap count calls individually
        followers_count = 0
        following_count = 0
        communities_joined = 0
        events_attended = 0
        posts_created = 0

        try: graph_counts = crud.get_user_graph_counts(cursor, current_user_id); followers_count=graph_counts.get('followers_count',0); following_count=graph_counts.get('following_count',0)
        except Exception as e: print(f"Warning: Failed getting follower/following counts for stats: {e}")

        try: communities_joined = crud.get_user_joined_communities_count(cursor, current_user_id)
        except Exception as e: print(f"Warning: Failed getting joined communities count for stats: {e}")

        try: events_attended = crud.get_user_participated_events_count(cursor, current_user_id)
        except Exception as e: print(f"Warning: Failed getting participated events count for stats: {e}")

        try: cursor.execute("SELECT COUNT(*) as count FROM public.posts WHERE user_id = %s;", (current_user_id,)); posts_created = cursor.fetchone()['count']
        except Exception as e: print(f"Warning: Failed getting posts count for stats: {e}")

        # Return UserStats schema
        stats_data = {
            "communities_joined": communities_joined,
            "events_attended": events_attended,
            "posts_created": posts_created
            # Add follower/following if schema updated
            # "followers_count": followers_count,
            # "following_count": following_count,
        }
        return schemas.UserStats(**stats_data) # Validate

    except Exception as e: print(f"Error GET /me/stats: {e}"); raise HTTPException(status_code=500, detail="Failed to fetch user statistics") from e
    finally:
        if conn: conn.close()

# --- Block/Unblock Endpoints are now in routers/block.py ---