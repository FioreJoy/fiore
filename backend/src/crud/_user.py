# backend/src/crud/_user.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
import bcrypt
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses
from .. import utils
# Import media CRUD functions
from ._media import set_user_profile_picture, get_user_profile_picture_media

# =========================================
# User CRUD (Relational + Graph + Media Link)
# =========================================

def get_user_by_email(cursor: psycopg2.extensions.cursor, email: str) -> Optional[Dict[str, Any]]:
    """Fetches basic user data (including hash and ID) by email from relational table."""
    cursor.execute(
        "SELECT id, username, password_hash FROM public.users WHERE email = %s",
        (email,)
    )
    return cursor.fetchone()

def get_user_by_id(cursor: psycopg2.extensions.cursor, user_id: int) -> Optional[Dict[str, Any]]:
    """Fetches user details from relational table ONLY. Avatar fetched separately."""
    cursor.execute(
        """SELECT id, name, username, email, gender,
                  current_location, current_location_address,
                  college, interest, created_at, last_seen
           FROM public.users WHERE id = %s;""",
        (user_id,)
    )
    return cursor.fetchone()

def create_user(
        cursor: psycopg2.extensions.cursor,
        name: str, username: str, email: str, password: str, gender: str,
        current_location_str: str, # Expects "(lon,lat)"
        college: str, interests_str: Optional[str],
        current_location_address: Optional[str]
) -> Optional[int]:
    """
    Creates a user in public.users AND a corresponding :User vertex in AGE graph.
    Profile picture linking is handled separately.
    Requires the CALLING function to handle transaction commit/rollback.
    """
    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    user_id = None
    # 1. Insert into relational table
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

    # 2. Create vertex in AGE graph
    try:
        user_props = {'id': user_id, 'username': username, 'name': name} # Minimal graph props
        set_clauses_str = build_cypher_set_clauses('u', user_props)
        cypher_q = f"CREATE (u:User {{id: {user_id}}})"
        if set_clauses_str: cypher_q += f" SET {set_clauses_str}"
        print(f"CRUD: Creating AGE vertex for user {user_id}...")
        execute_cypher(cursor, cypher_q) # No expected_columns needed for CREATE
        print(f"CRUD: AGE vertex created for user {user_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed to create AGE vertex for new user {user_id}: {age_err}")
        # Decide: raise age_err # Or let it pass

    return user_id

def update_user_profile(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        update_data: Dict[str, Any]
) -> bool:
    """
    Updates user profile in public.users AND corresponding :User vertex props.
    Requires the CALLING function to handle transaction commit/rollback.
    """
    relational_set_clauses = []
    relational_params = []
    graph_props_to_update = {}
    allowed_relational_fields = ['name', 'username', 'gender', 'current_location', 'college', 'interest', 'current_location_address']
    allowed_graph_props = ['username', 'name']

    for key, value in update_data.items():
        if key in allowed_relational_fields:
            clause = f"{key} = %s::point" if key == 'current_location' else f"{key} = %s"
            relational_set_clauses.append(clause)
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
    else: # Check existence if only graph might change
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
                execute_cypher(cursor, cypher_q) # No expected_columns needed for SET
                print(f"CRUD: AGE vertex updated for user {user_id}.")
            except Exception as age_err:
                print(f"CRUD WARNING: Failed to update AGE vertex for user {user_id}: {age_err}")
                # Allow relational update to commit

    return rows_affected > 0

def update_user_last_seen(cursor: psycopg2.extensions.cursor, user_id: int):
    """Updates only the last_seen timestamp."""
    try:
        cursor.execute("UPDATE public.users SET last_seen = NOW() WHERE id = %s", (user_id,))
    except Exception as e:
        print(f"CRUD Warning: Failed to update last_seen for user {user_id}: {e}")


