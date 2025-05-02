# backend/src/crud/_community.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and quote helper from the _graph module
from ._graph import execute_cypher, build_cypher_set_clauses, get_graph_counts
from .. import utils # Import root utils for quote_cypher_string if needed

# =========================================
# Community CRUD (Relational + Graph)
# =========================================

def create_community_db(
    cursor: psycopg2.extensions.cursor, name: str, description: Optional[str],
    created_by: int, primary_location_str: str, interest: Optional[str],
    logo_path: Optional[str]
) -> Optional[int]:
    """
    Creates community in public.communities, :Community vertex,
    :CREATED edge (User->Community), and :MEMBER_OF edge (Creator->Community).
    Requires CALLING function to handle transaction commit/rollback.
    """
    community_id = None
    # No try/except here, let caller handle transaction
    # 1. Insert into relational table
    cursor.execute(
        """
        INSERT INTO public.communities (name, description, created_by, primary_location, interest, logo_path)
        VALUES (%s, %s, %s, %s::point, %s, %s) RETURNING id, created_at;
        """,
        (name, description, created_by, primary_location_str, interest, logo_path),
    )
    result = cursor.fetchone()
    if not result or 'id' not in result: return None
    community_id = result['id']
    created_at = result['created_at'] # Get timestamp for graph edges
    print(f"CRUD: Inserted community {community_id} into public.communities.")

    # 2. Create :Community vertex
    # Properties stored in graph node (keep minimal - id, name, interest?)
    comm_props = {'id': community_id, 'name': name, 'interest': interest}
    set_clauses_str = build_cypher_set_clauses('c', comm_props)
    cypher_q_vertex = f"CREATE (c:Community {{id: {community_id}}})" # Use CREATE
    if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
    print(f"CRUD: Creating AGE vertex for community {community_id}...")
    execute_cypher(cursor, cypher_q_vertex) # Assumes raises on error
    print(f"CRUD: AGE vertex created for community {community_id}.")

    # 3. Create :CREATED edge (User -> Community)
    created_at_quoted = utils.quote_cypher_string(created_at)
    cypher_q_created = f"""
        MATCH (u:User {{id: {created_by}}})
        MATCH (c:Community {{id: {community_id}}})
        MERGE (u)-[r:CREATED]->(c)
        SET r.created_at = {created_at_quoted}
    """
    execute_cypher(cursor, cypher_q_created)
    print(f"CRUD: :CREATED edge created for community {community_id}.")

    # 4. Add creator as member (:MEMBER_OF edge)
    cypher_q_member = f"""
        MATCH (u:User {{id: {created_by}}})
        MATCH (c:Community {{id: {community_id}}})
        MERGE (u)-[r:MEMBER_OF]->(c)
        SET r.joined_at = {created_at_quoted} -- Use creation time as join time
    """
    execute_cypher(cursor, cypher_q_member)
    print(f"CRUD: Creator {created_by} added as member of community {community_id}.")

    return community_id # Return ID on success

