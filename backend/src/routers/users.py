# backend/src/routers/users.py

from fastapi import APIRouter, Depends, HTTPException, status, Header # Added Header
from typing import List, Optional, Dict, Any # Added Dict, Any
import psycopg2
from datetime import datetime, timezone, timedelta
import jwt # For optional auth

# Use the central crud import
from .. import schemas, crud, auth, utils
from ..database import get_db_connection
from ..utils import get_minio_url, parse_point_string

router = APIRouter(
    prefix="/users",
    tags=["Users"],
    # Apply auth selectively per route if needed
    # dependencies=[Depends(auth.get_current_user)]
)



# --- GET /users/{user_id} ---
@router.get("/{user_id}", response_model=schemas.UserDisplay)
async def get_user_profile_route( # Renamed to avoid conflict with crud function name
        user_id: int,
        # Auth optional: Allows viewing public profiles, but needed for follow status
        requesting_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    """ Fetches a user's profile, including follower/following counts from graph. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Fetch relational data
        user_db = crud.get_user_by_id(cursor, user_id)
        if not user_db:
            raise HTTPException(status_code=404, detail="User not found")

        # 2. Fetch graph counts
        counts = crud.get_user_graph_counts(cursor, user_id)

        # 3. Check follow status if viewer is authenticated
        is_following = False
        if requesting_user_id is not None and requesting_user_id != user_id:
            # Query graph to see if requesting_user follows user_id
            cypher_q = f"RETURN EXISTS((:User {{id: {requesting_user_id}}})-[:FOLLOWS]->(:User {{id: {user_id}}})) as following"
            follow_res = crud.execute_cypher(cursor, cypher_q, fetch_one=True)
            follow_map = utils.parse_agtype(follow_res)
            is_following = follow_map.get('following', False) if isinstance(follow_map, dict) else False

        # 4. Combine and process data for response schema
        user_data_dict = dict(user_db)
        user_data_dict.update(counts) # Add counts
        user_data_dict['is_following'] = is_following # Add follow status (needs schema update)

        # Format fields for schema
        user_data_dict['image_url'] = utils.get_minio_url(user_data_dict.get('image_path'))
        loc_str = user_data_dict.get('current_location')
        user_data_dict['current_location'] = utils.parse_point_string(str(loc_str)) if loc_str else None
        interests_db = user_data_dict.get('interest')
        user_data_dict['interests'] = interests_db.split(',') if interests_db and interests_db.strip() else []

        # Remove fields not in UserDisplay schema if necessary (e.g., password_hash if get_user_by_id fetched it)
        # Alternatively, ensure get_user_by_id selects only needed fields

        # Validate and return
        return schemas.UserDisplay(**user_data_dict) # Add is_following to schema

    except psycopg2.Error as db_err:
        print(f"DB Error getting profile for user {user_id}: {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching profile")
    except Exception as e:
        print(f"Error getting profile for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error fetching profile")
    finally:
        if conn: conn.close()


# --- POST /users/{user_id}/follow ---
@router.post("/{user_id}/follow", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def follow_user_route( # Renamed
        user_id: int, # The user to follow
        current_user_id: int = Depends(auth.get_current_user) # The user performing the action
):
    """ Follows a user (creates graph edge). """
    if user_id == current_user_id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # crud.follow_user creates/updates the :FOLLOWS edge
        success = crud.follow_user(cursor, current_user_id, user_id)
        conn.commit()

        # Fetch updated counts for the followed user
        counts = crud.get_user_graph_counts(cursor, user_id)

        print(f"✅ User {current_user_id} followed user {user_id}. Success: {success}")
        return {
            "message": "User followed successfully",
            "success": success,
            "new_follower_count": counts.get('followers_count') # Return relevant count
        }
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        print(f"Database error following user: {db_err}")
        # Check if it failed because a user node didn't exist
        if 'MATCH (f:User' in str(db_err) or 'MATCH (t:User' in str(db_err): # Basic check
            raise HTTPException(status_code=404, detail="User not found")
        raise HTTPException(status_code=500, detail="Database error processing follow request")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error in follow_user_route: {e}")
        raise HTTPException(status_code=500, detail="Could not process follow request")
    finally:
        if conn: conn.close()


# --- DELETE /users/{user_id}/follow ---  (Changed from /unfollow for RESTful convention)
@router.delete("/{user_id}/follow", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def unfollow_user_route( # Renamed
        user_id: int, # The user to unfollow
        current_user_id: int = Depends(auth.get_current_user) # The user performing the action
):
    """ Unfollows a user (deletes graph edge). """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # crud.unfollow_user deletes the :FOLLOWS edge
        deleted = crud.unfollow_user(cursor, current_user_id, user_id)
        conn.commit()

        # Fetch updated counts for the unfollowed user
        counts = crud.get_user_graph_counts(cursor, user_id)

        print(f"✅ User {current_user_id} unfollowed user {user_id}. Deleted: {deleted}")
        return {
            "message": "User unfollowed successfully" if deleted else "You were not following this user",
            "success": deleted,
            "new_follower_count": counts.get('followers_count') # Return relevant count
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
# Need a simpler schema for follower/following lists if UserBase is too complex
@router.get("/{user_id}/followers", response_model=List[schemas.UserBase]) # Or List[schemas.FollowerInfo]
async def get_followers_route( # Renamed
        user_id: int,
        requesting_user_id: Optional[int] = Depends(auth.get_current_user_optional) # Optional auth
):
    """ Gets the list of users following the specified user_id. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # crud.get_followers fetches basic info from graph nodes
        followers_db = crud.get_followers(cursor, user_id)

        processed_followers = []
        for follower_data in followers_db:
            if not isinstance(follower_data, dict): continue # Skip if parsing failed
            # Generate image URL
            follower_data['image_url'] = utils.get_minio_url(follower_data.get('image_path'))
            # Add missing fields expected by UserBase (use defaults or fetch more data if needed)
            # This is inefficient - better to use a simpler schema like FollowerInfo(id, username, name, image_url)
            follower_data.setdefault('email', '')
            follower_data.setdefault('gender', 'PreferNotSay')
            follower_data.setdefault('college', None)
            follower_data.setdefault('interest', None)
            follower_data.setdefault('current_location', None)
            follower_data.setdefault('current_location_address', None)

            processed_followers.append(schemas.UserBase(**follower_data)) # Validate

        return processed_followers
    except Exception as e:
        print(f"Error getting followers for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error fetching followers")
    finally:
        if conn: conn.close()

# --- GET /users/{user_id}/following ---
@router.get("/{user_id}/following", response_model=List[schemas.UserBase]) # Or List[schemas.FollowerInfo]
async def get_following_route( # Renamed
        user_id: int,
        requesting_user_id: Optional[int] = Depends(auth.get_current_user_optional) # Optional auth
):
    """ Gets the list of users the specified user_id is following. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # crud.get_following fetches basic info from graph nodes
        following_db = crud.get_following(cursor, user_id)

        processed_following = []
        for following_data in following_db:
            if not isinstance(following_data, dict): continue
            following_data['image_url'] = utils.get_minio_url(following_data.get('image_path'))
            # Add missing fields for UserBase schema
            following_data.setdefault('email', '')
            following_data.setdefault('gender', 'PreferNotSay')
            following_data.setdefault('college', None)
            following_data.setdefault('interest', None)
            following_data.setdefault('current_location', None)
            following_data.setdefault('current_location_address', None)

            processed_following.append(schemas.UserBase(**following_data))

        return processed_following
    except Exception as e:
        print(f"Error getting following for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error fetching following list")
    finally:
        if conn: conn.close()

# --- GET /users/me/... endpoints (Moved to separate file/router or keep here) ---
# These were already refactored previously to use specific CRUD functions

@router.get("/me/communities", response_model=List[schemas.CommunityDisplay])
async def get_my_joined_communities(
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Fetches communities the current user has joined (uses graph). """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # This needs a new CRUD function using the graph
        # e.g., crud.get_user_joined_communities_graph(cursor, current_user_id)
        # which returns data matching CommunityDisplay structure (including counts)

        # --- Placeholder using hypothetical graph function ---
        # communities_list = crud.get_user_joined_communities_graph(cursor, current_user_id)
        # Temp implementation: Fetch all communities and check membership via graph (inefficient)
        all_communities = crud.get_communities_db(cursor) # Relational list
        joined_communities = []
        for comm_rel in all_communities:
            comm_data = dict(comm_rel)
            comm_id = comm_data['id']
            # Check membership
            cypher_q = f"RETURN EXISTS((:User {{id:{current_user_id}}})-[:MEMBER_OF]->(:Community {{id:{comm_id}}})) as joined"
            join_res = crud.execute_cypher(cursor, cypher_q, fetch_one=True)
            join_map = utils.parse_agtype(join_res)
            is_joined = join_map.get('joined', False) if isinstance(join_map, dict) else False

            if is_joined:
                # Fetch counts and augment
                counts = crud.get_community_counts(cursor, comm_id)
                comm_data.update(counts)
                loc_point_str = comm_data.get('primary_location')
                comm_data['primary_location'] = str(loc_point_str) if loc_point_str else None
                comm_data['logo_url'] = get_minio_url(comm_data.get('logo_path'))
                joined_communities.append(schemas.CommunityDisplay(**comm_data))

        return joined_communities
    except Exception as e:
        print(f"❌ Error fetching user's communities for user {current_user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch joined communities")
    finally:
        if conn: conn.close()


@router.get("/me/events", response_model=List[schemas.EventDisplay])
async def get_my_joined_events(
        current_user_id: int = Depends(auth.get_current_user)
):
    """ Fetches events the current user has joined (uses graph). """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # This needs a new CRUD function using the graph
        # e.g., crud.get_user_joined_events_graph(cursor, current_user_id)

        # --- Placeholder using hypothetical graph function ---
        # events_list = crud.get_user_joined_events_graph(cursor, current_user_id)
        # Temp implementation: Query graph for events user participated in, then fetch details
        cypher_q = f"""
           MATCH (u:User {{id: {current_user_id}}})-[:PARTICIPATED_IN]->(e:Event)
           RETURN e.id as event_id
        """
        event_id_agtypes = crud.execute_cypher(cursor, cypher_q, fetch_all=True)
        event_ids = [int(utils.parse_agtype(eid).get('event_id')) for eid in event_id_agtypes if utils.parse_agtype(eid)]

        events_list = []
        for eid in event_ids:
            event_details = crud.get_event_details_db(cursor, eid) # Fetches combined data
            if event_details:
                events_list.append(schemas.EventDisplay(**event_details))

        return events_list
    except Exception as e:
        print(f"❌ Error fetching user's events for user {current_user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch joined events")
    finally:
        if conn: conn.close()


@router.get("/me/stats", response_model=schemas.UserStats)
async def get_user_stats(current_user_id: int = Depends(auth.get_current_user)):
    """ Fetches statistics for the current user (combines graph/relational). """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Fetch graph counts (followers/following)
        graph_counts = crud.get_user_graph_counts(cursor, current_user_id)

        # Fetch communities joined count (graph)
        comm_count_spec = [{'name': 'c', 'pattern': '(n)-[:MEMBER_OF]->(c:Community)', 'distinct_var': 'c'}]
        comm_counts = crud.get_graph_counts(cursor, 'User', current_user_id, comm_count_spec)
        communities_joined = comm_counts.get('c', 0)

        # Fetch events attended count (graph)
        event_count_spec = [{'name': 'e', 'pattern': '(n)-[:PARTICIPATED_IN]->(e:Event)', 'distinct_var': 'e'}]
        event_counts = crud.get_graph_counts(cursor, 'User', current_user_id, event_count_spec)
        events_attended = event_counts.get('e', 0)

        # Fetch posts created count (relational)
        cursor.execute("SELECT COUNT(*) as count FROM public.posts WHERE user_id = %s;", (current_user_id,))
        posts_created = cursor.fetchone()['count']

        return {
            "followers_count": graph_counts.get('followers_count', 0), # Add to schema if needed
            "following_count": graph_counts.get('following_count', 0), # Add to schema if needed
            "communities_joined": communities_joined,
            "events_attended": events_attended,
            "posts_created": posts_created
        }
    except Exception as e:
        print(f"❌ Error fetching user stats for user {current_user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch user statistics")
    finally:
        if conn: conn.close()

# --- Block/Unblock Endpoints (Keep similar logic, but call graph functions if blocking becomes a graph relationship) ---
# Assuming blocking is still managed elsewhere or not yet implemented in graph