def delete_user(cursor: psycopg2.extensions.cursor, user_id: int) -> bool:
    """
    Deletes user from public.users AND from AGE graph.
    Requires CALLING function to handle transaction commit/rollback.
    """
    # 1. Delete from AGE graph first
    cypher_q = f"MATCH (u:User {{id: {user_id}}}) DETACH DELETE u"
    print(f"CRUD: Deleting AGE vertex/edges for user {user_id}...")
    try:
        execute_cypher(cursor, cypher_q) # No expected_columns needed for DELETE
        print(f"CRUD: AGE vertex/edges deleted for user {user_id}.")
    except Exception as age_err:
        print(f"CRUD ERROR: Failed to delete AGE vertex/edges for user {user_id}: {age_err}")
        raise age_err # Re-raise to rollback relational delete too

    # 2. Delete from relational table
    cursor.execute("DELETE FROM public.users WHERE id = %s;", (user_id,))
    rows_deleted = cursor.rowcount
    print(f"CRUD: Deleted user {user_id} from public.users (Rows affected: {rows_deleted}).")

    return rows_deleted > 0

# --- Follower/Following Graph Operations ---

def get_user_graph_counts(cursor: psycopg2.extensions.cursor, user_id: int) -> Dict[str, int]:
    """Fetches follower/following counts using graph."""
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})
        OPTIONAL MATCH (follower:User)-[:FOLLOWS]->(u)
        OPTIONAL MATCH (u)-[:FOLLOWS]->(following:User)
        RETURN count(DISTINCT follower) as followers_count, count(DISTINCT following) as following_count
    """
    expected = [('followers_count', 'int8'), ('following_count', 'int8')] # Explicitly expect bigint/int8 for counts
    try:
        result_map = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected)
        if isinstance(result_map, dict):
            # Values should already be parsed as integers by execute_cypher
            return {
                "followers_count": result_map.get('followers_count', 0) or 0,
                "following_count": result_map.get('following_count', 0) or 0
            }
        else: return {"followers_count": 0, "following_count": 0}
    except Exception as e:
        print(f"Warning: Failed getting counts for user {user_id}: {e}")
        return {"followers_count": 0, "following_count": 0}

# --- ADDED follow_user ---
def follow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    """Creates/updates a :FOLLOWS relationship in the graph."""
    cypher_q = f"""
        MATCH (f:User {{id: {follower_id}}})
        MATCH (t:User {{id: {following_id}}})
        MERGE (f)-[r:FOLLOWS]->(t)
        SET r.created_at = {utils.quote_cypher_string(datetime.now(timezone.utc))}
    """
    try:
        execute_cypher(cursor, cypher_q) # No expected_columns needed for MERGE/SET
        return True # Assume success if no error
    except Exception as e:
        print(f"CRUD Error following user ({follower_id} -> {following_id}): {e}")
        raise # Re-raise for transaction handling

# --- ADDED unfollow_user ---
def unfollow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    """Deletes a :FOLLOWS relationship from the graph."""
    # Note: DELETE does not return anything meaningful by default in AGE cypher() context
    # We cannot easily check if a relationship *was* deleted vs didn't exist.
    # We assume the operation succeeded if no error is raised.
    cypher_q = f"""
        MATCH (f:User {{id: {follower_id}}})-[r:FOLLOWS]->(t:User {{id: {following_id}}})
        DELETE r
    """
    # If we needed to confirm deletion, we might need a pre-check MATCH first within the same transaction.
    try:
        execute_cypher(cursor, cypher_q) # No expected_columns needed for DELETE
        return True # Assume success
    except Exception as e:
        # This might error if the MATCH fails (relationship doesn't exist)
        # Or if DELETE fails for other reasons.
        print(f"CRUD Error unfollowing user ({follower_id} -> {following_id}): {e}")
        # Depending on desired behavior, you might return False if MATCH fails, or raise otherwise.
        # For now, re-raise to indicate potential issue.
        raise

def check_is_following(cursor: psycopg2.extensions.cursor, viewer_id: int, target_user_id: int) -> bool:
    """Checks if viewer follows target using graph."""
    cypher_q = f"MATCH (viewer:User {{id: {viewer_id}}})-[:FOLLOWS]->(target:User {{id: {target_user_id}}}) RETURN viewer.id as vid"
    expected = [('vid', 'agtype')]
    try:
        result = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected)
        return result is not None and result.get('vid') is not None
    except Exception as e:
        print(f"Error checking follow status ({viewer_id}->{target_user_id}): {e}")
        return False

def get_followers(cursor: psycopg2.extensions.cursor, user_id: int) -> List[Dict[str, Any]]:
    cypher_q = f"MATCH (f:User)-[:FOLLOWS]->(:User {{id: {user_id}}}) RETURN f ORDER BY f.username"
    # Now requires expected_columns because fetch_all=True and we need to tell execute_cypher what 'f' returns
    # Since 'f' is a node, we expect a single column containing the node data map.
    expected = [('f', 'agtype')] # Expecting the node itself in a column named 'f'
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected) or []
        # Results will be like [{'f': {'id': ..., 'name': ...}}, {'f': ...}]
        # Extract the inner map
        return [r['f'] for r in results if isinstance(r, dict) and 'f' in r and isinstance(r['f'], dict)]
    except Exception as e:
        print(f"Error getting followers for user {user_id}: {e}")
        # Log the error but return empty list to avoid crashing the caller
        return []

def get_following(cursor: psycopg2.extensions.cursor, user_id: int) -> List[Dict[str, Any]]:
    cypher_q = f"MATCH (:User {{id: {user_id}}})-[:FOLLOWS]->(f:User) RETURN f ORDER BY f.username"
    expected = [('f', 'agtype')] # Same as get_followers
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected) or []
        return [r['f'] for r in results if isinstance(r, dict) and 'f' in r and isinstance(r['f'], dict)]
    except Exception as e:
        print(f"Error getting following for user {user_id}: {e}")
        return []

def get_user_joined_communities_graph(cursor: psycopg2.extensions.cursor, user_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    """Fetches basic info of communities joined by the user."""
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[:MEMBER_OF]->(c:Community)
        RETURN c.id as id, c.name as name, c.interest as interest
        ORDER BY c.name SKIP {offset} LIMIT {limit}
     """
    expected = [('id', 'agtype'), ('name', 'agtype'), ('interest', 'agtype')]
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected) or []
        return [r for r in results if isinstance(r, dict)]
    except Exception as e:
        print(f"CRUD Error getting user joined communities graph: {e}")
        raise

