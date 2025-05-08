# backend/src/crud/_user.py
import traceback

import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
import bcrypt
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses
from .. import utils
# Import media CRUD functions
from ._media import set_user_profile_picture, get_user_profile_picture_media # Keep this

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
    """
    Fetches user details from relational table.
    Includes 'current_location_address' (text) and derives 'longitude', 'latitude' from 'location' (geography).
    """
    cursor.execute(
        """SELECT id, name, username, email, gender,
                  college, interest, interests, -- Keep existing interest fields
                  created_at, last_seen,
                  notify_new_post_in_community, notify_new_reply_to_post,
                  notify_new_event_in_community, notify_event_reminder, notify_event_update,
                  notify_direct_message,
                  current_location_address, -- The text address column
                  location_last_updated,
                  ST_X(location::geometry) as longitude, -- Derived from geography 'location'
                  ST_Y(location::geometry) as latitude   -- Derived from geography 'location'
           FROM public.users WHERE id = %s;""",
        (user_id,)
    )
    return cursor.fetchone()

def create_user(
        cursor: psycopg2.extensions.cursor,
        name: str, username: str, email: str, password: str, gender: str,
        current_location_str: str, # Expects "(lon,lat)"
        college: str, interests_str: Optional[str], # interests_str is comma-separated for 'interest' column
        current_current_location_address: Optional[str]
        # interests_json: Optional[List[str]] # For 'interests' jsonb column
) -> Optional[int]:
    """
    Creates a user in public.users AND a corresponding :User vertex in AGE graph.
    Profile picture linking is handled separately.
    Requires the CALLING function to handle transaction commit/rollback.
    """
    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    user_id = None

    # Convert interests_str (comma-separated) to a JSONB-compatible list for the 'interests' column
    # The 'interest' text column might be legacy or for simpler single-choice interest.
    # The schema now has `interests jsonb`. We'll populate this from interests_str.
    interests_json_val = None
    if interests_str:
        interests_list = [i.strip() for i in interests_str.split(',') if i.strip()]
        if interests_list:
            interests_json_val = json.dumps(interests_list)


    # 1. Insert into relational table
    cursor.execute(
        """
        INSERT INTO public.users (
            name, username, email, password_hash, gender, 
            current_location, college, interest, interests, current_current_location_address
        )
        VALUES (%s, %s, %s, %s, %s, %s::point, %s, %s, %s, %s) RETURNING id;
        """,
        (name, username, email, hashed_password, gender,
         current_location_str, college, interests_str, interests_json_val, current_current_location_address)
    )
    result = cursor.fetchone()
    if not result or 'id' not in result: return None
    user_id = result['id']
    print(f"CRUD: Inserted user {user_id} into public.users.")

    # 2. Create vertex in AGE graph
    try:
        # Minimal graph props for User vertex. Add more if needed for graph-specific queries.
        user_props = {'id': user_id, 'username': username, 'name': name}
        # If you decide to store image_path on the graph vertex (derived from media table later):
        # user_props['image_path'] = None # Initialize, can be updated by another process if profile pic changes

        set_clauses_str = build_cypher_set_clauses('u', user_props)
        cypher_q = f"CREATE (u:User {{id: {user_id}}})"
        if set_clauses_str: cypher_q += f" SET {set_clauses_str}"
        print(f"CRUD: Creating AGE vertex for user {user_id}...")
        execute_cypher(cursor, cypher_q) # No expected_columns needed for CREATE
        print(f"CRUD: AGE vertex created for user {user_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed to create AGE vertex for new user {user_id}: {age_err}")
        # Decide: raise age_err # Or let it pass and log

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
    # `image_path` is not directly in `users` table. It's managed via `user_profile_picture` and `media_items`.
    # Routers should handle image updates by calling `crud.set_user_profile_picture`.
    allowed_relational_fields = [
        'name', 'username', 'gender', 'current_location', 'college',
        'interest', 'interests', 'current_current_location_address' # 'interests' for JSONB, 'interest' for text
    ]
    allowed_graph_props = ['username', 'name'] # Only update props that are actually on the User vertex

    for key, value in update_data.items():
        if key in allowed_relational_fields:
            clause_value = value
            if key == 'current_location':
                clause = f"{key} = %s::point"
            elif key == 'interests' and isinstance(value, list): # Handle JSONB update for 'interests'
                clause = f"{key} = %s::jsonb"
                clause_value = json.dumps(value) # Convert list to JSON string for psycopg2
            else:
                clause = f"{key} = %s"

            relational_set_clauses.append(clause)
            relational_params.append(clause_value)

        if key in allowed_graph_props:
            graph_props_to_update[key] = value

    rows_affected = 0
    # 1. Update Relational Table
    if relational_set_clauses:
        relational_params.append(user_id)
        sql = f"UPDATE public.users SET {', '.join(relational_set_clauses)} WHERE id = %s;"
        try:
            cursor.execute(sql, tuple(relational_params))
            rows_affected = cursor.rowcount
            print(f"CRUD: Updated public.users for user {user_id} (Rows affected: {rows_affected}).")
        except psycopg2.Error as e:
            print(f"CRUD ERROR updating public.users for user {user_id}: {e}")
            raise # Re-raise for transaction rollback
    else: # Check existence if only graph might change or no text fields were provided
        cursor.execute("SELECT 1 FROM public.users WHERE id = %s", (user_id,))
        if cursor.fetchone():
            rows_affected = 1 # User exists, even if no fields changed in this call
        else:
            print(f"CRUD Warning: User {user_id} not found for update.")
            return False

    # 2. Update AGE Graph Vertex (if there are graph-relevant props and relational update was successful or user exists)
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
                # Allow relational update to commit, but log this warning.
                # Depending on requirements, you might want to raise age_err to rollback.

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
    Media item deletion (profile pic, user-uploaded content) should be handled by the router.
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
    # CASCADE constraints in the DB should handle related records in tables like
    # community_members, event_participants, posts, replies, votes, user_followers, user_blocks etc.
    # Profile picture link in user_profile_picture should also be handled by CASCADE.
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
    expected = [('followers_count', 'int8'), ('following_count', 'int8')]
    try:
        result_map = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected)
        if isinstance(result_map, dict):
            return {
                "followers_count": result_map.get('followers_count', 0) or 0, # Ensure 0 if None
                "following_count": result_map.get('following_count', 0) or 0  # Ensure 0 if None
            }
        else: return {"followers_count": 0, "following_count": 0}
    except Exception as e:
        print(f"Warning: Failed getting counts for user {user_id}: {e}")
        return {"followers_count": 0, "following_count": 0}

