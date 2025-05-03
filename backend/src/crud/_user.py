# backend/src/crud/_user.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
import bcrypt
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses # Removed get_graph_counts temporarily
from .. import utils
# Import media CRUD functions
from ._media import set_user_profile_picture, get_user_profile_picture_media

# =========================================
# User CRUD (Relational + Graph + Media Link)
# =========================================

def get_user_by_email(cursor: psycopg2.extensions.cursor, email: str) -> Optional[Dict[str, Any]]:
    """Fetches basic user data (including hash and ID) by email from relational table."""
    # No change needed here unless you need profile pic media_id for login response
    cursor.execute(
        "SELECT id, username, password_hash FROM public.users WHERE email = %s",
        (email,)
    )
    return cursor.fetchone()

def get_user_by_id(cursor: psycopg2.extensions.cursor, user_id: int) -> Optional[Dict[str, Any]]:
    """Fetches user details from relational table ONLY. Avatar fetched separately."""
    # Removed image_path from SELECT
    cursor.execute(
        """SELECT id, name, username, email, gender,
                  current_location, current_location_address,
                  college, interest, created_at, last_seen
           FROM public.users WHERE id = %s;""",
        (user_id,)
    )
    return cursor.fetchone()

# --- Fetch user counts from graph (Python counting workaround) ---
def get_user_graph_counts(cursor: psycopg2.extensions.cursor, user_id: int) -> Dict[str, int]:
    """Fetches follower/following counts from the AGE graph via separate queries."""
    counts = {"followers_count": 0, "following_count": 0}
    try:
        cypher_f = f"MATCH (follower:User)-[:FOLLOWS]->(target:User {{id: {user_id}}}) RETURN follower.id"
        res_f = execute_cypher(cursor, cypher_f, fetch_all=True) or []
        counts['followers_count'] = len(res_f)
        cypher_fl = f"MATCH (follower:User {{id: {user_id}}})-[:FOLLOWS]->(following:User) RETURN following.id"
        res_fl = execute_cypher(cursor, cypher_fl, fetch_all=True) or []
        counts['following_count'] = len(res_fl)
    except Exception as e: print(f"Warning: Failed getting counts for user {user_id}: {e}")
    return counts

# --- Check follow status ---
def check_is_following(cursor: psycopg2.extensions.cursor, viewer_id: int, target_user_id: int) -> bool:
    """Checks if viewer follows target using graph."""
    cypher_q = f"MATCH (viewer:User {{id: {viewer_id}}})-[:FOLLOWS]->(target:User {{id: {target_user_id}}}) RETURN viewer.id"
    try:
        result = execute_cypher(cursor, cypher_q, fetch_one=True)
        return result is not None
    except Exception as e: print(f"Error checking follow status ({viewer_id}->{target_user_id}): {e}"); return False

# --- Create User (Relational + Graph Vertex) ---
# Note: Profile picture is handled separately after user creation by the router
def create_user(
        cursor: psycopg2.extensions.cursor,
        name: str, username: str, email: str, password: str, gender: str,
        current_location_str: str, # Expects "(lon,lat)"
        college: str, interests_str: Optional[str],
        current_location_address: Optional[str]
        # Removed image_path parameter
) -> Optional[int]:
    """
    Creates a user in public.users AND a corresponding :User vertex in AGE graph.
    Profile picture linking is handled separately.
    Requires the CALLING function to handle transaction commit/rollback.
    """
    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    user_id = None
    # 1. Insert into relational table (without image_path)
    cursor.execute(
        """
        INSERT INTO public.users (name, username, email, password_hash, gender, current_location, college, interest, current_location_address)
        VALUES (%s, %s, %s, %s, %s, %s::point, %s, %s, %s) RETURNING id;
        """,
        (name, username, email, hashed_password, gender, current_location_str, college, interests_str, current_location_address)
    )
    result = cursor.fetchone()
    if not result or 'id' not in result: return None
    user_id = result['id']
    print(f"CRUD: Inserted user {user_id} into public.users.")

    # 2. Create vertex in AGE graph (without image_path initially)
    try:
        user_props = {'id': user_id, 'username': username, 'name': name} # Minimal graph props
        set_clauses_str = build_cypher_set_clauses('u', user_props)
        cypher_q = f"CREATE (u:User {{id: {user_id}}})"
        if set_clauses_str: cypher_q += f" SET {set_clauses_str}"
        print(f"CRUD: Creating AGE vertex for user {user_id}...")
        execute_cypher(cursor, cypher_q)
        print(f"CRUD: AGE vertex created for user {user_id}.")
    except Exception as age_err:
        # Allow function to succeed relationally but log graph error clearly
        print(f"CRUD WARNING: Failed to create AGE vertex for new user {user_id}: {age_err}")
        # Do NOT raise here if you want the user created anyway

    return user_id # Return ID