def get_user_participated_events_graph(cursor: psycopg2.extensions.cursor, user_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    """Fetches basic info of events the user participated in."""
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[p:PARTICIPATED_IN]->(e:Event)
        RETURN e.id as id, e.title as title, e.event_timestamp as event_timestamp
        ORDER BY e.event_timestamp DESC SKIP {offset} LIMIT {limit}
    """
    expected = [('id', 'agtype'), ('title', 'agtype'), ('event_timestamp', 'agtype')]
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected) or []
        return [r for r in results if isinstance(r, dict)]
    except Exception as e:
        print(f"CRUD Error getting user participated events graph: {e}")
        raise

def get_user_joined_communities_count(cursor: psycopg2.extensions.cursor, user_id: int) -> int:
    """Counts communities joined by the user using graph."""
    cypher_q = f"MATCH (:User {{id: {user_id}}})-[:MEMBER_OF]->(c:Community) RETURN count(c) as c_count"
    expected = [('c_count', 'int8')] # Expect integer count
    try:
        result = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected)
        # Result should be a dict {'c_count': 5}, value already parsed as int
        return result.get('c_count', 0) if result else 0
    except Exception as e:
        print(f"Warning: Failed getting joined communities count for user {user_id}: {e}")
        return 0

def get_user_participated_events_count(cursor: psycopg2.extensions.cursor, user_id: int) -> int:
    """Counts events participated in by the user using graph."""
    cypher_q = f"MATCH (:User {{id: {user_id}}})-[:PARTICIPATED_IN]->(e:Event) RETURN count(e) as e_count"
    expected = [('e_count', 'int8')]
    try:
        result = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected)
        return result.get('e_count', 0) if result else 0
    except Exception as e:
        print(f"Warning: Failed getting participated events count for user {user_id}: {e}")
        return 0