def follow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    action_timestamp_iso = datetime.now(timezone.utc).isoformat()
    cypher_q = f"""
        MATCH (f:User {{id: {follower_id}}})
        MATCH (t:User {{id: {following_id}}})
        MERGE (f)-[r:FOLLOWS]->(t)
        SET r.followed_at = '{action_timestamp_iso}'
        RETURN r IS NOT NULL AS created_or_matched
    """
    expected_cols = [('created_or_matched', 'agtype')] # agtype can represent boolean
    try:
        print(f"CRUD follow_user: Executing for {follower_id} -> {following_id}")
        result = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected_cols)
        print(f"CRUD follow_user: MERGE result: {result}")
        # utils.parse_agtype should correctly parse the boolean value from agtype
        return result is not None and result.get('created_or_matched') is True
    except Exception as e:
        print(f"CRUD Error following user ({follower_id} -> {following_id}): {e}")
        traceback.print_exc()
        raise

def unfollow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    cypher_q = f"""
        MATCH (f:User {{id: {follower_id}}})-[r:FOLLOWS]->(t:User {{id: {following_id}}})
        DELETE r
    """
    # To confirm deletion, we'd ideally return something or check if the edge still exists.
    # For now, rely on execute_cypher raising an error for DB issues.
    # If MATCH fails, DELETE won't run and it won't error.
    # The router should handle the "not following" case by checking before calling.
    try:
        print(f"CRUD unfollow_user: Executing DELETE for {follower_id} -> {following_id}")
        execute_cypher(cursor, cypher_q) # Returns True on success (no DB error)
        print(f"CRUD unfollow_user: DELETE executed (assumed success if no error).")
        return True
    except Exception as e:
        print(f"CRUD Error unfollowing user ({follower_id} -> {following_id}): {e}")
        # If MATCH fails because the edge doesn't exist, this might not raise an error with execute_cypher.
        # The function could return False in such cases if detectable, or router checks pre-condition.
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

