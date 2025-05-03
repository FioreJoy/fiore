# backend/src/crud.py
import psycopg2
import psycopg2.extras # For RealDictCursor
from datetime import datetime, timezone, timedelta
from typing import List, Optional, Dict, Any
import bcrypt
import json # For escaping strings for Cypher properties if needed

# --- Import utils INCLUDING parse_agtype ---
from . import utils, schemas # Import schemas for potential type hints
from .utils import parse_agtype, quote_cypher_string # Import helpers

# --- Constants ---
GRAPH_NAME = 'fiore' # Use the correct graph name

# =========================================
# Helper Function for Executing Cypher in CRUD
# =========================================
def execute_cypher(cursor: psycopg2.extensions.cursor, query: str, fetch_one=False, fetch_all=False):
    """Executes a Cypher query via AGE and optionally fetches results."""
    # Assumes search_path is set correctly by the connection or session
    # Or explicitly prefix: sql = f"SELECT * FROM ag_catalog.cypher('{GRAPH_NAME}', $${query}$$) as (result agtype);"
    sql = f"SELECT * FROM ag_catalog.cypher('{GRAPH_NAME}', $${query}$$) as (result agtype);"
    try:
        # print(f"DEBUG execute_cypher SQL: {sql}") # Uncomment for debugging
        cursor.execute(sql)
        if fetch_one:
            row = cursor.fetchone()
            # print(f"DEBUG execute_cypher fetchone raw: {row}") # Debug raw output
            return row['result'] if row else None # Return the agtype value
        elif fetch_all:
            rows = cursor.fetchall()
            # print(f"DEBUG execute_cypher fetchall raw: {rows}") # Debug raw output
            return [row['result'] for row in rows] # Return list of agtype values
        else:
            # For MERGE/CREATE/DELETE, often no specific result needed, just success/failure
            # We might check cursor.rowcount here if needed, but MERGE complicates it.
            # Assume success if no exception is raised.
            return True # Indicate success
    except psycopg2.Error as db_err:
        print(f"!!! Cypher Execution Error ({db_err.pgcode}): {db_err}")
        print(f"    Query: {query}")
        # Re-raise to be caught by the calling function for transaction rollback
        raise db_err
    except Exception as e:
        print(f"!!! Unexpected Error in execute_cypher: {e}")
        print(f"    Query: {query}")
        raise e


# =========================================
# User CRUD (Relational + Graph)
# =========================================

def get_user_by_email(cursor: psycopg2.extensions.cursor, email: str) -> Optional[Dict[str, Any]]:
    """Fetches basic user data (including hash) by email from relational table."""
    # Keep fetching essential auth data from the reliable public.users table
    cursor.execute(
        "SELECT id, username, password_hash, image_path FROM public.users WHERE email = %s",
        (email,)
    )
    return cursor.fetchone() # Returns RealDictRow or None

def get_user_by_id(cursor: psycopg2.extensions.cursor, user_id: int) -> Optional[Dict[str, Any]]:
    """Fetches user details from relational table. Counts are fetched separately."""
    # Fetch main user data from public.users
    cursor.execute(
        """SELECT id, name, username, email, gender, image_path,
                  current_location, current_location_address,
                  college, interest, created_at, last_seen
           FROM public.users WHERE id = %s;""",
        (user_id,)
    )
    # Return RealDictRow or None
    # The calling function (router) will fetch graph counts if needed
    return cursor.fetchone()

# --- NEW: Fetch user counts from graph ---
def get_user_graph_counts(cursor: psycopg2.extensions.cursor, user_id: int) -> Dict[str, int]:
    """Fetches follower and following counts from the AGE graph."""
    cypher_query = f"""
        MATCH (u:User {{id: {user_id}}})
        OPTIONAL MATCH (follower:User)-[:FOLLOWS]->(u)
        OPTIONAL MATCH (u)-[:FOLLOWS]->(following:User)
        RETURN count(DISTINCT follower) as followers_count, count(DISTINCT following) as following_count
    """
    result_agtype = execute_cypher(cursor, cypher_query, fetch_one=True)
    # result_agtype should contain a map like '{"followers_count": 5, "following_count": 3}'
    result_map = parse_agtype(result_agtype)

    if isinstance(result_map, dict):
        return {
            "followers_count": int(result_map.get('followers_count', 0)),
            "following_count": int(result_map.get('following_count', 0)),
        }
    else:
        print(f"Warning: Unexpected result format for graph counts: {result_map}")
        return {"followers_count": 0, "following_count": 0}


def create_user(
        cursor: psycopg2.extensions.cursor,
        name: str, username: str, email: str, password: str, gender: str,
        current_location_str: str, # Expects "(lon,lat)"
        college: str, interests_str: Optional[str], image_path: Optional[str],
        current_location_address: Optional[str] # Added address
) -> Optional[int]:
    """
    Creates a user in public.users AND a corresponding :User vertex in AGE graph.
    Uses transaction: rolls back both if either fails.
    """
    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    user_id = None
    try:
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
            print("ERROR: Failed to get ID back from public.users insert.")
            raise psycopg2.DatabaseError("User insert failed to return ID.")
        user_id = result['id']
        print(f"Inserted user {user_id} into public.users.")

        # 2. Create vertex in AGE graph
        user_props = {
            'id': user_id, 'username': username, 'name': name, 'image_path': image_path
        }
        set_clauses_str = build_cypher_set_clauses('u', user_props)
        # Use CREATE instead of MERGE for a newly created user
        cypher_q = f"CREATE (u:User {{id: {user_id}}})"
        if set_clauses_str:
            cypher_q += f" SET {set_clauses_str}"

        print(f"Creating AGE vertex for user {user_id}...")
        execute_cypher(cursor, cypher_q) # No fetch needed
        print(f"AGE vertex created for user {user_id}.")

        # If both succeed, the caller should commit the transaction
        return user_id

    except Exception as e:
        print(f"ERROR in create_user (User ID: {user_id if user_id else 'N/A'}): {e}")
        # IMPORTANT: Don't commit here. Let the calling function handle rollback on exception.
        raise # Re-raise the exception