def get_community_by_id(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
    """Fetches community details from relational table ONLY."""
    # Counts and graph-specific data fetched separately
    cursor.execute(
        """SELECT id, name, description, created_by, created_at,
                  primary_location, interest, logo_path
           FROM public.communities WHERE id = %s""",
        (community_id,)
    )
    return cursor.fetchone()

def get_communities_db(cursor: psycopg2.extensions.cursor) -> List[Dict[str, Any]]:
    """Fetches list of communities from relational table ONLY."""
    # Counts will be added by graph queries in the router if needed
    query = """
        SELECT id, name, description, created_by, created_at,
               primary_location, interest, logo_path
        FROM public.communities
        ORDER BY created_at DESC;
    """
    cursor.execute(query)
    return cursor.fetchall()

# --- Fetch community counts from graph ---
def get_community_counts(cursor: psycopg2.extensions.cursor, community_id: int) -> Dict[str, int]:
    """Fetches member count (and potentially online count) from AGE graph."""
    # Extend this later if online status is reliably added to :User nodes
    count_specs = [
        {'name': 'member_count', 'pattern': '(m:User)-[:MEMBER_OF]->(n)', 'distinct_var': 'm'}
        # {'name': 'online_count', 'pattern': '(o:User)-[:MEMBER_OF]->(n) WHERE o.last_seen_epoch > ...', 'distinct_var': 'o'}
    ]
    return get_graph_counts(cursor, 'Community', community_id, count_specs)

def update_community_details_db(
    cursor: psycopg2.extensions.cursor,
    community_id: int,
    update_data: Dict[str, Any] # Expect Pydantic model dump exclude_unset=True from router
) -> bool:
    """Updates community in public.communities AND :Community vertex properties."""
    relational_set_clauses = []
    relational_params = []
    graph_props_to_update = {}

    # Define which fields belong where
    allowed_relational_fields = ['name', 'description', 'primary_location', 'interest', 'logo_path']
    # Properties stored in the AGE :Community node
    allowed_graph_props = ['name', 'interest']

    for key, value in update_data.items():
        # Update Relational Table
        if key in allowed_relational_fields:
            if key == 'primary_location':
                # Ensure value is formatted correctly, use helper if needed
                # Assuming router sends correct "(lon,lat)" string
                formatted_loc = utils.format_location_for_db(str(value)) # Add safety format
                relational_set_clauses.append(f"primary_location = %s::point")
                relational_params.append(formatted_loc)
            else:
                relational_set_clauses.append(f"{key} = %s")
                relational_params.append(value)

        # Check if graph property needs update
        if key in allowed_graph_props:
            graph_props_to_update[key] = value

    # Execute updates within caller's transaction
    rows_affected = 0
    # 1. Update Relational Table
    if relational_set_clauses:
        relational_params.append(community_id)
        sql = f"UPDATE public.communities SET {', '.join(relational_set_clauses)} WHERE id = %s;"
        cursor.execute(sql, tuple(relational_params))
        rows_affected = cursor.rowcount
        print(f"CRUD: Updated public.communities for ID {community_id}.")
    else:
        # Check existence if only graph props might change
        cursor.execute("SELECT 1 FROM public.communities WHERE id = %s", (community_id,))
        if cursor.fetchone(): rows_affected = 1
        else: print(f"CRUD Warning: Community {community_id} not found for update."); return False

    # 2. Update AGE Graph Vertex
    if graph_props_to_update and rows_affected > 0:
        set_clauses_str = build_cypher_set_clauses('c', graph_props_to_update)
        if set_clauses_str:
            cypher_q = f"MATCH (c:Community {{id: {community_id}}}) SET {set_clauses_str}"
            execute_cypher(cursor, cypher_q)
            print(f"CRUD: Updated AGE vertex for community {community_id}.")

    return rows_affected > 0

def update_community_logo_path_db(cursor: psycopg2.extensions.cursor, community_id: int, logo_path: Optional[str]) -> bool:
    """ Updates only the logo_path in the relational table. """
    # Graph vertex doesn't store logo_path in this design
    cursor.execute(
        "UPDATE public.communities SET logo_path = %s WHERE id = %s;",
        (logo_path, community_id)
    )
    return cursor.rowcount > 0

# --- Keep trending relational for now ---
def get_trending_communities_db(cursor: psycopg2.extensions.cursor) -> List[Dict[str, Any]]:
     """Fetches trending communities (using relational joins/subqueries)."""
     # This query joins on the *old* relational tables for counts.
     # TODO: Refactor this later to use graph counts if performance allows or needed.
     # For now, keep using the PUBLIC tables for counts as they still exist pre-drop.
     # If tables are dropped, this query MUST be rewritten using graph counts.
     query = """
        SELECT
            c.id, c.name, c.description, c.interest, c.primary_location, c.logo_path, c.created_by, c.created_at,
            (COALESCE(recent_members.count, 0) + COALESCE(recent_posts.count, 0)) AS recent_activity_score,
            COALESCE(total_members.count, 0) as member_count
        FROM public.communities c
        LEFT JOIN (
            SELECT community_id, COUNT(*) as count FROM public.community_members -- Uses public table
            WHERE joined_at >= NOW() - INTERVAL '48 hours' GROUP BY community_id
        ) AS recent_members ON c.id = recent_members.community_id
        LEFT JOIN (
            SELECT cp.community_id, COUNT(*) as count FROM public.community_posts cp -- Uses public table
            JOIN public.posts p ON cp.post_id = p.id
            WHERE p.created_at >= NOW() - INTERVAL '48 hours' GROUP BY cp.community_id
        ) AS recent_posts ON c.id = recent_posts.community_id
        LEFT JOIN (
             SELECT community_id, COUNT(*) as count FROM public.community_members GROUP BY community_id -- Uses public table
        ) AS total_members ON c.id = total_members.community_id
        ORDER BY recent_activity_score DESC, c.created_at DESC
        LIMIT 15;
     """
     cursor.execute(query)
     return cursor.fetchall()


def get_community_details_db(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
    """Fetches detailed community data from relational AND graph counts."""
    community_relational = get_community_by_id(cursor, community_id)
    if not community_relational: return None
    counts = get_community_counts(cursor, community_id) # Fetch counts from graph
    combined_data = dict(community_relational)
    combined_data.update(counts)
    return combined_data


def delete_community_db(cursor: psycopg2.extensions.cursor, community_id: int) -> bool:
    """Deletes community from public.communities AND AGE graph."""
    # 1. Delete from AGE graph
    cypher_q = f"MATCH (c:Community {{id: {community_id}}}) DETACH DELETE c"
    print(f"CRUD: Deleting AGE vertex for community {community_id}...")
    execute_cypher(cursor, cypher_q)
    print(f"CRUD: AGE vertex deleted for community {community_id}.")

    # 2. Delete from relational table
    cursor.execute("DELETE FROM public.communities WHERE id = %s;", (community_id,))
    rows_deleted = cursor.rowcount
    print(f"CRUD: Deleted community {community_id} from public.communities (Rows: {rows_deleted}).")

    return rows_deleted > 0

# --- Graph Operations for Membership/Posts ---

def join_community_db(cursor: psycopg2.extensions.cursor, user_id: int, community_id: int) -> bool:
    """Creates :MEMBER_OF edge in AGE graph."""
    now_iso = datetime.now(timezone.utc).isoformat()
    joined_at_quoted = utils.quote_cypher_string(now_iso)
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (c:Community {{id: {community_id}}})
        MERGE (u)-[r:MEMBER_OF]->(c)
        SET r.joined_at = {joined_at_quoted}
    """
    # Assumes execute_cypher raises on error
    execute_cypher(cursor, cypher_q)
    return True # Indicate relationship exists/was created

def leave_community_db(cursor: psycopg2.extensions.cursor, user_id: int, community_id: int) -> bool:
    """Deletes :MEMBER_OF edge in AGE graph."""
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[r:MEMBER_OF]->(c:Community {{id: {community_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
    # If MATCH fails, result_agtype is None
    if result_agtype is None: return False
    result_map = utils.parse_agtype(result_agtype)
    deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
    return deleted_count > 0

def add_post_to_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> bool:
    """Creates :HAS_POST edge from Community to Post."""
    now_iso = datetime.now(timezone.utc).isoformat()
    added_at_quoted = utils.quote_cypher_string(now_iso)
    cypher_q = f"""
        MATCH (c:Community {{id: {community_id}}})
        MATCH (p:Post {{id: {post_id}}})
        MERGE (c)-[r:HAS_POST]->(p)
        SET r.added_at = {added_at_quoted}
    """
    execute_cypher(cursor, cypher_q)
    return True

def remove_post_from_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> bool:
    """Deletes :HAS_POST edge between Community and Post."""
    cypher_q = f"""
        MATCH (c:Community {{id: {community_id}}})-[r:HAS_POST]->(p:Post {{id: {post_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
    if result_agtype is None: return False
    result_map = utils.parse_agtype(result_agtype)
    deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
    return deleted_count > 0