# --- Update User Profile ---
def update_user_profile(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        update_data: Dict[str, Any] # Contains ONLY fields to update (excluding profile pic)
) -> bool:
    """
    Updates user profile in public.users AND corresponding :User vertex props.
    Profile picture update is handled separately via set_user_profile_picture.
    Requires the CALLING function to handle transaction commit/rollback.
    """
    relational_set_clauses = []
    relational_params = []
    graph_props_to_update = {}

    # image_path is removed, handle other fields
    allowed_relational_fields = ['name', 'username', 'gender', 'current_location', 'college', 'interest', 'current_location_address']
    allowed_graph_props = ['username', 'name'] # Only update props stored in graph node

    for key, value in update_data.items():
        if key in allowed_relational_fields:
            if key == 'current_location': relational_set_clauses.append(f"current_location = %s::point")
            else: relational_set_clauses.append(f"{key} = %s")
            relational_params.append(value)
        if key in allowed_graph_props:
            graph_props_to_update[key] = value

    rows_affected = 0
    # 1. Update Relational Table
    if relational_set_clauses:
        relational_params.append(user_id)
        sql = f"UPDATE public.users SET {', '.join(relational_set_clauses)} WHERE id = %s;"
        cursor.execute(sql, tuple(relational_params))
        rows_affected = cursor.rowcount
        print(f"CRUD: Updated public.users for user {user_id} (Rows affected: {rows_affected}).")
    else:
        # Check existence if only graph might change (or no changes provided)
        cursor.execute("SELECT 1 FROM public.users WHERE id = %s", (user_id,))
        if cursor.fetchone(): rows_affected = 1
        else: print(f"CRUD Warning: User {user_id} not found for update."); return False

    # 2. Update AGE Graph Vertex
    if graph_props_to_update and rows_affected > 0:
        set_clauses_str = build_cypher_set_clauses('u', graph_props_to_update)
        if set_clauses_str:
            cypher_q = f"MATCH (u:User {{id: {user_id}}}) SET {set_clauses_str}"
            try:
                print(f"CRUD: Updating AGE vertex for user {user_id}...")
                execute_cypher(cursor, cypher_q)
                print(f"CRUD: AGE vertex updated for user {user_id}.")
            except Exception as age_err:
                print(f"CRUD WARNING: Failed to update AGE vertex for user {user_id}: {age_err}")
                # Don't raise, allow relational update to commit

    return rows_affected > 0

# --- Update Last Seen (No change) ---
def update_user_last_seen(cursor: psycopg2.extensions.cursor, user_id: int):
    cursor.execute("UPDATE public.users SET last_seen = NOW() WHERE id = %s", (user_id,))

# --- Delete User ---
def delete_user(cursor: psycopg2.extensions.cursor, user_id: int) -> bool:
    """
    Deletes user from public.users AND from AGE graph.
    Assumes profile pic / other media links might be handled by CASCADE or router.
    Requires CALLING function to handle transaction commit/rollback.
    """
    # 1. Delete from AGE graph first
    cypher_q = f"MATCH (u:User {{id: {user_id}}}) DETACH DELETE u"
    print(f"CRUD: Deleting AGE vertex/edges for user {user_id}...")
    try:
        execute_cypher(cursor, cypher_q) # Raises error on failure
        print(f"CRUD: AGE vertex/edges deleted for user {user_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed to delete AGE vertex/edges for user {user_id}: {age_err}")
        # Decide if deletion should proceed or fail
        raise age_err # Re-raise to rollback relational delete too

    # 2. Delete from relational table
    cursor.execute("DELETE FROM public.users WHERE id = %s;", (user_id,))
    rows_deleted = cursor.rowcount
    print(f"CRUD: Deleted user {user_id} from public.users (Rows affected: {rows_deleted}).")

    return rows_deleted > 0

