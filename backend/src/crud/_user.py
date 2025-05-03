# backend/src/crud/_user.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
import bcrypt
from datetime import datetime, timezone

# Import graph helpers and quote helper from the _graph module within the same package
from ._graph import execute_cypher, build_cypher_set_clauses, get_graph_counts
from .. import utils # Import root utils for quote_cypher_string if needed
from . import _community, _event

# =========================================
# User CRUD (Relational + Graph)
# =========================================

def get_user_by_email(cursor: psycopg2.extensions.cursor, email: str) -> Optional[Dict[str, Any]]:
    """Fetches basic user data (including hash) by email from relational table."""
    cursor.execute(
        "SELECT id, username, password_hash, image_path FROM public.users WHERE email = %s",
        (email,)
    )
    return cursor.fetchone()

def get_user_by_id(cursor: psycopg2.extensions.cursor, user_id: int) -> Optional[Dict[str, Any]]:
    """Fetches user details from relational table. Counts are fetched separately."""
    cursor.execute(
        """SELECT id, name, username, email, gender, image_path,
                  current_location, current_location_address,
                  college, interest, created_at, last_seen
           FROM public.users WHERE id = %s;""",
        (user_id,)
    )
    return cursor.fetchone()

# --- Fetch user counts from graph using the helper ---
def get_user_graph_counts(cursor: psycopg2.extensions.cursor, user_id: int) -> Dict[str, int]:
    """Fetches follower and following counts from the AGE graph."""
    count_specs = [
        {'name': 'followers_count', 'pattern': '(f:User)-[:FOLLOWS]->(n)', 'distinct_var': 'f'},
        {'name': 'following_count', 'pattern': '(n)-[:FOLLOWS]->(f)', 'distinct_var': 'f'} # Corrected pattern and var
    ]
    return get_graph_counts(cursor, 'User', user_id, count_specs)


def create_user(
    cursor: psycopg2.extensions.cursor,
    name: str, username: str, email: str, password: str, gender: str,
    current_location_str: str, # Expects "(lon,lat)"
    college: str, interests_str: Optional[str], image_path: Optional[str],
    current_location_address: Optional[str]
) -> Optional[int]:
    """
    Creates a user in public.users AND a corresponding :User vertex in AGE graph.
    Requires the CALLING function to handle transaction commit/rollback.
    """
    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    user_id = None
    # No try/except here, let the caller handle DB errors for transaction management
    # 1. Insert into relational table
    cursor.execute(
        """
        INSERT INTO public.users (name, username, email, password_hash, gender, current_location, college, interest, image_path, current_location_address)
        VALUES (%s, %s, %s, %s, %s, %s::point, %s, %s, %s, %s) RETURNING id;
        """,
        (name, username, email, hashed_password, gender, current_location_str, college, interests_str, image_path, current_location_address)
    )
    result = cursor.fetchone()
    if not result or 'id' not in result:
         # Raise specific error if needed, or let potential None return be handled
         return None
    user_id = result['id']
    print(f"CRUD: Inserted user {user_id} into public.users.")

    # 2. Create vertex in AGE graph
    user_props = {
        'username': username, 'name': name, 'image_path': image_path
    }
    set_clauses_str = build_cypher_set_clauses('u', user_props)
    # Use CREATE - assumes user ID doesn't exist in graph yet
    cypher_q = f"CREATE (u:User {{id: {user_id}}})"
    if set_clauses_str:
        cypher_q += f" SET {set_clauses_str}"

    print(f"CRUD: Creating AGE vertex for user {user_id}...")
    execute_cypher(cursor, cypher_q) # Assumes execute_cypher raises on error
    print(f"CRUD: AGE vertex created for user {user_id}.")

    return user_id # Return ID on success

