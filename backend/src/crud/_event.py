# backend/src/crud/_event.py
import traceback

import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses#, get_graph_counts
from .. import utils # Import root utils for quote_cypher_string

# =========================================
# Event CRUD (Relational + Graph)
# =========================================

def create_event_db(
        cursor: psycopg2.extensions.cursor, community_id: int, creator_id: int, title: str,
        description: Optional[str],
        location_address: str, # Changed from 'location' to 'location_address'
        event_timestamp: datetime,
        max_participants: int, image_url: Optional[str],
        location_coords_wkt: Optional[str] = None # New for PostGIS point
) -> Optional[Dict[str, Any]]:
    """
    Creates event in public.events, :Event vertex, :CREATED edge (User->Event),
    and :PARTICIPATED_IN edge (Creator->Event).
    Requires CALLING function to handle transaction commit/rollback.
    Returns {'id': event_id, 'created_at': created_at} on success.
    """
    event_id = None
    # 1. Insert into relational table
    # Ensure the SQL uses location_address for the text location and location_coords for geography
    sql_insert_event = """
                INSERT INTO public.events 
                    (community_id, creator_id, title, description, 
                     location, -- This is the TEXT column for the address
                     event_timestamp, max_participants, image_url, 
                     location_coords -- This is the GEOGRAPHY column
                    )
                VALUES (%s, %s, %s, %s, 
                        %s, -- for location_address
                        %s, %s, %s, 
                        CASE WHEN %s IS NOT NULL THEN ST_SetSRID(ST_GeomFromText(%s), 4326) ELSE NULL END
                       ) 
                RETURNING id, created_at;
            """
    params_insert_event = (
        community_id, creator_id, title, description,
        location_address, # Value for the 'location' TEXT column
        event_timestamp, max_participants, image_url,
        location_coords_wkt, location_coords_wkt # For the 'location_coords' GEOGRAPHY column
    )

    cursor.execute(sql_insert_event, params_insert_event)
    result = cursor.fetchone()
    if not result or 'id' not in result: return None
    event_id = result['id']
    created_at = result['created_at']
    print(f"CRUD: Inserted event {event_id} into public.events.")

    # 2. Create :Event vertex
    event_props = {'id': event_id, 'title': title, 'event_timestamp': event_timestamp}
    # If storing coordinates in graph properties as well:
    if location_coords_wkt:
        # Crude parsing of WKT POINT(lon lat) for graph properties if needed.
        # This is just for example; storing complex geometry in graph props is often not ideal.
        try:
            coords_match = re.match(r"POINT\(([-\d\.]+) ([-\d\.]+)\)", location_coords_wkt)
            if coords_match:
                event_props['longitude'] = float(coords_match.group(1))
                event_props['latitude'] = float(coords_match.group(2))
        except: # nosec
            pass # Ignore parsing errors for graph props

    set_clauses_str = build_cypher_set_clauses('e', event_props)
    cypher_q_vertex = f"CREATE (e:Event {{id: {event_id}}})"
    if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
    execute_cypher(cursor, cypher_q_vertex)
    print(f"CRUD: AGE vertex created for event {event_id}.")

    # 3. Create :CREATED edge (User -> Event)
    created_at_quoted = utils.quote_cypher_string(created_at)
    cypher_q_created = f"""
        MATCH (u:User {{id: {creator_id}}})
        MATCH (e:Event {{id: {event_id}}})
        MERGE (u)-[r:CREATED]->(e)
        SET r.created_at = {created_at_quoted}
    """
    execute_cypher(cursor, cypher_q_created)

    # 4. Add creator as participant (:PARTICIPATED_IN edge)
    joined_at_quoted = utils.quote_cypher_string(created_at)
    cypher_q_participated = f"""
        MATCH (u:User {{id: {creator_id}}})
        MATCH (e:Event {{id: {event_id}}})
        MERGE (u)-[r:PARTICIPATED_IN]->(e)
        SET r.joined_at = {joined_at_quoted}
    """
    execute_cypher(cursor, cypher_q_participated)

    return {'id': event_id, 'created_at': created_at}