def get_following(cursor: psycopg2.extensions.cursor, user_id: int, limit: int = 500, offset: int = 0) -> List[Dict[str, Any]]: # Added limit/offset defaults
    # Fetch IDs and usernames from graph for correct ordering first
    id_username_query = f"""
        MATCH (u:User {{id: {user_id}}})-[:FOLLOWS]->(f:User)
        RETURN f.id as id, f.username as username 
        ORDER BY f.username 
        SKIP {offset} LIMIT {limit} 
    """
    expected_id_usernames = [('id', 'agtype'), ('username', 'agtype')]
    try:
        following_basic_info = execute_cypher(cursor, id_username_query, fetch_all=True, expected_columns=expected_id_usernames) or []
        following_ids = [int(m['id']) for m in following_basic_info if isinstance(m, dict) and m.get('id') is not None]

        if not following_ids: return []

        # Fetch full user details from relational table for these IDs
        sql_following_details = """
            SELECT id, name, username, email, gender, college, interest, interests,
                   location_address, location_last_updated,
                   ST_X(location::geometry) as longitude, 
                   ST_Y(location::geometry) as latitude
            FROM public.users WHERE id = ANY(%s);
        """ # Corrected column selection
        cursor.execute(sql_following_details, (following_ids,))
        users_detail_map = {row['id']: dict(row) for row in cursor.fetchall()}

        ordered_detailed_following = []
        for basic_info in following_basic_info:
            if isinstance(basic_info, dict) and basic_info.get('id') is not None:
                user_id_from_graph = int(basic_info['id'])
                if user_id_from_graph in users_detail_map:
                    ordered_detailed_following.append(users_detail_map[user_id_from_graph])
        return ordered_detailed_following
    except Exception as e:
        print(f"Error getting following for user {user_id}: {e}")
        traceback.print_exc()
        return []

def get_followers(cursor: psycopg2.extensions.cursor, user_id: int, limit: int = 500, offset: int = 0) -> List[Dict[str, Any]]: # Added limit/offset defaults
    id_username_query = f"""
        MATCH (f:User)-[:FOLLOWS]->(:User {{id: {user_id}}})
        RETURN f.id as id, f.username as username
        ORDER BY f.username
        SKIP {offset} LIMIT {limit}
    """
    expected_id_usernames_followers = [('id', 'agtype'), ('username', 'agtype')]
    try:
        follower_basic_info = execute_cypher(cursor, id_username_query, fetch_all=True, expected_columns=expected_id_usernames_followers) or []
        follower_ids = [int(m['id']) for m in follower_basic_info if isinstance(m, dict) and m.get('id') is not None]

        if not follower_ids: return []

        sql_followers_details = """
            SELECT id, name, username, email, gender, college, interest, interests,
                   location_address, location_last_updated,
                   ST_X(location::geometry) as longitude, 
                   ST_Y(location::geometry) as latitude
            FROM public.users WHERE id = ANY(%s);
        """ # Corrected column selection
        cursor.execute(sql_followers_details, (follower_ids,))
        users_detail_map = {row['id']: dict(row) for row in cursor.fetchall()}

        ordered_detailed_followers = []
        for basic_info in follower_basic_info:
            if isinstance(basic_info, dict) and basic_info.get('id') is not None:
                user_id_from_graph = int(basic_info['id'])
                if user_id_from_graph in users_detail_map:
                    ordered_detailed_followers.append(users_detail_map[user_id_from_graph])
        return ordered_detailed_followers
    except Exception as e:
        print(f"Error getting followers for user {user_id}: {e}")
        traceback.print_exc()
        return []

def get_user_joined_communities_graph(cursor: psycopg2.extensions.cursor, user_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    """Fetches basic info of communities joined by the user."""
    # Community vertex also doesn't store logo_path by default.
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
    # Event vertex also doesn't store image_url by default.
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
    expected = [('c_count', 'int8')]
    try:
        result = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected)
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