def update_user_profile(
    cursor: psycopg2.extensions.cursor,
    user_id: int,
    update_data: Dict[str, Any] # Contains ONLY fields to update
) -> bool:
    """
    Updates user profile in public.users AND corresponding :User vertex props.
    Requires the CALLING function to handle transaction commit/rollback.
    """
    relational_set_clauses = []
    relational_params = []
    graph_props_to_update = {}

    allowed_relational_fields = ['name', 'username', 'gender', 'current_location', 'college', 'interest', 'image_path', 'current_location_address']
    allowed_graph_props = ['username', 'name', 'image_path'] # Match props in create_user

    for key, value in update_data.items():
        if key in allowed_relational_fields:
            if key == 'current_location': relational_set_clauses.append(f"current_location = %s::point")
            else: relational_set_clauses.append(f"{key} = %s")
            relational_params.append(value)
        if key in allowed_graph_props:
            graph_props_to_update[key] = value

    rows_affected = 0
    # 1. Update Relational Table (if anything changed there)
    if relational_set_clauses:
        relational_params.append(user_id)
        relational_query = f"UPDATE public.users SET {', '.join(relational_set_clauses)} WHERE id = %s;"
        cursor.execute(relational_query, tuple(relational_params))
        rows_affected = cursor.rowcount
        print(f"CRUD: Updated public.users for user {user_id} (Rows affected: {rows_affected}).")
    else:
        # Check if user exists if only graph potentially needs update
        cursor.execute("SELECT 1 FROM public.users WHERE id = %s", (user_id,))
        if cursor.fetchone(): rows_affected = 1 # Treat as "found"
        else: print(f"CRUD Warning: User {user_id} not found for update."); return False

    # 2. Update AGE Graph Vertex (if anything changed there AND user exists)
    if graph_props_to_update and rows_affected > 0:
        set_clauses_str = build_cypher_set_clauses('u', graph_props_to_update)
        if set_clauses_str:
            cypher_q = f"MATCH (u:User {{id: {user_id}}}) SET {set_clauses_str}"
            print(f"CRUD: Updating AGE vertex for user {user_id}...")
            execute_cypher(cursor, cypher_q) # Assumes raises on error
            print(f"CRUD: AGE vertex updated for user {user_id}.")

    return rows_affected > 0 # Return True if user existed/was updated

def update_user_last_seen(cursor: psycopg2.extensions.cursor, user_id: int):
     """Updates only the last_seen timestamp in public.users."""
     # No corresponding graph update usually needed for this
     cursor.execute("UPDATE public.users SET last_seen = NOW() WHERE id = %s", (user_id,))

def delete_user(cursor: psycopg2.extensions.cursor, user_id: int) -> bool:
    """
    Deletes user from public.users AND from AGE graph.
    Requires the CALLING function to handle transaction commit/rollback.
    """
    # 1. Delete from AGE graph first using DETACH DELETE
    cypher_q = f"MATCH (u:User {{id: {user_id}}}) DETACH DELETE u"
    print(f"CRUD: Deleting AGE vertex and edges for user {user_id}...")
    execute_cypher(cursor, cypher_q) # Assumes raises on error
    print(f"CRUD: AGE vertex/edges deleted for user {user_id}.")

    # 2. Delete from relational table
    cursor.execute("DELETE FROM public.users WHERE id = %s;", (user_id,))
    rows_deleted = cursor.rowcount
    print(f"CRUD: Deleted user {user_id} from public.users (Rows affected: {rows_deleted}).")

    return rows_deleted > 0

# --- NEW Graph Query Functions for User's Relations ---