def get_event_by_id(cursor: psycopg2.extensions.cursor, event_id: int) -> Optional[Dict[str, Any]]:
    """ Fetches event details from relational table ONLY. """
    cursor.execute(
        """SELECT id, community_id, creator_id, title, description, location,
                  event_timestamp, max_participants, image_url, created_at
           FROM public.events WHERE id = %s""",
        (event_id,)
    )
    return cursor.fetchone()

# --- NEW Graph Query Function ---
def get_event_participants_graph(cursor: psycopg2.extensions.cursor, event_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    """Fetches participants (basic User info) of an event from the AGE graph."""
    # Select properties needed by the UserType GQL type
    cypher_q = f"""
        MATCH (u:User)-[r:PARTICIPATED_IN]->(e:Event {{id: {event_id}}})
        RETURN u.id as id,
               u.username as username,
               u.name as name,
               u.image_path as image_path
               // Add other User vertex properties if needed by GQL type
        ORDER BY r.joined_at DESC // Order by join time (most recent first)
        SKIP {offset}
        LIMIT {limit}
    """
    try:
        results_agtype = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected)
        # Results are list of maps like {'id': 1, 'username': 'x', ...}
        return results_agtype if isinstance(results_agtype, list) else []
    except Exception as e:
        print(f"CRUD Error getting event participants graph for E:{event_id}: {e}")
        raise # Re-raise for transaction handling
# --- END NEW FUNCTION ---

# --- Fetch event participant count from graph ---
def get_event_participant_count(cursor: psycopg2.extensions.cursor, event_id: int) -> int:
    cypher_q = f"MATCH (p:User)-[:PARTICIPATED_IN]->(e:Event {{id: {event_id}}}) RETURN count(p) as p_count"
    expected = [('p_count', 'agtype')]
    try:
        result = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected)
        return int(result.get('p_count', 0)) if result else 0
    except Exception as e: print(f"Warning: Failed getting participant count for event {event_id}: {e}"); return 0

def check_is_participating(cursor: psycopg2.extensions.cursor, viewer_id: int, event_id: int) -> bool:
    """Checks if viewer is participating in event using graph."""
    cypher_q = f"MATCH (viewer:User {{id: {viewer_id}}})-[:PARTICIPATED_IN]->(event:Event {{id: {event_id}}}) RETURN viewer.id as vid"
    expected = [('vid', 'agtype')] # Defined
    try:
        # --- FIX: Add expected_columns argument ---
        result = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected)
        # --- End Fix ---
        return result is not None and result.get('vid') is not None
    except Exception as e:
        print(f"Error checking participation status (U:{viewer_id}-E:{event_id}): {e}")
        return False

# --- Fetch event details including participant count ---
def get_event_details_db(cursor: psycopg2.extensions.cursor, event_id: int) -> Optional[Dict[str, Any]]:
    # ... fetch relational data ...
    event_relational = get_event_by_id(cursor, event_id) # Use crud prefix if needed
    if not event_relational: return None
    # ... call FIXED get_event_participant_count ...
    participant_count = get_event_participant_count(cursor, event_id) # Direct call within module
    combined_data = dict(event_relational); combined_data['participant_count'] = participant_count
    return combined_data
# --- Fetch list of events for a community (combines relational + graph counts) ---
def get_events_for_community_db(cursor: psycopg2.extensions.cursor, community_id: int) -> List[Dict[str, Any]]:
    """ Fetches events list from public.events, augments with participant count from graph."""
    # 1. Fetch relational list
    cursor.execute(
        """SELECT id, community_id, creator_id, title, description, location,
                  event_timestamp, max_participants, image_url, created_at
           FROM public.events WHERE community_id = %s ORDER BY event_timestamp ASC""",
        (community_id,)
    )
    events_relational = cursor.fetchall()

    # 2. Augment with counts
    augmented_events = []
    for event_rel in events_relational:
        event_data = dict(event_rel)
        event_id = event_data['id']
        # Fetch count for this event
        try:
            # Use the dedicated count function
            event_data['participant_count'] = get_event_participant_count(cursor, event_id)
        except Exception as e:
             print(f"CRUD Warning: Failed to get graph counts for event {event_id}: {e}")
             event_data['participant_count'] = 0 # Default count on error

        augmented_events.append(event_data)

    return augmented_events


