# backend/src/crud/_community.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses
from .. import utils # Import root utils for quote_cypher_string and potentially get_minio_url if needed here
# Import media CRUD functions if needed (e.g., for delete cleanup) - though router usually handles this
# from ._media import get_community_logo_media, delete_media_item

# =========================================
# Community CRUD (Relational + Graph + Media Link)
# =========================================

def create_community_db(
        cursor: psycopg2.extensions.cursor, name: str, description: Optional[str],
        created_by: int, primary_location_str: str, interest: Optional[str]
        # Removed logo_path parameter
) -> Optional[int]:
    """
    Creates community in public.communities and :Community vertex, :CREATED edge.
    Logo linking is handled separately by the router.
    Requires CALLING function to handle transaction commit/rollback.
    Returns community ID on success.
    """
    community_id = None
    # No try/except here, let caller handle transaction
    # 1. Insert into relational table (without logo_path)
    cursor.execute(
        """
        INSERT INTO public.communities (name, description, created_by, primary_location, interest)
        VALUES (%s, %s, %s, %s::point, %s) RETURNING id, created_at;
        """,
        (name, description, created_by, primary_location_str, interest),
    )
    result = cursor.fetchone()
    if not result or 'id' not in result: return None
    community_id = result['id']
    created_at = result['created_at']
    print(f"CRUD: Inserted community {community_id} into public.communities.")

    # 2. Create :Community vertex
    try:
        comm_props = {'id': community_id, 'name': name, 'interest': interest} # Store searchable/linkable props
        set_clauses_str = build_cypher_set_clauses('c', comm_props)
        cypher_q_vertex = f"CREATE (c:Community {{id: {community_id}}})"
        if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
        print(f"CRUD: Creating AGE vertex for community {community_id}...")
        execute_cypher(cursor, cypher_q_vertex)
        print(f"CRUD: AGE vertex created for community {community_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed to create AGE vertex for new community {community_id}: {age_err}")
        # Allow relational part to succeed, router handles overall transaction

    # 3. Create :CREATED edge (User -> Community)
    try:
        created_at_quoted = utils.quote_cypher_string(created_at)
        cypher_q_edge = f"""
            MATCH (u:User {{id: {created_by}}})
            MATCH (c:Community {{id: {community_id}}})
            MERGE (u)-[r:CREATED]->(c)
            SET r.created_at = {created_at_quoted}
        """
        execute_cypher(cursor, cypher_q_edge)
        print(f"CRUD: :CREATED edge created for community {community_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed to create :CREATED edge for community {community_id}: {age_err}")
        # Allow relational part to succeed

    # 4. Add creator as member (:MEMBER_OF edge)
    try:
        joined_at_quoted = utils.quote_cypher_string(created_at)
        cypher_q_member = f"""
            MATCH (u:User {{id: {created_by}}})
            MATCH (c:Community {{id: {community_id}}})
            MERGE (u)-[r:MEMBER_OF]->(c)
            SET r.joined_at = {joined_at_quoted}
        """
        execute_cypher(cursor, cypher_q_member)
        print(f"CRUD: Creator {created_by} added as member of community {community_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed to add creator as member for community {community_id}: {age_err}")

    return community_id # Return ID