def get_user_joined_communities_graph(cursor: psycopg2.extensions.cursor, user_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    """Fetches communities (basic info) a user is a member of from AGE graph."""
    # Select properties needed by the CommunityType GQL type that are stored in the graph node
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[:MEMBER_OF]->(c:Community)
        RETURN c.id as id,
               c.name as name,
               c.interest as interest
               // Fetch logo_path if stored in graph, otherwise join needed
               // c.logo_path as logo_path
        ORDER BY c.name // Or maybe by joined_at from edge property?
        SKIP {offset}
        LIMIT {limit}
    """
    try:
        results_agtype = execute_cypher(cursor, cypher_q, fetch_all=True)
        # Results are list of maps like {'id': 1, 'name': 'x', ...}
        communities_basic_info = results_agtype if isinstance(results_agtype, list) else []

        # OPTIONAL: Augment with full details from relational table if needed
        # This adds N+1 queries but provides complete data
        # augmented_communities = []
        # for comm_basic in communities_basic_info:
        #     comm_details = _community.get_community_details_db(cursor, comm_basic['id']) # Fetch full details
        #     if comm_details:
        #         augmented_communities.append(comm_details)
        # return augmented_communities

        # Return basic info directly from graph for now
        return communities_basic_info

    except Exception as e:
        print(f"CRUD Error getting user joined communities graph for U:{user_id}: {e}")
        raise # Re-raise for transaction handling

def get_user_participated_events_graph(cursor: psycopg2.extensions.cursor, user_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    """Fetches events (basic info) a user participated in from AGE graph."""
    # Select properties needed by the EventType GQL type stored in graph node
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[:PARTICIPATED_IN]->(e:Event)
        RETURN e.id as id,
               e.title as title,
               e.event_timestamp as event_timestamp
               // Fetch other props like location, community_id if stored/needed
        ORDER BY e.event_timestamp DESC // Or by joined_at edge property?
        SKIP {offset}
        LIMIT {limit}
    """
    try:
        results_agtype = execute_cypher(cursor, cypher_q, fetch_all=True)
        events_basic_info = results_agtype if isinstance(results_agtype, list) else []

        # OPTIONAL: Augment with full details
        # augmented_events = []
        # for event_basic in events_basic_info:
        #     event_details = _event.get_event_details_db(cursor, event_basic['id'])
        #     if event_details:
        #         augmented_events.append(event_details)
        # return augmented_events

        # Return basic info for now
        return events_basic_info

    except Exception as e:
        print(f"CRUD Error getting user participated events graph for U:{user_id}: {e}")
        raise # Re-raise for transaction handling

# --- END NEW FUNCTIONS ---
# =========================================
# Follower CRUD (Graph Operations)
# =========================================

def follow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    """Creates/Updates a :FOLLOWS edge in AGE graph."""
    now_iso = datetime.now(timezone.utc).isoformat()
    created_at_quoted = utils.quote_cypher_string(now_iso)
    cypher_q = f"""
        MATCH (f:User {{id: {follower_id}}})
        MATCH (t:User {{id: {following_id}}})
        MERGE (f)-[r:FOLLOWS]->(t)
        SET r.created_at = {created_at_quoted}
    """
    try:
        execute_cypher(cursor, cypher_q)
        # MERGE doesn't easily tell us if it was created vs matched,
        # returning True indicates the relationship exists/was created.
        return True
    except Exception as e:
        print(f"CRUD Error following user ({follower_id} -> {following_id}): {e}")
        raise

def unfollow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    """Deletes a :FOLLOWS edge in AGE graph. Returns True if deleted."""
    cypher_q = f"""
        MATCH (f:User {{id: {follower_id}}})-[r:FOLLOWS]->(t:User {{id: {following_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    try:
        # Execute and fetch the count
        result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
        # If MATCH fails (no edge existed), fetch_one returns None
        if result_agtype is None:
            return False
        result_map = utils.parse_agtype(result_agtype)
        # If DELETE happened, count should be 1
        deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
        return deleted_count > 0
    except Exception as e:
        print(f"CRUD Error unfollowing user ({follower_id} -> {following_id}): {e}")
        raise

def get_followers(cursor: psycopg2.extensions.cursor, user_id: int) -> List[Dict[str, Any]]:
    """Gets followers (basic User info) from AGE graph."""
    # Select properties needed for the UserBase schema or a specific Follower schema
    cypher_q = f"""
        MATCH (follower:User)-[:FOLLOWS]->(target:User {{id: {user_id}}})
        RETURN follower.id as id,
               follower.username as username,
               follower.name as name,
               follower.image_path as image_path
               // Add other properties from :User vertex if needed by schema
        ORDER BY follower.username
    """
    try:
        results_agtype = execute_cypher(cursor, cypher_q, fetch_all=True)
        # Results are list of maps like {'id': 1, 'username': 'x', ...}
        # No further parsing needed if properties are simple types
        return results_agtype if isinstance(results_agtype, list) else []
    except Exception as e:
        print(f"CRUD Error getting followers for user {user_id}: {e}")
        raise

def get_following(cursor: psycopg2.extensions.cursor, user_id: int) -> List[Dict[str, Any]]:
    """Gets users being followed (basic User info) from AGE graph."""
    cypher_q = f"""
        MATCH (follower:User {{id: {user_id}}})-[:FOLLOWS]->(following:User)
        RETURN following.id as id,
               following.username as username,
               following.name as name,
               following.image_path as image_path
               // Add other properties from :User vertex if needed by schema
        ORDER BY following.username
    """
    try:
        results_agtype = execute_cypher(cursor, cypher_q, fetch_all=True)
        return results_agtype if isinstance(results_agtype, list) else []
    except Exception as e:
        print(f"CRUD Error getting following for user {user_id}: {e}")
        raise