def update_user_profile(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        update_data: Dict[str, Any] # Contains ONLY fields to update
) -> bool:
    """
    Updates user profile in public.users AND corresponding :User vertex properties in AGE.
    Uses transaction: rolls back both if either fails.
    """
    relational_set_clauses = []
    relational_params = []
    graph_props_to_update = {} # Properties to update in AGE

    # Separate relational and graph updates
    allowed_relational_fields = [
        'name', 'username', 'gender', 'current_location', 'college',
        'interest', 'image_path', 'current_location_address'
    ]
    allowed_graph_props = ['username', 'name', 'image_path'] # Props stored in AGE :User

    for key, value in update_data.items():
        # Update Relational Table
        if key in allowed_relational_fields:
            # Special handling for POINT type
            if key == 'current_location':
                # Value should already be formatted "(lon,lat)" by router
                relational_set_clauses.append(f"current_location = %s::point")
            else:
                relational_set_clauses.append(f"{key} = %s")
            relational_params.append(value)

        # Check if this property also needs updating in the graph
        if key in allowed_graph_props:
            graph_props_to_update[key] = value

    try:
        # 1. Update Relational Table (if anything changed there)
        rows_affected = 0
        if relational_set_clauses:
            relational_params.append(user_id)
            relational_query = f"UPDATE public.users SET {', '.join(relational_set_clauses)} WHERE id = %s;"
            # print(f"DEBUG update_user_profile SQL: {relational_query}")
            # print(f"DEBUG update_user_profile PARAMS: {relational_params}")
            cursor.execute(relational_query, tuple(relational_params))
            rows_affected = cursor.rowcount
            print(f"Updated public.users for user {user_id} (Rows affected: {rows_affected}).")
        else:
            # If only graph properties changed, set rows_affected to trigger graph update check
            # Or check if user exists first
            cursor.execute("SELECT 1 FROM public.users WHERE id = %s", (user_id,))
            if cursor.fetchone():
                rows_affected = 1 # Assume user exists if no relational update needed
            else:
                print(f"Warning: User {user_id} not found for profile update.")
                return False

        # 2. Update AGE Graph Vertex (if anything changed there AND user exists)
        if graph_props_to_update and rows_affected > 0:
            set_clauses_str = build_cypher_set_clauses('u', graph_props_to_update)
            if set_clauses_str: # Ensure there are properties to SET
                cypher_q = f"""
                    MATCH (u:User {{id: {user_id}}})
                    SET {set_clauses_str}
                """
                print(f"Updating AGE vertex for user {user_id}...")
                execute_cypher(cursor, cypher_q) # No fetch needed
                print(f"AGE vertex updated for user {user_id}.")
            else:
                print(f"No graph properties needed updating for user {user_id}.")

        # If either relational or graph update happened (or user was found), return True
        # The caller should commit the transaction.
        return rows_affected > 0

    except Exception as e:
        print(f"ERROR in update_user_profile (User ID: {user_id}): {e}")
        raise # Re-raise for rollback


def update_user_last_seen(cursor: psycopg2.extensions.cursor, user_id: int):
    """Updates only the last_seen timestamp in public.users."""
    try:
        cursor.execute("UPDATE public.users SET last_seen = NOW() WHERE id = %s", (user_id,))
        # print(f"CRUD: Updated last_seen for user {user_id}") # Optional log
    except Exception as e:
        print(f"CRUD Error updating last_seen for user {user_id}: {e}")
        # Don't raise here usually, failure is not critical for main operation
        # Let calling function decide how to handle

def delete_user(cursor: psycopg2.extensions.cursor, user_id: int) -> bool:
    """Deletes user from public.users (CASCADE should handle FKs) AND from AGE graph."""
    try:
        # 1. Delete from AGE graph first (or within same transaction)
        cypher_q = f"MATCH (u:User {{id: {user_id}}}) DETACH DELETE u"
        print(f"Deleting AGE vertex for user {user_id}...")
        execute_cypher(cursor, cypher_q)
        print(f"AGE vertex deleted for user {user_id}.")

        # 2. Delete from relational table
        cursor.execute("DELETE FROM public.users WHERE id = %s;", (user_id,))
        rows_deleted = cursor.rowcount
        print(f"Deleted user {user_id} from public.users (Rows affected: {rows_deleted}).")

        # Caller should commit
        return rows_deleted > 0
    except Exception as e:
        print(f"ERROR in delete_user (User ID: {user_id}): {e}")
        raise # Re-raise for rollback

# =========================================
# Follower CRUD (Graph Operations)
# =========================================

def follow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    """Creates a :FOLLOWS edge in AGE graph. Returns True if created, False if exists."""
    # MERGE handles idempotency. We check result to see if relationship was new.
    # NOTE: Checking existence before MERGE is less efficient. Rely on MERGE.
    # To know if it was *newly* created requires more complex Cypher or checking before/after.
    # Let's simplify: just execute MERGE. Return True on success, let router handle interpretation.
    now_iso = datetime.now(timezone.utc).isoformat()
    cypher_q = f"""
        MATCH (f:User {{id: {follower_id}}})
        MATCH (t:User {{id: {following_id}}})
        MERGE (f)-[r:FOLLOWS]->(t)
        -- Optionally set/update timestamp on MERGE
        SET r.created_at = {quote_cypher_string(now_iso)}
    """
    try:
        execute_cypher(cursor, cypher_q)
        # Assume success if no error. We can't easily tell if it was newly created vs existing here.
        return True
    except Exception as e:
        print(f"Error following user ({follower_id} -> {following_id}): {e}")
        raise # Re-raise for rollback/error handling


def unfollow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    """Deletes a :FOLLOWS edge in AGE graph. Returns True if deleted, False if not found."""
    cypher_q = f"""
        MATCH (f:User {{id: {follower_id}}})-[r:FOLLOWS]->(t:User {{id: {following_id}}})
        DELETE r
        RETURN count(r) as deleted_count // Return count to check if deleted
    """
    try:
        # Fetch the result to see if anything was deleted
        result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
        result_map = parse_agtype(result_agtype)
        # AGE might return 0 if edge didn't exist, or 1 if deleted
        deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
        return deleted_count > 0
    except Exception as e:
        print(f"Error unfollowing user ({follower_id} -> {following_id}): {e}")
        raise

def get_followers(cursor: psycopg2.extensions.cursor, user_id: int) -> List[Dict[str, Any]]:
    """Gets followers (User nodes) from AGE graph."""
    # Fetch basic info needed for display (match UserBase schema fields)
    cypher_q = f"""
        MATCH (follower:User)-[:FOLLOWS]->(target:User {{id: {user_id}}})
        RETURN follower.id as id,
               follower.username as username,
               follower.name as name,
               follower.image_path as image_path
               // Add other fields needed by UserBase schema (gender, email etc)
               // follower.gender as gender, ...
        ORDER BY follower.username // Optional ordering
    """
    try:
        results_agtype = execute_cypher(cursor, cypher_q, fetch_all=True)
        # Parse each agtype map in the results
        followers = [parse_agtype(row) for row in results_agtype]
        # Ensure they are dictionaries before returning
        return [f for f in followers if isinstance(f, dict)]
    except Exception as e:
        print(f"Error getting followers for user {user_id}: {e}")
        raise