def get_post_ids_by_user(cursor: psycopg2.extensions.cursor, user_id: int, limit: int, offset: int) -> List[int]:
    """Fetches IDs of posts written by a user, ordered by creation time."""
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[:WROTE]->(p:Post)
        RETURN p.id as id, p.created_at as created_at
        ORDER BY created_at DESC
        SKIP {offset} LIMIT {limit}
    """
    expected_cols = [('id', 'agtype'), ('created_at', 'agtype')]
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols) or []
        return [int(r['id']) for r in results if isinstance(r, dict) and r.get('id') is not None]
    except Exception as e:
        print(f"CRUD Error getting post IDs by user {user_id}: {e}")
        return []

def get_community_ids_joined_by_user(cursor: psycopg2.extensions.cursor, user_id: int, limit: int, offset: int) -> List[int]:
    """Fetches IDs of communities joined by a user, ordered by name."""
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[:MEMBER_OF]->(c:Community)
        RETURN c.id as id, c.name as name
        ORDER BY name ASC
        SKIP {offset} LIMIT {limit}
    """
    expected_cols = [('id', 'agtype'), ('name', 'agtype')]
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols) or []
        return [int(r['id']) for r in results if isinstance(r, dict) and r.get('id') is not None]
    except Exception as e:
        print(f"CRUD Error getting community IDs joined by user {user_id}: {e}")
        return []

def get_event_ids_participated_by_user(cursor: psycopg2.extensions.cursor, user_id: int, limit: int, offset: int) -> List[int]:
    """Fetches IDs of events participated in by a user, ordered by event time."""
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[:PARTICIPATED_IN]->(e:Event)
        RETURN e.id as id, e.event_timestamp as event_time
        ORDER BY event_time DESC
        SKIP {offset} LIMIT {limit}
    """
    expected_cols = [('id', 'agtype'), ('event_time', 'agtype')]
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols) or []
        return [int(r['id']) for r in results if isinstance(r, dict) and r.get('id') is not None]
    except Exception as e:
        print(f"CRUD Error getting event IDs participated by user {user_id}: {e}")
        return []

# --- ADD THIS NEW FUNCTION ---
def get_nearby_users_db(
        cursor: psycopg2.extensions.cursor,
        longitude: float,
        latitude: float,
        radius_meters: int,
        limit: int,
        offset: int,
        viewer_id: Optional[int] = None # Optional: to check follow status
) -> List[Dict[str, Any]]:
    """
    Fetches users within a given radius from a point, ordered by distance.
    Includes basic profile info, location, and distance.
    Does NOT include image_url or follow status here, those are typically augmented by the router.
    """
    radius_meters_int = int(radius_meters)

    # Base query
    query = """
        SELECT 
            u.id, u.name, u.username, u.gender, u.college, u.interest, u.interests, -- Include interests JSONB
            u.current_location_address, u.location_last_updated,
            ST_X(u.location::geometry) as longitude, 
            ST_Y(u.location::geometry) as latitude,
            ST_Distance(u.location, ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography) as distance_meters
        FROM public.users u
        WHERE ST_DWithin(
            u.location,
            ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography,
            %s -- radius in meters
        )
    """
    params = [longitude, latitude, longitude, latitude, radius_meters_int]

    # Exclude the viewer themselves from nearby results if viewer_id is provided
    if viewer_id is not None:
        query += " AND u.id != %s"
        params.append(viewer_id)

    query += """
        ORDER BY distance_meters ASC, u.last_seen DESC NULLS LAST -- Prioritize closer and recently active users
        LIMIT %s OFFSET %s;
    """
    params.extend([limit, offset])

    try:
        cursor.execute(query, tuple(params))
        users_db = cursor.fetchall()

        # Process 'interests' (JSONB) from string to list if needed by Pydantic schema upon return
        # The RealDictCursor should handle JSONB to Python list/dict automatically.
        # If it comes back as a string, manual parsing would be:
        # results = []
        # for row_dict in users_db:
        #     if isinstance(row_dict.get('interests'), str):
        #      try:
        #                  row_dict['interests'] = json.loads(row_dict['interests'])
        #     except json.JSONDecodeError:
        #              row_dict['interests'] = [] # Fallback
        #      elif row_dict.get('interests') is None:
        #          row_dict['interests'] = []
        #     results.append(row_dict)
        # return results
        return users_db # RealDictCursor should convert JSONB to list of dicts/primitives

    except psycopg2.Error as db_err:
        print(f"CRUD DB Error fetching nearby users: {db_err}")
        traceback.print_exc()
        raise
    except Exception as e:
        print(f"CRUD Unexpected error fetching nearby users: {e}")
        traceback.print_exc()
        raise
# --- END OF NEW FUNCTION ---