def update_event_db(
    cursor: psycopg2.extensions.cursor,
    event_id: int,
    update_data: Dict[str, Any] # Expect dict with only fields to update
) -> Optional[Dict[str, Any]]: # Return updated event details or None
    """
    Updates event in public.events AND :Event vertex properties.
    Requires CALLING function to handle transaction commit/rollback.
    """
    relational_set_clauses = []
    relational_params = []
    graph_props_to_update = {}

    allowed_relational = ['title', 'description', 'location', 'event_timestamp', 'max_participants', 'image_url']
    allowed_graph = ['title', 'event_timestamp'] # Match props stored in graph node

    for key, value in update_data.items():
        if key in allowed_relational:
            relational_set_clauses.append(f"{key} = %s")
            relational_params.append(value)
        if key in allowed_graph:
             graph_props_to_update[key] = value

    rows_affected = 0
    # 1. Update Relational Table
    if relational_set_clauses:
        relational_params.append(event_id)
        sql = f"UPDATE public.events SET {', '.join(relational_set_clauses)} WHERE id = %s;"
        cursor.execute(sql, tuple(relational_params))
        rows_affected = cursor.rowcount
        print(f"CRUD: Updated public.events for ID {event_id}.")
    else:
        cursor.execute("SELECT 1 FROM public.events WHERE id = %s", (event_id,))
        if cursor.fetchone(): rows_affected = 1
        else: print(f"CRUD Warning: Event {event_id} not found for update."); return None

    # 2. Update AGE Graph Vertex
    if graph_props_to_update and rows_affected > 0:
        set_clauses_str = build_cypher_set_clauses('e', graph_props_to_update)
        if set_clauses_str:
            cypher_q = f"MATCH (e:Event {{id: {event_id}}}) SET {set_clauses_str}"
            execute_cypher(cursor, cypher_q)
            print(f"CRUD: Updated AGE vertex for event {event_id}.")

    # Return updated details if successful
    if rows_affected > 0:
         return get_event_details_db(cursor, event_id) # Fetch combined details
    else:
         return None


def delete_event_db(cursor: psycopg2.extensions.cursor, event_id: int) -> bool:
    """
    Deletes event from public.events AND AGE graph.
    Requires CALLING function to handle transaction commit/rollback.
    """
    # 1. Delete from AGE graph using DETACH DELETE
    cypher_q = f"MATCH (e:Event {{id: {event_id}}}) DETACH DELETE e"
    print(f"CRUD: Deleting AGE vertex and edges for event {event_id}...")
    execute_cypher(cursor, cypher_q) # Assumes raises on error
    print(f"CRUD: AGE vertex/edges deleted for event {event_id}.")

    # 2. Delete from relational table
    cursor.execute("DELETE FROM public.events WHERE id = %s;", (event_id,))
    rows_deleted = cursor.rowcount
    print(f"CRUD: Deleted event {event_id} from public.events (Rows affected: {rows_deleted}).")

    return rows_deleted > 0

# --- Event Participation (Graph Operations) ---

def join_event_db(cursor: psycopg2.extensions.cursor, event_id: int, user_id: int) -> bool:
    """Creates :PARTICIPATED_IN edge, checking capacity first."""
    try:
        # 1. Check Capacity (use the combined details function)
        event_details = get_event_details_db(cursor, event_id) # Use crud. prefix
        if not event_details: raise ValueError(f"Event {event_id} not found.")
        current_participants = event_details.get('participant_count', 0)
        max_p = event_details.get('max_participants', 0)
        if current_participants >= max_p: raise ValueError("Event is full")

        # 2. Create Edge
        now_iso = datetime.now(timezone.utc).isoformat()
        joined_at_quoted = utils.quote_cypher_string(now_iso)
        cypher_q = f"""
            MATCH (u:User {{id: {user_id}}}) MATCH (e:Event {{id: {event_id}}})
            MERGE (u)-[r:PARTICIPATED_IN]->(e) SET r.joined_at = {joined_at_quoted} """
        success = execute_cypher(cursor, cypher_q)
        if success: print(f"CRUD: User {user_id} joined event {event_id}.")
        return success
    except ValueError as ve: # Catch specific errors
        print(f"CRUD Info joining event (U:{user_id}, E:{event_id}): {ve}")
        raise ve # Re-raise for router to handle specific status codes
    except Exception as e: print(f"Error joining event (U:{user_id}, E:{event_id}): {e}"); raise