def get_following(cursor: psycopg2.extensions.cursor, user_id: int) -> List[Dict[str, Any]]:
    """Gets users being followed (User nodes) from AGE graph."""
    cypher_q = f"""
        MATCH (follower:User {{id: {user_id}}})-[:FOLLOWS]->(following:User)
        RETURN following.id as id,
               following.username as username,
               following.name as name,
               following.image_path as image_path
               // Add other fields needed by UserBase schema
        ORDER BY following.username // Optional ordering
    """
    try:
        results_agtype = execute_cypher(cursor, cypher_q, fetch_all=True)
        following = [parse_agtype(row) for row in results_agtype]
        return [f for f in following if isinstance(f, dict)]
    except Exception as e:
        print(f"Error getting following for user {user_id}: {e}")
        raise

# =========================================
# Community CRUD (Relational + Graph)
# =========================================

# --- create_community_db ---
def create_community_db(
        cursor: psycopg2.extensions.cursor, name: str, description: Optional[str],
        created_by: int, primary_location_str: str, interest: Optional[str],
        logo_path: Optional[str]
) -> Optional[int]:
    """Creates community in public.communities and :Community vertex in AGE."""
    community_id = None
    try:
        # 1. Insert into relational table
        cursor.execute(
            """
            INSERT INTO public.communities (name, description, created_by, primary_location, interest, logo_path)
            VALUES (%s, %s, %s, %s::point, %s, %s) RETURNING id, created_at;
            """,
            (name, description, created_by, primary_location_str, interest, logo_path),
        )
        result = cursor.fetchone()
        if not result or 'id' not in result: raise psycopg2.DatabaseError("Community insert failed")
        community_id = result['id']
        created_at = result['created_at'] # Get timestamp for graph edge
        print(f"Inserted community {community_id} into public.communities.")

        # 2. Create :Community vertex
        comm_props = {'id': community_id, 'name': name, 'interest': interest}
        set_clauses_str = build_cypher_set_clauses('c', comm_props)
        cypher_q_vertex = f"CREATE (c:Community {{id: {community_id}}})"
        if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
        print(f"Creating AGE vertex for community {community_id}...")
        execute_cypher(cursor, cypher_q_vertex)
        print(f"AGE vertex created for community {community_id}.")

        # 3. Create :CREATED edge (User -> Community)
        created_at_quoted = quote_cypher_string(created_at)
        cypher_q_edge = f"""
            MATCH (u:User {{id: {created_by}}})
            MATCH (c:Community {{id: {community_id}}})
            MERGE (u)-[r:CREATED]->(c)
            SET r.created_at = {created_at_quoted}
        """
        print(f"Creating :CREATED edge for community {community_id}...")
        execute_cypher(cursor, cypher_q_edge)
        print(f":CREATED edge created.")

        # 4. Add creator as member (:MEMBER_OF edge) - Replaces insert to community_members
        joined_at_quoted = quote_cypher_string(created_at) # Use creation time as join time
        cypher_q_member = f"""
            MATCH (u:User {{id: {created_by}}})
            MATCH (c:Community {{id: {community_id}}})
            MERGE (u)-[r:MEMBER_OF]->(c)
            SET r.joined_at = {joined_at_quoted}
        """
        print(f"Adding creator {created_by} as member of community {community_id}...")
        execute_cypher(cursor, cypher_q_member)
        print(f":MEMBER_OF edge created for creator.")

        # Caller commits
        return community_id
    except Exception as e:
        print(f"ERROR in create_community_db (ID: {community_id if community_id else 'N/A'}): {e}")
        raise