def get_community_by_id(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
    """Fetches community details from relational table ONLY. Logo/Counts fetched separately."""
    # Removed logo_path from SELECT
    cursor.execute(
        """SELECT id, name, description, created_by, created_at,
                  primary_location, interest
           FROM public.communities WHERE id = %s""",
        (community_id,)
    )
    return cursor.fetchone()

def get_communities_db(cursor: psycopg2.extensions.cursor) -> List[Dict[str, Any]]:
    """Fetches list of communities from relational table ONLY."""
    # Removed logo_path from SELECT
    query = """
        SELECT id, name, description, created_by, created_at,
               primary_location, interest
        FROM public.communities
        ORDER BY created_at DESC;
    """
    cursor.execute(query)
    return cursor.fetchall()

# --- Fetch community counts from graph (Python counting) ---
def get_community_counts(cursor: psycopg2.extensions.cursor, community_id: int) -> Dict[str, int]:
    """Fetches member count from AGE graph by counting fetched results."""
    counts = {"member_count": 0, "online_count": 0} # Online count TBD
    try:
        cypher_m = f"MATCH (member:User)-[:MEMBER_OF]->(c:Community {{id: {community_id}}}) RETURN member.id"
        res_m = execute_cypher(cursor, cypher_m, fetch_all=True) or []
        counts['member_count'] = len(res_m)
        # TODO: Add online count logic if needed
    except Exception as e:
        print(f"Warning: Failed getting counts for community {community_id}: {e}")
    return counts

# --- Check membership status ---
def check_is_member(cursor: psycopg2.extensions.cursor, viewer_id: int, community_id: int) -> bool:
    """Checks if viewer is member of community using graph."""
    cypher_q = f"MATCH (viewer:User {{id: {viewer_id}}})-[:MEMBER_OF]->(community:Community {{id: {community_id}}}) RETURN viewer.id"
    try:
        result = execute_cypher(cursor, cypher_q, fetch_one=True)
        return result is not None
    except Exception as e: print(f"Error checking membership (U:{viewer_id}-C:{community_id}): {e}"); return False

# --- Update Community Details ---
def update_community_details_db(
        cursor: psycopg2.extensions.cursor,
        community_id: int,
        update_data: Dict[str, Any] # Expect dict with only fields to update (NO logo)
) -> bool:
    """Updates community in public.communities AND :Community vertex properties."""
    relational_set_clauses = []
    relational_params = []
    graph_props_to_update = {}

    # logo_path removed
    allowed_relational_fields = ['name', 'description', 'primary_location', 'interest']
    allowed_graph_props = ['name', 'interest'] # Match props stored in graph node

    for key, value in update_data.items():
        if key in allowed_relational_fields:
            if key == 'primary_location':
                formatted_loc = utils.format_location_for_db(str(value))
                relational_set_clauses.append(f"primary_location = %s::point")
                relational_params.append(formatted_loc)
            else:
                relational_set_clauses.append(f"{key} = %s")
                relational_params.append(value)
        if key in allowed_graph_props:
            graph_props_to_update[key] = value

    rows_affected = 0
    # 1. Update Relational Table
    if relational_set_clauses:
        relational_params.append(community_id)
        sql = f"UPDATE public.communities SET {', '.join(relational_set_clauses)} WHERE id = %s;"
        cursor.execute(sql, tuple(relational_params))
        rows_affected = cursor.rowcount
        print(f"CRUD: Updated public.communities for ID {community_id}.")
    else:
        cursor.execute("SELECT 1 FROM public.communities WHERE id = %s", (community_id,))
        if cursor.fetchone(): rows_affected = 1
        else: print(f"CRUD Warning: Community {community_id} not found for update."); return False

    # 2. Update AGE Graph Vertex (Wrap in Try/Except)
    if graph_props_to_update and rows_affected > 0:
        set_clauses_str = build_cypher_set_clauses('c', graph_props_to_update)
        if set_clauses_str:
            cypher_q = f"MATCH (c:Community {{id: {community_id}}}) SET {set_clauses_str}"
            try:
                print(f"CRUD: Updating AGE vertex for community {community_id}...")
                execute_cypher(cursor, cypher_q)
                print(f"CRUD: AGE vertex updated for community {community_id}.")
            except Exception as age_err:
                print(f"CRUD WARNING: Failed updating AGE vertex for community {community_id}: {age_err}")
                # Allow relational update to commit

    return rows_affected > 0

# --- Remove update_community_logo_path_db ---
# Logo updates are handled by set_community_logo in _media.py and the router

# --- get_trending_communities_db (Keep relational version for now) ---
def get_trending_communities_db(cursor: psycopg2.extensions.cursor) -> List[Dict[str, Any]]:
    """Fetches trending communities (using relational joins/subqueries)."""
    # Needs update if community_members/community_posts tables are dropped
    # Assumes they still exist for now
    query = """
        SELECT
            c.id, c.name, c.description, c.interest, c.primary_location, c.created_by, c.created_at,
            -- Removed logo_path here, fetch separately
            (COALESCE(recent_members.count, 0) + COALESCE(recent_posts.count, 0)) AS recent_activity_score,
            COALESCE(total_members.count, 0) as member_count -- Keep SQL count for now
        FROM public.communities c
        LEFT JOIN (SELECT community_id, COUNT(*) as count FROM public.community_members WHERE joined_at >= NOW() - INTERVAL '48 hours' GROUP BY community_id) AS recent_members ON c.id = recent_members.community_id
        LEFT JOIN (SELECT cp.community_id, COUNT(*) as count FROM public.community_posts cp JOIN public.posts p ON cp.post_id = p.id WHERE p.created_at >= NOW() - INTERVAL '48 hours' GROUP BY cp.community_id) AS recent_posts ON c.id = recent_posts.community_id
        LEFT JOIN (SELECT community_id, COUNT(*) as count FROM public.community_members GROUP BY community_id) AS total_members ON c.id = total_members.community_id
        ORDER BY recent_activity_score DESC, c.created_at DESC
        LIMIT 15;
     """
    cursor.execute(query)
    return cursor.fetchall() # Returns list of dicts


# --- get_community_details_db (Combines relational + graph counts) ---
def get_community_details_db(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
    """Fetches detailed community data from relational AND graph counts."""
    community_relational = get_community_by_id(cursor, community_id)
    if not community_relational: return None
    counts = get_community_counts(cursor, community_id) # Fetch counts from graph
    combined_data = dict(community_relational)
    combined_data.update(counts)
    # Logo fetched separately by router using get_community_logo_media
    return combined_data


# --- delete_community_db ---
def delete_community_db(cursor: psycopg2.extensions.cursor, community_id: int) -> bool:
    """
    Deletes community from public.communities AND AGE graph.
    Requires CALLING function to handle logo deletion from MinIO/media tables.
    """
    # 1. Delete from AGE graph
    cypher_q = f"MATCH (c:Community {{id: {community_id}}}) DETACH DELETE c"
    print(f"CRUD: Deleting AGE vertex for community {community_id}...")
    try:
        execute_cypher(cursor, cypher_q)
        print(f"CRUD: AGE vertex deleted for community {community_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed to delete AGE vertex for community {community_id}: {age_err}")
        raise age_err # Fail the whole delete if graph delete fails

    # 2. Delete from relational table
    cursor.execute("DELETE FROM public.communities WHERE id = %s;", (community_id,))
    rows_deleted = cursor.rowcount
    print(f"CRUD: Deleted community {community_id} from public.communities (Rows: {rows_deleted}).")

    return rows_deleted > 0 # Return status


# --- Membership/Post Linking (Graph Operations - Keep as is) ---
def join_community_db(cursor: psycopg2.extensions.cursor, user_id: int, community_id: int) -> bool:
    now_iso = datetime.now(timezone.utc).isoformat()
    joined_at_quoted = utils.quote_cypher_string(now_iso)
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}}) MATCH (c:Community {{id: {community_id}}})
        MERGE (u)-[r:MEMBER_OF]->(c) SET r.joined_at = {joined_at_quoted} """
    try: return execute_cypher(cursor, cypher_q)
    except Exception as e: print(f"Error joining community: {e}"); return False

def leave_community_db(cursor: psycopg2.extensions.cursor, user_id: int, community_id: int) -> bool:
    cypher_q = f"MATCH (u:User {{id: {user_id}}})-[r:MEMBER_OF]->(c:Community {{id: {community_id}}}) DELETE r"
    try: return execute_cypher(cursor, cypher_q)
    except Exception as e: print(f"Error leaving community: {e}"); return False

def add_post_to_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> bool:
    now_iso = datetime.now(timezone.utc).isoformat()
    added_at_quoted = utils.quote_cypher_string(now_iso)
    cypher_q = f"""
        MATCH (c:Community {{id: {community_id}}}) MATCH (p:Post {{id: {post_id}}})
        MERGE (c)-[r:HAS_POST]->(p) SET r.added_at = {added_at_quoted} """
    try: return execute_cypher(cursor, cypher_q)
    except Exception as e: print(f"Error adding post to community: {e}"); return False

def remove_post_from_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> bool:
    cypher_q = f"MATCH (c:Community {{id: {community_id}}})-[r:HAS_POST]->(p:Post {{id: {post_id}}}) DELETE r"
    try: return execute_cypher(cursor, cypher_q)
    except Exception as e: print(f"Error removing post from community: {e}"); return False

# --- NEW: get_community_members_graph (Moved from _user.py or needs adding) ---
def get_community_members_graph(cursor: psycopg2.extensions.cursor, community_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    """Fetches members (basic User info) of a community from the AGE graph."""
    cypher_q = f"""
        MATCH (u:User)-[:MEMBER_OF]->(c:Community {{id: {community_id}}})
        RETURN u.id as id, u.username as username, u.name as name, u.image_path as image_path
        ORDER BY u.username SKIP {offset} LIMIT {limit}
    """
    expected_cols = [('id', 'agtype'), ('username', 'agtype'), ('name', 'agtype'), ('image_path', 'agtype')]
    try: return execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols) or []
    except Exception as e: print(f"CRUD Error getting community members graph for C:{community_id}: {e}"); raise