# --- Follower/Following Graph Operations (No change needed) ---
def follow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    # ... (keep existing graph MERGE logic) ...
    cypher_q = f"""
        MATCH (f:User {{id: {follower_id}}}) MATCH (t:User {{id: {following_id}}})
        MERGE (f)-[r:FOLLOWS]->(t)
        SET r.created_at = {utils.quote_cypher_string(datetime.now(timezone.utc))}
    """
    try: return execute_cypher(cursor, cypher_q)
    except Exception as e: print(f"CRUD Error following: {e}"); return False

def unfollow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    # ... (keep existing graph DELETE logic) ...
    cypher_q = f"MATCH (f:User {{id: {follower_id}}})-[r:FOLLOWS]->(t:User {{id: {following_id}}}) DELETE r"
    try: return execute_cypher(cursor, cypher_q)
    except Exception as e: print(f"CRUD Error unfollowing: {e}"); return False

def get_followers(cursor: psycopg2.extensions.cursor, user_id: int) -> List[Dict[str, Any]]:
    """Gets basic follower info."""
    cypher_q = f"""
        MATCH (f:User)-[:FOLLOWS]->(:User {{id: {user_id}}})
        RETURN ag_catalog.agtype_build_map(
            'id', f.id, 'username', f.username, 'name', f.name, 'image_path', f.image_path
        ) ORDER BY f.username
    """ # Explicitly return a map
    try:
        # execute_cypher now returns list of parsed maps
        results = execute_cypher(cursor, cypher_q, fetch_all=True) or []
        return [r for r in results if isinstance(r, dict)] # Filter out non-dicts just in case
    except Exception as e: print(f"Error getting followers for user {user_id}: {e}"); return []

def get_following(cursor: psycopg2.extensions.cursor, user_id: int) -> List[Dict[str, Any]]:
    """Gets basic following info."""
    cypher_q = f"""
        MATCH (:User {{id: {user_id}}})-[:FOLLOWS]->(f:User)
         RETURN ag_catalog.agtype_build_map(
            'id', f.id, 'username', f.username, 'name', f.name, 'image_path', f.image_path
        ) ORDER BY f.username
    """ # Explicitly return a map
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True) or []
        return [r for r in results if isinstance(r, dict)]
    except Exception as e: print(f"Error getting following for user {user_id}: {e}"); return

# --- User's Communities/Events (Graph Queries - Keep as is) ---
def get_user_joined_communities_graph(cursor: psycopg2.extensions.cursor, user_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    # ... (keep existing implementation using execute_cypher with expected_columns) ...
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[:MEMBER_OF]->(c:Community)
        RETURN c.id as id, c.name as name, c.interest as interest
        ORDER BY c.name SKIP {offset} LIMIT {limit}
     """
    expected_cols = [('id', 'agtype'), ('name', 'agtype'), ('interest', 'agtype')]
    try: return execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols) or []
    except Exception as e: print(f"CRUD Error getting user joined communities graph: {e}"); raise

def get_user_participated_events_graph(cursor: psycopg2.extensions.cursor, user_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    # ... (keep existing implementation using execute_cypher with expected_columns) ...
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[p:PARTICIPATED_IN]->(e:Event)
        RETURN e.id as id, e.title as title, e.event_timestamp as event_timestamp
        ORDER BY e.event_timestamp DESC SKIP {offset} LIMIT {limit}
    """
    expected_cols = [('id', 'agtype'), ('title', 'agtype'), ('event_timestamp', 'agtype')]
    try: return execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols) or []
    except Exception as e: print(f"CRUD Error getting user participated events graph: {e}"); raise

# --- User Stat Counts (Python counting - Keep as is) ---
def get_user_joined_communities_count(cursor: psycopg2.extensions.cursor, user_id: int) -> int:
    cypher_q = f"MATCH (:User {{id: {user_id}}})-[:MEMBER_OF]->(c:Community) RETURN c.id"
    try: results = execute_cypher(cursor, cypher_q, fetch_all=True); return len(results) if results else 0
    except Exception: return 0

def get_user_participated_events_count(cursor: psycopg2.extensions.cursor, user_id: int) -> int:
    cypher_q = f"MATCH (:User {{id: {user_id}}})-[:PARTICIPATED_IN]->(e:Event) RETURN e.id"
    try: results = execute_cypher(cursor, cypher_q, fetch_all=True); return len(results) if results else 0
    except Exception: return 0