def leave_event_db(cursor: psycopg2.extensions.cursor, event_id: int, user_id: int) -> bool:
    """Deletes :PARTICIPATED_IN edge."""
    # Avoid count()
    cypher_q = f"MATCH (u:User {{id: {user_id}}})-[r:PARTICIPATED_IN]->(e:Event {{id: {event_id}}}) DELETE r"
    try:
        success = execute_cypher(cursor, cypher_q)
        print(f"CRUD: User {user_id} left event {event_id}. Success: {success}")
        return success # Return status based on execute_cypher
    except Exception as e: print(f"Error leaving event (U:{user_id}, E:{event_id}): {e}"); raise

# Ensure get_event_details_db calls the fixed get_event_participant_count
def get_event_participant_ids(cursor: psycopg2.extensions.cursor, event_id: int, limit: int, offset: int) -> List[int]:
    """Fetches IDs of participants for an event, ordered by join time."""
    # Comment moved outside the Cypher string
    # Fetches join time for ordering
    cypher_q = f"""
        MATCH (u:User)-[p:PARTICIPATED_IN]->(e:Event {{id: {event_id}}})
        RETURN u.id as id, p.joined_at as joined_at
        ORDER BY p.joined_at DESC 
        SKIP {offset} LIMIT {limit}
    """
    expected_cols = [('id', 'agtype'), ('joined_at', 'agtype')]
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols) or []
        return [int(r['id']) for r in results if isinstance(r, dict) and r.get('id') is not None]
    except Exception as e:
        print(f"CRUD Error getting event participant IDs for E:{event_id}: {e}")
        # Re-raise the exception so the transaction state is handled by the caller
        raise

    # --- Spatial Query (Ensure this is present) ---
def get_nearby_events_db(
        cursor: psycopg2.extensions.cursor,
        longitude: float, latitude: float, radius_meters: int,
        limit: int, offset: int
) -> List[Dict[str, Any]]:
    """
    Fetches events within a given radius from a point.
    Includes event details and coordinates.
    The 'location' column is the text address.
    The 'location_coords' geography column is converted to lon/lat.
    """
    radius_meters_int = int(radius_meters)

    query = """
        SELECT 
            e.id, e.community_id, e.creator_id, e.title, e.description, 
            e.location, -- text address
            e.event_timestamp, e.max_participants, e.image_url, e.created_at,
            ST_X(e.location_coords::geometry) as longitude, 
            ST_Y(e.location_coords::geometry) as latitude,
            ST_Distance(e.location_coords, ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography) as distance_meters
        FROM public.events e
        WHERE e.location_coords IS NOT NULL AND ST_DWithin( -- Ensure location_coords is not null
            e.location_coords,
            ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography,
            %s -- radius in meters
        )
        AND e.event_timestamp >= NOW() -- Optionally filter for future events
        ORDER BY distance_meters ASC, e.event_timestamp ASC 
        LIMIT %s OFFSET %s;
    """
    params = (longitude, latitude, longitude, latitude, radius_meters_int, limit, offset)
    try:
        cursor.execute(query, params)
        return cursor.fetchall()
    except psycopg2.Error as db_err:
        print(f"CRUD DB Error fetching nearby events: {db_err}")
        traceback.print_exc()
        raise
    except Exception as e:
        print(f"CRUD Unexpected error fetching nearby events: {e}")
        traceback.print_exc()
        raise