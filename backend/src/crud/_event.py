# backend/src/crud/_event.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses, get_graph_counts
from .. import utils # Import root utils for quote_cypher_string

# =========================================
# Event CRUD (Relational + Graph)
# =========================================

def create_event_db(
    cursor: psycopg2.extensions.cursor, community_id: int, creator_id: int, title: str,
    description: Optional[str], location: str, event_timestamp: datetime,
    max_participants: int, image_url: Optional[str]
) -> Optional[Dict[str, Any]]: # Return dict with id and created_at
    """
    Creates event in public.events, :Event vertex, :CREATED edge (User->Event),
    and :PARTICIPATED_IN edge (Creator->Event).
    Requires CALLING function to handle transaction commit/rollback.
    Returns {'id': event_id, 'created_at': created_at} on success.
    """
    event_id = None
    # No try/except here, let caller handle transaction
    # 1. Insert into relational table
    cursor.execute(
        """
        INSERT INTO public.events (community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id, created_at;
        """,
        (community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url)
    )
    result = cursor.fetchone()
    if not result or 'id' not in result: return None # Indicate failure
    event_id = result['id']
    created_at = result['created_at']
    print(f"CRUD: Inserted event {event_id} into public.events.")

    # 2. Create :Event vertex
    # Store props useful for graph queries (id, title, maybe timestamp)
    event_props = {'id': event_id, 'title': title, 'event_timestamp': event_timestamp}
    set_clauses_str = build_cypher_set_clauses('e', event_props)
    cypher_q_vertex = f"CREATE (e:Event {{id: {event_id}}})"
    if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
    print(f"CRUD: Creating AGE vertex for event {event_id}...")
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
    print(f"CRUD: :CREATED edge created for event {event_id}.")

    # 4. Add creator as participant (:PARTICIPATED_IN edge)
    joined_at_quoted = quote_cypher_string(created_at) # Use creation time as join time
    cypher_q_participated = f"""
        MATCH (u:User {{id: {creator_id}}})
        MATCH (e:Event {{id: {event_id}}})
        MERGE (u)-[r:PARTICIPATED_IN]->(e)
        SET r.joined_at = {joined_at_quoted}
    """
    execute_cypher(cursor, cypher_q_participated)
    print(f"CRUD: Creator {creator_id} added as participant for event {event_id}.")

    return {'id': event_id, 'created_at': created_at} # Return dict on success


def get_event_by_id(cursor: psycopg2.extensions.cursor, event_id: int) -> Optional[Dict[str, Any]]:
    """ Fetches event details from relational table ONLY. """
    cursor.execute(
        """SELECT id, community_id, creator_id, title, description, location,
                  event_timestamp, max_participants, image_url, created_at
           FROM public.events WHERE id = %s""",
        (event_id,)
    )
    return cursor.fetchone()

# --- Fetch event participant count from graph ---
def get_event_participant_count(cursor: psycopg2.extensions.cursor, event_id: int) -> int:
    """ Fetches participant count for an event from AGE graph. """
    count_specs = [
        {'name': 'participant_count', 'pattern': '(p:User)-[:PARTICIPATED_IN]->(n)', 'distinct_var': 'p'}
    ]
    counts = get_graph_counts(cursor, 'Event', event_id, count_specs)
    return counts.get('participant_count', 0)

# --- Fetch event details including participant count ---
def get_event_details_db(cursor: psycopg2.extensions.cursor, event_id: int) -> Optional[Dict[str, Any]]:
    """ Fetches event details from public.events AND participant count from graph."""
    # 1. Fetch relational data
    event_relational = get_event_by_id(cursor, event_id)
    if not event_relational:
        return None

    # 2. Fetch participant count from graph
    participant_count = get_event_participant_count(cursor, event_id)

    # 3. Combine
    combined_data = dict(event_relational)
    combined_data['participant_count'] = participant_count
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
    """Creates :PARTICIPATED_IN edge in AGE graph."""
    # Need to check max_participants against current count BEFORE creating edge
    # 1. Get current participant count and max participants
    event_details = get_event_details_db(cursor, event_id) # Fetches combined data
    if not event_details:
        raise ValueError(f"Event {event_id} not found.") # Or specific exception

    current_participants = event_details.get('participant_count', 0)
    max_p = event_details.get('max_participants', 0)

    if current_participants >= max_p:
        print(f"CRUD Info: Event {event_id} is full ({current_participants}/{max_p}). Cannot join.")
        # Throw a specific exception or return a specific status
        raise ValueError("Event is full") # Let router handle this specific case

    # 2. If not full, create the edge
    now_iso = datetime.now(timezone.utc).isoformat()
    joined_at_quoted = utils.quote_cypher_string(now_iso)
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (e:Event {{id: {event_id}}})
        MERGE (u)-[r:PARTICIPATED_IN]->(e)
        SET r.joined_at = {joined_at_quoted}
    """
    # Assumes execute_cypher raises on error (e.g., if user/event nodes don't exist)
    execute_cypher(cursor, cypher_q)
    print(f"CRUD: User {user_id} joined event {event_id}.")
    return True # Indicate success

def leave_event_db(cursor: psycopg2.extensions.cursor, event_id: int, user_id: int) -> bool:
    """Deletes :PARTICIPATED_IN edge in AGE graph."""
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[r:PARTICIPATED_IN]->(e:Event {{id: {event_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
    if result_agtype is None: return False # Edge didn't exist
    result_map = utils.parse_agtype(result_agtype)
    deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
    print(f"CRUD: User {user_id} left event {event_id}. Deleted count: {deleted_count}")
    return deleted_count > 0