# --- get_community_by_id (fetch relational details) ---
def get_community_by_id(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
    """Fetches community details from relational table."""
    cursor.execute(
        """SELECT id, name, description, created_by, created_at,
                  primary_location, interest, logo_path
           FROM public.communities WHERE id = %s""",
        (community_id,)
    )
    return cursor.fetchone()

# --- get_communities_db (fetch relational list) ---
def get_communities_db(cursor: psycopg2.extensions.cursor) -> List[Dict[str, Any]]:
    """Fetches list of communities from relational table."""
    # Counts will be added by graph queries in the router if needed
    query = """
        SELECT id, name, description, created_by, created_at,
               primary_location, interest, logo_path
        FROM public.communities
        ORDER BY created_at DESC;
    """
    cursor.execute(query)
    return cursor.fetchall()

# --- NEW: get_community_counts (fetch graph counts) ---
def get_community_counts(cursor: psycopg2.extensions.cursor, community_id: int) -> Dict[str, int]:
    """Fetches member and online counts from AGE graph."""
    # TODO: Implement online count based on User last_seen property if stored in graph,
    # otherwise this requires joining back to public.users which is less ideal.
    # For now, just member count.
    cypher_q = f"""
        MATCH (c:Community {{id: {community_id}}})<-[r:MEMBER_OF]-(member:User)
        RETURN count(DISTINCT member) as member_count
        // Add logic for online count if feasible within graph
        // WITH count(DISTINCT member) as member_count, c
        // MATCH (c)<-[:MEMBER_OF]-(online_member:User)
        // WHERE online_member.last_seen >= datetime() - duration("PT5M") // Example syntax
        // RETURN member_count, count(DISTINCT online_member) as online_count
    """
    result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
    result_map = parse_agtype(result_agtype)
    if isinstance(result_map, dict):
        return {
            "member_count": int(result_map.get('member_count', 0)),
            "online_count": int(result_map.get('online_count', 0)) # Placeholder
        }
    else:
        return {"member_count": 0, "online_count": 0}

# --- update_community_details_db ---
def update_community_details_db(cursor: psycopg2.extensions.cursor, community_id: int, update_data: schemas.CommunityUpdate) -> bool:
    """Updates community in public.communities AND :Community vertex properties."""
    # Similar logic to update_user_profile: update relational then graph
    relational_set_clauses = []
    relational_params = []
    graph_props_to_update = {}
    update_dict = update_data.model_dump(exclude_unset=True)

    allowed_relational_fields = ['name', 'description', 'primary_location', 'interest', 'logo_path']
    allowed_graph_props = ['name', 'interest'] # Only update props stored in graph node

    for key, value in update_dict.items():
        if key in allowed_relational_fields:
            if key == 'primary_location':
                relational_set_clauses.append(f"primary_location = %s::point")
            else:
                relational_set_clauses.append(f"{key} = %s")
            relational_params.append(value)
        if key in allowed_graph_props:
            graph_props_to_update[key] = value

    try:
        rows_affected = 0
        if relational_set_clauses:
            relational_params.append(community_id)
            sql = f"UPDATE public.communities SET {', '.join(relational_set_clauses)} WHERE id = %s;"
            cursor.execute(sql, tuple(relational_params))
            rows_affected = cursor.rowcount
            print(f"Updated public.communities for ID {community_id}.")
        else:
            # Check if community exists if only graph props changed
            cursor.execute("SELECT 1 FROM public.communities WHERE id = %s", (community_id,))
            if cursor.fetchone(): rows_affected = 1
            else: return False

        if graph_props_to_update and rows_affected > 0:
            set_clauses_str = build_cypher_set_clauses('c', graph_props_to_update)
            if set_clauses_str:
                cypher_q = f"""
                    MATCH (c:Community {{id: {community_id}}})
                    SET {set_clauses_str}
                """
                execute_cypher(cursor, cypher_q)
                print(f"Updated AGE vertex for community {community_id}.")

        return rows_affected > 0
    except Exception as e:
        print(f"ERROR in update_community_details_db (ID: {community_id}): {e}")
        raise

# --- update_community_logo_path_db (Only updates relational table) ---
def update_community_logo_path_db(cursor: psycopg2.extensions.cursor, community_id: int, logo_path: Optional[str]) -> bool:
    """ Updates only the logo_path in the relational table. """
    # Graph vertex doesn't store logo_path in this design
    try:
        cursor.execute(
            "UPDATE public.communities SET logo_path = %s WHERE id = %s;",
            (logo_path, community_id)
        )
        return cursor.rowcount > 0
    except Exception as e:
        print(f"Error updating community logo path (ID: {community_id}): {e}")
        raise

# --- get_trending_communities_db (Relies on complex logic, maybe keep relational for now?) ---
# TODO: Re-evaluate if this can be efficiently done via graph queries later.
# For now, keep the relational query.
def get_trending_communities_db(cursor: psycopg2.extensions.cursor) -> List[Dict[str, Any]]:
    """Fetches trending communities based on recent activity (using relational joins)."""
    query = """
        SELECT
            c.id, c.name, c.description, c.interest, c.primary_location, c.logo_path, c.created_by, c.created_at,
            (COALESCE(recent_members.count, 0) + COALESCE(recent_posts.count, 0)) AS recent_activity_score,
            COALESCE(total_members.count, 0) as member_count
        FROM public.communities c
        LEFT JOIN (
            SELECT community_id, COUNT(*) as count FROM public.community_members
            WHERE joined_at >= NOW() - INTERVAL '48 hours' GROUP BY community_id
        ) AS recent_members ON c.id = recent_members.community_id
        LEFT JOIN (
            SELECT cp.community_id, COUNT(*) as count FROM public.community_posts cp
            JOIN public.posts p ON cp.post_id = p.id
            WHERE p.created_at >= NOW() - INTERVAL '48 hours' GROUP BY cp.community_id
        ) AS recent_posts ON c.id = recent_posts.community_id
        LEFT JOIN (
             SELECT community_id, COUNT(*) as count FROM public.community_members GROUP BY community_id
        ) AS total_members ON c.id = total_members.community_id
        ORDER BY recent_activity_score DESC, c.created_at DESC
        LIMIT 15;
     """
    # WHERE c.created_at >= NOW() - INTERVAL '30 days' -- Removed this filter
    cursor.execute(query)
    return cursor.fetchall()


# --- get_community_details_db (Now combines relational + graph counts) ---
# Keep name as is, but logic changes
def get_community_details_db(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
    """Fetches detailed community data from relational AND graph counts."""
    # 1. Fetch relational data
    community_relational = get_community_by_id(cursor, community_id)
    if not community_relational:
        return None

    # 2. Fetch graph counts
    counts = get_community_counts(cursor, community_id)

    # 3. Combine results
    combined_data = dict(community_relational)
    combined_data.update(counts) # Add member_count, online_count

    return combined_data


# --- delete_community_db ---
def delete_community_db(cursor: psycopg2.extensions.cursor, community_id: int) -> bool:
    """Deletes community from public.communities AND AGE graph."""
    try:
        # 1. Delete from AGE graph
        cypher_q = f"MATCH (c:Community {{id: {community_id}}}) DETACH DELETE c"
        print(f"Deleting AGE vertex for community {community_id}...")
        execute_cypher(cursor, cypher_q)
        print(f"AGE vertex deleted for community {community_id}.")

        # 2. Delete from relational table (CASCADE should handle FKs)
        cursor.execute("DELETE FROM public.communities WHERE id = %s;", (community_id,))
        rows_deleted = cursor.rowcount
        print(f"Deleted community {community_id} from public.communities (Rows affected: {rows_deleted}).")

        return rows_deleted > 0
    except Exception as e:
        print(f"ERROR in delete_community_db (ID: {community_id}): {e}")
        raise

# --- join_community_db (Graph operation) ---
def join_community_db(cursor: psycopg2.extensions.cursor, user_id: int, community_id: int) -> bool:
    """Creates :MEMBER_OF edge in AGE graph."""
    now_iso = datetime.now(timezone.utc).isoformat()
    joined_at_quoted = quote_cypher_string(now_iso)
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (c:Community {{id: {community_id}}})
        MERGE (u)-[r:MEMBER_OF]->(c)
        ON CREATE SET r.joined_at = {joined_at_quoted} -- Set only if newly created
        ON MATCH SET r.joined_at = {joined_at_quoted}  -- Update if already exists
    """
    try:
        execute_cypher(cursor, cypher_q)
        return True # Assume success if no error
    except Exception as e:
        print(f"Error joining community (U:{user_id}, C:{community_id}): {e}")
        raise

# --- leave_community_db (Graph operation) ---
def leave_community_db(cursor: psycopg2.extensions.cursor, user_id: int, community_id: int) -> bool:
    """Deletes :MEMBER_OF edge in AGE graph."""
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[r:MEMBER_OF]->(c:Community {{id: {community_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    try:
        result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
        result_map = parse_agtype(result_agtype)
        deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
        return deleted_count > 0
    except Exception as e:
        print(f"Error leaving community (U:{user_id}, C:{community_id}): {e}")
        raise

# --- add_post_to_community_db (Graph operation) ---
def add_post_to_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> bool:
    """Creates :HAS_POST edge from Community to Post."""
    now_iso = datetime.now(timezone.utc).isoformat()
    added_at_quoted = quote_cypher_string(now_iso)
    cypher_q = f"""
        MATCH (c:Community {{id: {community_id}}})
        MATCH (p:Post {{id: {post_id}}})
        MERGE (c)-[r:HAS_POST]->(p)
        SET r.added_at = {added_at_quoted}
    """
    try:
        execute_cypher(cursor, cypher_q)
        return True
    except Exception as e:
        print(f"Error adding post to community (C:{community_id}, P:{post_id}): {e}")
        raise

# --- remove_post_from_community_db (Graph operation) ---
def remove_post_from_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> bool:
    """Deletes :HAS_POST edge between Community and Post."""
    cypher_q = f"""
        MATCH (c:Community {{id: {community_id}}})-[r:HAS_POST]->(p:Post {{id: {post_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    try:
        result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
        result_map = parse_agtype(result_agtype)
        deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
        return deleted_count > 0
    except Exception as e:
        print(f"Error removing post from community (C:{community_id}, P:{post_id}): {e}")
        raise

# =========================================
# Post CRUD (Relational + Graph)
# =========================================

# --- create_post_db ---
def create_post_db(
        cursor: psycopg2.extensions.cursor, user_id: int, title: str, content: str,
        image_path: Optional[str] = None, community_id: Optional[int] = None
) -> Optional[int]:
    """Creates post in public.posts, :Post vertex, :WROTE edge, and optional :HAS_POST edge."""
    post_id = None
    try:
        # 1. Insert into public.posts
        cursor.execute(
            """
            INSERT INTO public.posts (user_id, title, content, image_path)
            VALUES (%s, %s, %s, %s) RETURNING id, created_at;
            """,
            (user_id, title, content, image_path),
        )
        result = cursor.fetchone()
        if not result or 'id' not in result: raise psycopg2.DatabaseError("Post insert failed")
        post_id = result['id']
        created_at = result['created_at']
        print(f"Inserted post {post_id} into public.posts.")

        # 2. Create :Post vertex
        post_props = {'id': post_id, 'title': title, 'created_at': created_at} # Include created_at
        set_clauses_str = build_cypher_set_clauses('p', post_props)
        cypher_q_vertex = f"CREATE (p:Post {{id: {post_id}}})" # Use CREATE
        if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
        execute_cypher(cursor, cypher_q_vertex)
        print(f"AGE vertex created for post {post_id}.")

        # 3. Create :WROTE edge (User -> Post)
        created_at_quoted = quote_cypher_string(created_at)
        cypher_q_wrote = f"""
            MATCH (u:User {{id: {user_id}}})
            MATCH (p:Post {{id: {post_id}}})
            MERGE (u)-[r:WROTE]->(p)
            SET r.created_at = {created_at_quoted}
        """
        execute_cypher(cursor, cypher_q_wrote)
        print(f":WROTE edge created for post {post_id}.")

        # 4. Optionally create :HAS_POST edge (Community -> Post)
        if community_id is not None:
            added_at_quoted = quote_cypher_string(created_at) # Use post creation time
            cypher_q_has_post = f"""
                MATCH (c:Community {{id: {community_id}}})
                MATCH (p:Post {{id: {post_id}}})
                MERGE (c)-[r:HAS_POST]->(p)
                SET r.added_at = {added_at_quoted}
            """
            execute_cypher(cursor, cypher_q_has_post)
            print(f":HAS_POST edge created for post {post_id} in community {community_id}.")

        # Caller commits
        return post_id
    except Exception as e:
        print(f"ERROR in create_post_db (ID: {post_id if post_id else 'N/A'}): {e}")
        raise

# --- get_post_by_id (fetches relational details) ---
def get_post_by_id(cursor: psycopg2.extensions.cursor, post_id: int) -> Optional[Dict[str, Any]]:
    """Fetches post details from relational table."""
    cursor.execute(
        "SELECT id, user_id, content, title, created_at, image_path FROM public.posts WHERE id = %s",
        (post_id,)
    )
    return cursor.fetchone()

# --- NEW: get_post_counts (fetches graph counts) ---
def get_post_counts(cursor: psycopg2.extensions.cursor, post_id: int) -> Dict[str, int]:
    """Fetches reply count and vote counts for a post from AGE graph."""
    cypher_q = f"""
        MATCH (p:Post {{id: {post_id}}})
        OPTIONAL MATCH (reply:Reply)-[:REPLIED_TO]->(p)
        OPTIONAL MATCH (upvoter:User)-[:VOTED {{vote_type: true}}]->(p)
        OPTIONAL MATCH (downvoter:User)-[:VOTED {{vote_type: false}}]->(p)
        RETURN count(DISTINCT reply) as reply_count,
               count(DISTINCT upvoter) as upvotes,
               count(DISTINCT downvoter) as downvotes
    """
    result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
    result_map = parse_agtype(result_agtype)
    if isinstance(result_map, dict):
        return {
            "reply_count": int(result_map.get('reply_count', 0)),
            "upvotes": int(result_map.get('upvotes', 0)),
            "downvotes": int(result_map.get('downvotes', 0)),
        }
    else:
        return {"reply_count": 0, "upvotes": 0, "downvotes": 0}

# --- get_posts_db (Combines relational list fetch with graph counts) ---
# Keep name, modify logic
def get_posts_db(
        cursor: psycopg2.extensions.cursor,
        community_id: Optional[int] = None,
        user_id: Optional[int] = None
) -> List[Dict[str, Any]]:
    """ Fetches posts from relational table, adds graph counts and author/community info."""
    # Base query for relational post data
    sql = """
        SELECT
            p.id, p.user_id, p.content, p.title, p.created_at, p.image_path,
            u.username AS author_name,
            u.image_path AS author_avatar,
            c.id as community_id,
            c.name as community_name
        FROM public.posts p
        JOIN public.users u ON p.user_id = u.id
        LEFT JOIN public.community_posts cp ON p.id = cp.post_id -- Still needed for filtering
        LEFT JOIN public.communities c ON cp.community_id = c.id
    """
    params = []
    filters = []
    if community_id is not None:
        filters.append("cp.community_id = %s")
        params.append(community_id)
    if user_id is not None:
        filters.append("p.user_id = %s")
        params.append(user_id)

    if filters:
        sql += " WHERE " + " AND ".join(filters)
    sql += " ORDER BY p.created_at DESC;" # Add LIMIT/OFFSET here if needed

    cursor.execute(sql, tuple(params))
    posts_relational = cursor.fetchall()

    # Augment with graph counts
    augmented_posts = []
    for post_rel in posts_relational:
        post_data = dict(post_rel)
        post_id = post_data['id']
        # Fetch counts for this post
        counts = get_post_counts(cursor, post_id)
        post_data.update(counts)
        augmented_posts.append(post_data)

    return augmented_posts


# --- delete_post_db ---
def delete_post_db(cursor: psycopg2.extensions.cursor, post_id: int) -> bool:
    """Deletes post from public.posts AND AGE graph."""
    try:
        # 1. Delete from AGE graph
        cypher_q = f"MATCH (p:Post {{id: {post_id}}}) DETACH DELETE p"
        execute_cypher(cursor, cypher_q)
        print(f"AGE vertex deleted for post {post_id}.")

        # 2. Delete from relational table
        cursor.execute("DELETE FROM public.posts WHERE id = %s;", (post_id,))
        rows_deleted = cursor.rowcount
        print(f"Deleted post {post_id} from public.posts (Rows affected: {rows_deleted}).")

        return rows_deleted > 0
    except Exception as e:
        print(f"ERROR in delete_post_db (ID: {post_id}): {e}")
        raise

# =========================================
# Reply CRUD (Relational + Graph)
# =========================================

# --- get_reply_by_id (fetch relational details) ---
def get_reply_by_id(cursor: psycopg2.extensions.cursor, reply_id: int) -> Optional[Dict[str, Any]]:
    """Fetches reply details from relational table."""
    cursor.execute(
        "SELECT id, user_id, post_id, content, parent_reply_id, created_at FROM public.replies WHERE id = %s",
        (reply_id,)
    )
    return cursor.fetchone()

# --- NEW: get_reply_counts (fetches graph counts) ---
def get_reply_counts(cursor: psycopg2.extensions.cursor, reply_id: int) -> Dict[str, int]:
    """Fetches vote counts for a reply from AGE graph."""
    cypher_q = f"""
        MATCH (rep:Reply {{id: {reply_id}}})
        OPTIONAL MATCH (upvoter:User)-[:VOTED {{vote_type: true}}]->(rep)
        OPTIONAL MATCH (downvoter:User)-[:VOTED {{vote_type: false}}]->(rep)
        RETURN count(DISTINCT upvoter) as upvotes,
               count(DISTINCT downvoter) as downvotes
    """
    result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
    result_map = parse_agtype(result_agtype)
    if isinstance(result_map, dict):
        return {
            "upvotes": int(result_map.get('upvotes', 0)),
            "downvotes": int(result_map.get('downvotes', 0)),
        }
    else:
        return {"upvotes": 0, "downvotes": 0}


# --- create_reply_db ---
def create_reply_db(
        cursor: psycopg2.extensions.cursor, post_id: int, user_id: int, content: str,
        parent_reply_id: Optional[int]
) -> Optional[int]:
    """Creates reply in public.replies, :Reply vertex, :WROTE edge, and :REPLIED_TO edge."""
    reply_id = None
    try:
        # 1. Insert into public.replies
        cursor.execute(
            """
            INSERT INTO public.replies (post_id, user_id, content, parent_reply_id)
            VALUES (%s, %s, %s, %s) RETURNING id, created_at;
            """,
            (post_id, user_id, content, parent_reply_id)
        )
        result = cursor.fetchone()
        if not result or 'id' not in result: raise psycopg2.DatabaseError("Reply insert failed")
        reply_id = result['id']
        created_at = result['created_at']
        print(f"Inserted reply {reply_id} into public.replies.")

        # 2. Create :Reply vertex
        reply_props = {'id': reply_id, 'created_at': created_at}
        set_clauses_str = build_cypher_set_clauses('r', reply_props)
        cypher_q_vertex = f"CREATE (r:Reply {{id: {reply_id}}})"
        if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
        execute_cypher(cursor, cypher_q_vertex)
        print(f"AGE vertex created for reply {reply_id}.")

        # 3. Create :WROTE edge (User -> Reply)
        created_at_quoted = quote_cypher_string(created_at)
        cypher_q_wrote = f"""
            MATCH (u:User {{id: {user_id}}})
            MATCH (rep:Reply {{id: {reply_id}}})
            MERGE (u)-[r:WROTE]->(rep)
            SET r.created_at = {created_at_quoted}
        """
        execute_cypher(cursor, cypher_q_wrote)
        print(f":WROTE edge created for reply {reply_id}.")

        # 4. Create :REPLIED_TO edge (Reply -> Post or Reply -> Reply)
        target_id = parent_reply_id if parent_reply_id is not None else post_id
        target_label = "Reply" if parent_reply_id is not None else "Post"
        cypher_q_replied = f"""
            MATCH (child:Reply {{id: {reply_id}}})
            MATCH (parent:{target_label} {{id: {target_id}}})
            MERGE (child)-[r:REPLIED_TO]->(parent)
            SET r.created_at = {created_at_quoted}
        """
        execute_cypher(cursor, cypher_q_replied)
        print(f":REPLIED_TO edge created for reply {reply_id} -> {target_label} {target_id}.")

        return reply_id
    except Exception as e:
        print(f"ERROR in create_reply_db (ID: {reply_id if reply_id else 'N/A'}): {e}")
        raise

# --- get_replies_for_post_db (Combines relational + graph) ---
# Keep name, modify logic
def get_replies_for_post_db(cursor: psycopg2.extensions.cursor, post_id: int) -> List[Dict[str, Any]]:
    """ Fetches replies from relational table, adds graph counts and author info."""
    # Fetch relational reply data including author info
    sql = """
        SELECT
            r.id, r.post_id, r.user_id, r.content, r.parent_reply_id, r.created_at,
            u.username AS author_name,
            u.image_path AS author_avatar -- Fetch path for URL generation
        FROM public.replies r
        JOIN public.users u ON r.user_id = u.id
        WHERE r.post_id = %s
        ORDER BY r.created_at ASC; -- Important for threading display
    """
    cursor.execute(sql, (post_id,))
    replies_relational = cursor.fetchall()

    # Augment with graph counts
    augmented_replies = []
    for reply_rel in replies_relational:
        reply_data = dict(reply_rel)
        reply_id = reply_data['id']
        # Fetch counts for this reply
        counts = get_reply_counts(cursor, reply_id)
        reply_data.update(counts)
        augmented_replies.append(reply_data)

    return augmented_replies


# --- delete_reply_db ---
def delete_reply_db(cursor: psycopg2.extensions.cursor, reply_id: int) -> bool:
    """Deletes reply from public.replies AND AGE graph."""
    try:
        # 1. Delete from AGE graph (DETACH DELETE handles relationships)
        cypher_q = f"MATCH (r:Reply {{id: {reply_id}}}) DETACH DELETE r"
        execute_cypher(cursor, cypher_q)
        print(f"AGE vertex deleted for reply {reply_id}.")

        # 2. Delete from relational table
        cursor.execute("DELETE FROM public.replies WHERE id = %s;", (reply_id,))
        rows_deleted = cursor.rowcount
        print(f"Deleted reply {reply_id} from public.replies (Rows affected: {rows_deleted}).")

        return rows_deleted > 0
    except Exception as e:
        print(f"ERROR in delete_reply_db (ID: {reply_id}): {e}")
        raise

# =========================================
# Vote CRUD (Graph Operations Only)
# =========================================

# --- get_existing_vote (No longer needed, MERGE handles existence) ---
# def get_existing_vote(...) -> REMOVE

# --- create_vote_db / update_vote_db / delete_vote_db -> Replaced by cast_vote ---

def cast_vote_db(
        cursor: psycopg2.extensions.cursor, user_id: int,
        post_id: Optional[int], reply_id: Optional[int],
        vote_type: bool # True=Up, False=Down
) -> bool:
    """Creates or updates a :VOTED edge in AGE. Returns success status."""
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None: raise ValueError("Must provide post_id or reply_id")

    now_iso = datetime.now(timezone.utc).isoformat()
    created_at_quoted = quote_cypher_string(now_iso)
    vote_type_cypher = 'true' if vote_type else 'false'

    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (target:{target_label} {{id: {target_id}}})
        -- Merge the edge. If it exists, it's matched. If not, it's created.
        MERGE (u)-[r:VOTED]->(target)
        -- Always set/update properties
        SET r.vote_type = {vote_type_cypher}, r.created_at = {created_at_quoted}
    """
    try:
        execute_cypher(cursor, cypher_q)
        return True # Assume success if no error
    except Exception as e:
        print(f"Error casting vote (U:{user_id} -> {target_label}:{target_id}): {e}")
        raise

def remove_vote_db(
        cursor: psycopg2.extensions.cursor, user_id: int,
        post_id: Optional[int], reply_id: Optional[int]
) -> bool:
    """Removes a :VOTED edge in AGE. Returns True if deleted."""
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None: raise ValueError("Must provide post_id or reply_id")

    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[r:VOTED]->(target:{target_label} {{id: {target_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    try:
        result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
        result_map = parse_agtype(result_agtype)
        deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
        return deleted_count > 0
    except Exception as e:
        print(f"Error removing vote (U:{user_id} -> {target_label}:{target_id}): {e}")
        raise

# --- get_votes_db (No longer needed, counts are fetched with post/reply) ---
# def get_votes_db(...) -> REMOVE


# =========================================
# Favorite CRUD (Graph Operations Only)
# =========================================
# Add similar create/delete edge functions for :FAVORITED relationship
# connecting :User to :Post or :Reply

def add_favorite_db(cursor, user_id: int, post_id: Optional[int], reply_id: Optional[int]) -> bool:
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None: raise ValueError("Must provide post_id or reply_id")
    now_iso = datetime.now(timezone.utc).isoformat()
    favorited_at_quoted = quote_cypher_string(now_iso)

    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (target:{target_label} {{id: {target_id}}})
        MERGE (u)-[r:FAVORITED]->(target)
        SET r.favorited_at = {favorited_at_quoted}
    """
    try:
        execute_cypher(cursor, cypher_q)
        return True
    except Exception as e:
        print(f"Error adding favorite (U:{user_id} -> {target_label}:{target_id}): {e}")
        raise

def remove_favorite_db(cursor, user_id: int, post_id: Optional[int], reply_id: Optional[int]) -> bool:
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None: raise ValueError("Must provide post_id or reply_id")

    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[r:FAVORITED]->(target:{target_label} {{id: {target_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    try:
        result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
        result_map = parse_agtype(result_agtype)
        deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
        return deleted_count > 0
    except Exception as e:
        print(f"Error removing favorite (U:{user_id} -> {target_label}:{target_id}): {e}")
        raise

# =========================================
# Event CRUD (Relational + Graph)
# =========================================
# (Similar pattern: create/delete in both, add graph edges for creator/participants)

# --- create_event_db ---
def create_event_db(
        cursor: psycopg2.extensions.cursor, community_id: int, creator_id: int, title: str,
        description: Optional[str], location: str, event_timestamp: datetime,
        max_participants: int, image_url: Optional[str]
) -> Optional[Dict[str, Any]]:
    """Creates event in public.events, :Event vertex, :CREATED and :PARTICIPATED_IN edges."""
    event_id = None
    try:
        # 1. Insert into relational
        cursor.execute(
            """
            INSERT INTO public.events (community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id, created_at;
            """,
            (community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url)
        )
        result = cursor.fetchone()
        if not result: raise psycopg2.DatabaseError("Event insert failed")
        event_id = result['id']
        created_at = result['created_at']
        print(f"Inserted event {event_id} into public.events.")

        # 2. Create :Event vertex
        event_props = {'id': event_id, 'title': title, 'event_timestamp': event_timestamp}
        set_clauses_str = build_cypher_set_clauses('e', event_props)
        cypher_q_vertex = f"CREATE (e:Event {{id: {event_id}}})"
        if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
        execute_cypher(cursor, cypher_q_vertex)
        print(f"AGE vertex created for event {event_id}.")

        # 3. Create :CREATED edge (User -> Event)
        created_at_quoted = quote_cypher_string(created_at)
        cypher_q_created = f"""
            MATCH (u:User {{id: {creator_id}}})
            MATCH (e:Event {{id: {event_id}}})
            MERGE (u)-[r:CREATED]->(e)
            SET r.created_at = {created_at_quoted}
        """
        execute_cypher(cursor, cypher_q_created)
        print(f":CREATED edge created for event {event_id}.")

        # 4. Add creator as participant
        cypher_q_participated = f"""
            MATCH (u:User {{id: {creator_id}}})
            MATCH (e:Event {{id: {event_id}}})
            MERGE (u)-[r:PARTICIPATED_IN]->(e)
            SET r.joined_at = {created_at_quoted} -- Use creation time
        """
        execute_cypher(cursor, cypher_q_participated)
        print(f"Creator {creator_id} added as participant for event {event_id}.")

        # Return ID and created_at for router
        return {'id': event_id, 'created_at': created_at}
    except Exception as e:
        print(f"ERROR in create_event_db (ID: {event_id if event_id else 'N/A'}): {e}")
        raise

# --- get_event_details_db (fetch relational + graph counts) ---
# Keep name, change logic
def get_event_details_db(cursor: psycopg2.extensions.cursor, event_id: int) -> Optional[Dict[str, Any]]:
    """Fetches event details from public.events AND participant count from graph."""
    # 1. Fetch relational data
    cursor.execute(
        """SELECT id, community_id, creator_id, title, description, location,
                  event_timestamp, max_participants, image_url, created_at
           FROM public.events WHERE id = %s""",
        (event_id,)
    )
    event_relational = cursor.fetchone()
    if not event_relational:
        return None

    # 2. Fetch participant count from graph
    cypher_q_count = f"""
        MATCH (e:Event {{id: {event_id}}})<-[r:PARTICIPATED_IN]-(p:User)
        RETURN count(DISTINCT p) as participant_count
    """
    count_agtype = execute_cypher(cursor, cypher_q_count, fetch_one=True)
    count_map = parse_agtype(count_agtype)
    participant_count = int(count_map.get('participant_count', 0)) if isinstance(count_map, dict) else 0

    # 3. Combine
    combined_data = dict(event_relational)
    combined_data['participant_count'] = participant_count
    return combined_data

# --- get_events_for_community_db (fetch relational list + graph counts) ---
# Keep name, change logic
def get_events_for_community_db(cursor: psycopg2.extensions.cursor, community_id: int) -> List[Dict[str, Any]]:
    """Fetches events list from public.events, augments with participant count from graph."""
    # 1. Fetch relational list
    cursor.execute(
        """SELECT id, community_id, creator_id, title, description, location,
                  event_timestamp, max_participants, image_url, created_at
           FROM public.events WHERE community_id = %s ORDER BY event_timestamp ASC""",
        (community_id,)
    )
    events_relational = cursor.fetchall()

    # 2. Augment with counts (could be done more efficiently with a single graph query later)
    augmented_events = []
    for event_rel in events_relational:
        event_data = dict(event_rel)
        event_id = event_data['id']
        # Fetch count for this event
        cypher_q_count = f"MATCH (e:Event {{id: {event_id}}})<-[:PARTICIPATED_IN]-(p:User) RETURN count(p) as c"
        count_ag = execute_cypher(cursor, cypher_q_count, fetch_one=True)
        count_map = parse_agtype(count_ag)
        event_data['participant_count'] = int(count_map.get('c', 0)) if isinstance(count_map, dict) else 0
        augmented_events.append(event_data)

    return augmented_events

# --- update_event_db ---
def update_event_db(cursor: psycopg2.extensions.cursor, event_id: int, update_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Updates event in public.events AND :Event vertex properties."""
    # Logic similar to update_user_profile / update_community_details
    relational_set_clauses = []
    relational_params = []
    graph_props_to_update = {}

    allowed_relational = ['title', 'description', 'location', 'event_timestamp', 'max_participants', 'image_url']
    allowed_graph = ['title', 'event_timestamp'] # Props stored in graph

    for key, value in update_data.items():
        if key in allowed_relational:
            relational_set_clauses.append(f"{key} = %s")
            relational_params.append(value)
        if key in allowed_graph:
            graph_props_to_update[key] = value

    try:
        rows_affected = 0
        if relational_set_clauses:
            relational_params.append(event_id)
            sql = f"UPDATE public.events SET {', '.join(relational_set_clauses)} WHERE id = %s;"
            cursor.execute(sql, tuple(relational_params))
            rows_affected = cursor.rowcount
            print(f"Updated public.events for ID {event_id}.")
        else:
            cursor.execute("SELECT 1 FROM public.events WHERE id = %s", (event_id,))
            if cursor.fetchone(): rows_affected = 1
            else: return None # Event doesn't exist

        if graph_props_to_update and rows_affected > 0:
            set_clauses_str = build_cypher_set_clauses('e', graph_props_to_update)
            if set_clauses_str:
                cypher_q = f"MATCH (e:Event {{id: {event_id}}}) SET {set_clauses_str}"
                execute_cypher(cursor, cypher_q)
                print(f"Updated AGE vertex for event {event_id}.")

        if rows_affected > 0:
            # Fetch updated data to return (uses combined fetch)
            return get_event_details_db(cursor, event_id)
        else:
            return None

    except Exception as e:
        print(f"ERROR in update_event_db (ID: {event_id}): {e}")
        raise

# --- delete_event_db ---
def delete_event_db(cursor: psycopg2.extensions.cursor, event_id: int) -> bool:
    """Deletes event from public.events AND AGE graph."""
    try:
        # 1. Delete from AGE graph
        cypher_q = f"MATCH (e:Event {{id: {event_id}}}) DETACH DELETE e"
        execute_cypher(cursor, cypher_q)
        print(f"AGE vertex deleted for event {event_id}.")

        # 2. Delete from relational table
        cursor.execute("DELETE FROM public.events WHERE id = %s;", (event_id,))
        rows_deleted = cursor.rowcount
        print(f"Deleted event {event_id} from public.events (Rows affected: {rows_deleted}).")

        return rows_deleted > 0
    except Exception as e:
        print(f"ERROR in delete_event_db (ID: {event_id}): {e}")
        raise

# --- join_event_db (Graph operation) ---
def join_event_db(cursor: psycopg2.extensions.cursor, event_id: int, user_id: int) -> bool:
    """Creates :PARTICIPATED_IN edge in AGE graph."""
    now_iso = datetime.now(timezone.utc).isoformat()
    joined_at_quoted = quote_cypher_string(now_iso)
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (e:Event {{id: {event_id}}})
        MERGE (u)-[r:PARTICIPATED_IN]->(e)
        SET r.joined_at = {joined_at_quoted}
    """
    try:
        execute_cypher(cursor, cypher_q)
        return True
    except Exception as e:
        print(f"Error joining event (U:{user_id}, E:{event_id}): {e}")
        raise

# --- leave_event_db (Graph operation) ---
def leave_event_db(cursor: psycopg2.extensions.cursor, event_id: int, user_id: int) -> bool:
    """Deletes :PARTICIPATED_IN edge in AGE graph."""
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[r:PARTICIPATED_IN]->(e:Event {{id: {event_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    try:
        result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
        result_map = parse_agtype(result_agtype)
        deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
        return deleted_count > 0
    except Exception as e:
        print(f"Error leaving event (U:{user_id}, E:{event_id}): {e}")
        raise

# --- get_event_participant_count (Now redundant, use get_event_details_db) ---
# def get_event_participant_count(...) -> REMOVE

# =========================================
# Chat CRUD (Remains Relational - No changes needed for AGE)
# =========================================
def create_chat_message_db(cursor: psycopg2.extensions.cursor, user_id: int, content: str, community_id: Optional[int], event_id: Optional[int]) -> Optional[Dict[str, Any]]:
    """Saves a chat message to the database."""
    try:
        cursor.execute(
            """
            INSERT INTO public.chat_messages (community_id, event_id, user_id, content)
            VALUES (%s, %s, %s, %s) RETURNING id, timestamp;
            """,
            (community_id, event_id, user_id, content)
        )
        result = cursor.fetchone()
        if not result: return None

        cursor.execute("SELECT username FROM public.users WHERE id = %s", (user_id,))
        user_info = cursor.fetchone()
        username = user_info['username'] if user_info else "Unknown"

        return {
            "message_id": result["id"], "community_id": community_id,
            "event_id": event_id, "user_id": user_id, "username": username,
            "content": content, "timestamp": result["timestamp"]
        }
    except Exception as e:
        print(f"Error in create_chat_message_db: {e}")
        raise

def get_chat_messages_db(cursor: psycopg2.extensions.cursor, community_id: Optional[int], event_id: Optional[int], limit: int, before_id: Optional[int]) -> List[Dict[str, Any]]:
    """Fetches chat messages for a community or event."""
    # Note: This query might need adjustment if events can belong to communities
    # and you want to show community messages in an event chat.
    # Current logic assumes strictly community OR event messages.
    query = """
        SELECT m.id as message_id, m.community_id, m.event_id, m.user_id, m.content, m.timestamp,
               u.username
        FROM public.chat_messages m
        JOIN public.users u ON m.user_id = u.id
        WHERE """
    params = []
    filters = []

    if event_id is not None:
        filters.append("m.event_id = %s")
        params.append(event_id)
    elif community_id is not None:
        filters.append("m.community_id = %s AND m.event_id IS NULL") # Only general community messages
        params.append(community_id)
    else:
        return [] # Must provide community or event ID

    if before_id is not None:
        filters.append("m.id < %s")
        params.append(before_id)

    query += " AND ".join(filters)
    query += " ORDER BY m.id DESC LIMIT %s;" # Order by ID DESC for pagination
    params.append(limit)

    cursor.execute(query, tuple(params))
    # Return in reverse chronological order (newest first)
    return cursor.fetchall()