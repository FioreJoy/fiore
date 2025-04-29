# backend/src/routers/users.py

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
import psycopg2
from datetime import datetime, timezone, timedelta

from .. import schemas, crud, auth
from ..database import get_db_connection
from ..utils import get_minio_url, format_location_for_db # Added format_location_for_db just in case

router = APIRouter(
    prefix="/users",
    tags=["Users"],
    dependencies=[Depends(auth.get_current_user)]
)

# --- Helper function to fetch joined communities with online count ---
def get_user_communities_with_online_count(cursor: psycopg2.extensions.cursor, user_id: int) -> List[dict]:
    """ Fetches communities joined by the user, including online member counts AND ALL fields required by CommunityDisplay. """
    ONLINE_THRESHOLD_MINUTES = 5
    online_threshold = datetime.now(timezone.utc) - timedelta(minutes=ONLINE_THRESHOLD_MINUTES)

    # --- UPDATED QUERY ---
    # Select ALL necessary fields from the communities table (c.*)
    query = """
        SELECT
            c.*, -- Select all columns from communities table
            COUNT(DISTINCT cm.user_id) AS member_count,
            COUNT(DISTINCT CASE WHEN u.last_seen >= %s THEN cm.user_id ELSE NULL END) AS online_count
        FROM communities c
        -- Join only once on community_members filtered by the current user to ensure we only get communities they are a member of
        JOIN community_members cm_user ON c.id = cm_user.community_id AND cm_user.user_id = %s
        -- Left join community_members again (aliased) to count ALL members for the filtered communities
        LEFT JOIN community_members cm ON c.id = cm.community_id
        -- Left join users to check the last_seen status for the online count
        LEFT JOIN users u ON cm.user_id = u.id
        GROUP BY c.id -- Group by primary key (includes all columns selected by c.*)
        ORDER BY c.name;
    """
    # --- END UPDATED QUERY ---

    cursor.execute(query, (online_threshold, user_id))
    communities_db = cursor.fetchall() # Fetch all results

    processed_communities = []
    for comm_row in communities_db:
        # Convert RealDictRow to a mutable dict
        comm_data = dict(comm_row)

        # Generate full logo URL
        comm_data['logo_url'] = get_minio_url(comm_row.get('logo_path'))

        # Format primary_location (which is a Point object from DB) into string if needed by schema
        # The CommunityDisplay schema expects a string for primary_location now
        location_point = comm_row.get('primary_location')
        if location_point:
            # Assuming location_point looks like Point(x=lon, y=lat) or similar string representation from RealDictCursor
            # We need to reliably convert it back to "(lon,lat)" string format.
            # psycopg2 returns it directly as a string like '(lon,lat)' when fetched with RealDictCursor usually.
            # Let's assume it's already the correct string format. If not, parsing is needed.
            comm_data['primary_location'] = str(location_point)
        else:
            comm_data['primary_location'] = '(0,0)' # Default if null

        processed_communities.append(comm_data)

    return processed_communities


@router.get("/me/communities", response_model=List[schemas.CommunityDisplay])
async def get_my_joined_communities(
        current_user_id: int = Depends(auth.get_current_user)
):
    """
    Fetches the list of communities the currently authenticated user has joined,
    including member and online counts.
    """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        communities_list = get_user_communities_with_online_count(cursor, current_user_id)
        # communities_list now contains dicts with all required fields and logo_url
        # Pydantic will validate the list against List[CommunityDisplay]
        return communities_list
    except Exception as e:
        # Log the detailed error
        import traceback
        print(f"❌ Error fetching user's communities for user {current_user_id}:")
        print(traceback.format_exc()) # Print full traceback
        raise HTTPException(status_code=500, detail=f"Failed to fetch joined communities: {e}")
    finally:
        if conn: conn.close()

# --- NEW: Function to fetch joined events ---
def get_user_events(cursor: psycopg2.extensions.cursor, user_id: int) -> List[dict]:
    """ Fetches events the user has joined, including participant counts. """
    # Query to select events where the user is a participant
    query = """
        SELECT
            e.*, -- Select all event columns
            COUNT(ep_all.user_id) as participant_count -- Count all participants for the event
        FROM events e
        JOIN event_participants ep_user ON e.id = ep_user.event_id AND ep_user.user_id = %s -- Filter for current user's participation
        LEFT JOIN event_participants ep_all ON e.id = ep_all.event_id -- Join again to count all participants
        GROUP BY e.id -- Group by event primary key
        ORDER BY e.event_timestamp DESC; -- Order by newest first, or desired order
    """
    cursor.execute(query, (user_id,))
    events_db = cursor.fetchall()

    # Process results (e.g., format timestamps if needed, handle image_url)
    # The EventDisplay schema expects image_url which is already selected by e.*
    # Timestamps should be handled by Pydantic automatically if they are datetime objects
    processed_events = [dict(event_row) for event_row in events_db]

    return processed_events


