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