# --- NEW: Endpoint for joined events ---
@router.get("/me/events", response_model=List[schemas.EventDisplay])
async def get_my_joined_events(
        current_user_id: int = Depends(auth.get_current_user)
):
    """
    Fetches the list of events the currently authenticated user has joined.
    """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        events_list = get_user_events(cursor, current_user_id)
        # The EventDisplay schema handles the fields from the fetched dictionaries
        return events_list
    except Exception as e:
        import traceback
        print(f"❌ Error fetching user's events for user {current_user_id}:")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Failed to fetch joined events: {e}")
    finally:
        if conn: conn.close()

@router.get("/me/stats", response_model=schemas.UserStats)
async def get_user_stats(current_user_id: int = Depends(auth.get_current_user)):
    """Fetches statistics for the currently authenticated user."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Fetch communities joined
        cursor.execute("SELECT COUNT(*) FROM community_members WHERE user_id = %s;", (current_user_id,))
        communities_joined = cursor.fetchone()['count']

        # Fetch events attended
        cursor.execute("SELECT COUNT(*) FROM event_participants WHERE user_id = %s;", (current_user_id,))
        events_attended = cursor.fetchone()['count']

        # Fetch posts created
        cursor.execute("SELECT COUNT(*) FROM posts WHERE user_id = %s;", (current_user_id,))
        posts_created = cursor.fetchone()['count']

        return {
            "communities_joined": communities_joined,
            "events_attended": events_attended,
            "posts_created": posts_created
        }
    except Exception as e:
        # Log the detailed error
        import traceback
        print(f"❌ Error fetching user stats for user {current_user_id}:")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Failed to fetch user statistics")
    finally:
        if conn: conn.close()


@router.get("/{user_id}", response_model=schemas.UserDisplay)
async def get_user_profile_route(user_id: int, current_user_id: int = Depends(auth.get_current_user)): # Renamed function slightly
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Assume a simpler CRUD function 'get_raw_user_profile' exists now
        user_db = crud.get_user_profile(cursor, user_id) # Fetch raw data
        if not user_db:
            raise HTTPException(status_code=404, detail="User not found")

        # Process the raw data into the Pydantic model HERE
        user_data_dict = dict(user_db) # Convert RealDictRow to dict

        # Generate image URL
        image_path = user_data_dict.get('image_path')
        user_data_dict['image_url'] = get_minio_url(image_path)

        # Parse location
        location_str = user_data_dict.get('current_location')
        user_data_dict['current_location'] = parse_point_string(str(location_str)) if location_str else None

        # Split interests
        interests_db = user_data_dict.get('interest') # Assuming 'interest' is the comma-sep string column
        user_data_dict['interests'] = interests_db.split(',') if interests_db else []

        # Ensure counts exist, default to 0 if somehow missing from query result
        user_data_dict['followers_count'] = user_data_dict.get('followers_count', 0)
        user_data_dict['following_count'] = user_data_dict.get('following_count', 0)


        # Validate and return using the schema
        return schemas.UserDisplay(**user_data_dict)

    except Exception as e:
         print(f"Error getting profile for user {user_id}: {e}")
         # Handle specific DB errors if needed, otherwise default 500
         raise HTTPException(status_code=500, detail="Internal server error fetching profile")
    finally:
        if conn: conn.close()


# --- Revised get_followers ---
# CRUD function fix:
# def get_raw_followers(cursor, user_id: int):
#     cursor.execute("""
#         SELECT u.id, u.name, u.username, u.image_path -- Select image_path
#         FROM user_followers f
#         JOIN users u ON f.follower_id = u.id
#         WHERE f.following_id = %s
#     """, (user_id,))
#     return cursor.fetchall() # Returns list of RealDictRow

@router.get("/{user_id}/followers", response_model=List[schemas.UserBase]) # UserBase is likely okay if image_url is generated
async def get_followers_route(user_id: int, current_user_id: int = Depends(auth.get_current_user)): # Renamed function slightly
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Assume CRUD func 'get_raw_followers' returns list of dicts with image_path
        followers_db = crud.get_followers(cursor, user_id)

        processed_followers = []
        for follower_row in followers_db:
            follower_data = dict(follower_row)
            print(follower_data)

            # Generate image URL
            image_path = follower_data.get('image_path')
            follower_data['image_url'] = get_minio_url(image_path)

            # --- *** IMPORTANT: Align with UserBase *** ---
            # UserBase might expect other fields like email, gender, etc.
            # You either need a different, simpler schema (e.g., FollowerInfo)
            # OR ensure get_raw_followers selects ALL fields required by UserBase
            # OR adjust UserBase to only include id, name, username, image_path/image_url.
            # Let's assume UserBase is simple for now or you adjust the query/schema.

            # Add missing fields expected by UserBase with defaults if necessary
            # before validation. Example (adjust based on actual UserBase):
            if 'email' not in follower_data: follower_data['email'] = 'anonymous@anonymous.anonymous' # Placeholder
            if 'gender' not in follower_data: follower_data['gender'] = 'Others' # Placeholder
            if 'college' not in follower_data: follower_data['college'] = None
            if 'interest' not in follower_data: follower_data['interest'] = None
            if 'current_location' not in follower_data: follower_data['current_location'] = None


            processed_followers.append(schemas.UserBase(**follower_data)) # Validate against schema

        return processed_followers

    except Exception as e:
        print(f"Error getting followers for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error fetching followers")
    finally:
        if conn: conn.close()

# --- follow_user route (Keep as is, maybe improve error handling) ---
@router.post("/{user_id}/follow", status_code=status.HTTP_200_OK) # Use 200 OK, response indicates outcome
async def follow_user_route(user_id: int, current_user_id: int = Depends(auth.get_current_user)): # Renamed function slightly
    if user_id == current_user_id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Consider using try-except around crud call if it raises exceptions
        success = crud.follow_user(cursor, current_user_id, user_id)
        conn.commit()
        if success:
            return {"message": "User followed successfully"}
        else:
            # This means ON CONFLICT happened, or a DB error occurred and crud returned False
            # Check if the relationship exists to be sure it's "already-following"
            cursor.execute("SELECT 1 FROM user_followers WHERE follower_id = %s AND following_id = %s", (current_user_id, user_id))
            already_following = cursor.fetchone()
            if already_following:
                return {"message": "Already following this user"}
            else:
                # If not already following and crud returned False, it must have been an error
                raise HTTPException(status_code=500, detail="Failed to follow user due to an unexpected error")
    except psycopg2.Error as db_err:
         if conn: conn.rollback()
         print(f"Database error following user: {db_err}")
         # Check for specific integrity errors if needed
         raise HTTPException(status_code=500, detail="Database error processing follow request")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error in follow_user_route: {e}")
        raise HTTPException(status_code=500, detail="Could not process follow request")
    finally:
        if conn: conn.close()

# --- ADD unfollow endpoint ---
@router.delete("/{user_id}/unfollow", status_code=status.HTTP_200_OK)
async def unfollow_user_route(user_id: int, current_user_id: int = Depends(auth.get_current_user)):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Add a crud function: def unfollow_user(cursor, follower_id, following_id): ...
        # It should execute: DELETE FROM user_followers WHERE follower_id = %s AND following_id = %s
        # And return cursor.rowcount > 0
        deleted = crud.unfollow_user(cursor, current_user_id, user_id) # Create this CRUD func
        conn.commit()
        if deleted:
            return {"message": "User unfollowed successfully"}
        else:
             # Could be user wasn't following, or DB error
             # Add check if needed
             return {"message": "User was not followed"}
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error unfollowing user: {e}")
        raise HTTPException(status_code=500, detail="Could not process unfollow request")
    finally:
        if conn: conn.close()

# --- ADD get_following endpoint (similar to get_followers) ---
# @router.get("/{user_id}/following", response_model=List[schemas.UserBase])
# async def get_following_route(user_id: int, current_user_id: int = Depends(auth.get_current_user)):
#     # ... similar logic to get_followers_route, but query WHERE follower_id = user_id
#     # and join users on f.following_id = u.id
#     # Remember to process data and generate image_url
#     pass
        #if conn: conn.close()
