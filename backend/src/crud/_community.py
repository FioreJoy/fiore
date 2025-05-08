# backend/src/crud/_community.py
import traceback

import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone
import re

from ._graph import execute_cypher, build_cypher_set_clauses
from .. import utils

def create_community_db(
        cursor: psycopg2.extensions.cursor, name: str, description: Optional[str],
        created_by: int, interest: Optional[str],
        location_address: Optional[str] = None,
        location_coords_wkt: Optional[str] = None
) -> Optional[int]:
    community_id = None
    try:
        sql_insert_community = """
            INSERT INTO public.communities (name, description, created_by, interest, location_address, location)
            VALUES (%s, %s, %s, %s, %s, CASE WHEN %s IS NOT NULL THEN ST_SetSRID(ST_GeomFromText(%s), 4326) ELSE NULL END) 
            RETURNING id, created_at;
        """
        params_insert_community = (
            name, description, created_by, interest, location_address,
            location_coords_wkt, location_coords_wkt
        )
        cursor.execute(sql_insert_community, params_insert_community)
        result = cursor.fetchone()
        if not result or 'id' not in result: return None
        community_id = result['id']
        created_at = result['created_at']
        print(f"CRUD: Inserted community {community_id}. Address: '{location_address}', Coords WKT: {location_coords_wkt}")

        comm_props = {'id': community_id, 'name': name, 'interest': interest}
        if location_coords_wkt:
            try:
                coords_match = re.match(r"POINT\s*\(\s*([-\d\.]+)\s+([-\d\.]+)\s*\)", location_coords_wkt, re.IGNORECASE)
                if coords_match:
                    comm_props['longitude'] = float(coords_match.group(1))
                    comm_props['latitude'] = float(coords_match.group(2))
            except: # nosec
                pass

        set_clauses_str = build_cypher_set_clauses('c', comm_props)
        cypher_q_vertex = f"CREATE (c:Community {{id: {community_id}}})"
        if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
        execute_cypher(cursor, cypher_q_vertex)

        created_at_quoted = utils.quote_cypher_string(created_at)
        cypher_q_edge = f"""
            MATCH (u:User {{id: {created_by}}}) MATCH (c:Community {{id: {community_id}}})
            MERGE (u)-[r:CREATED]->(c) SET r.created_at = {created_at_quoted}
        """
        execute_cypher(cursor, cypher_q_edge)

        joined_at_quoted = utils.quote_cypher_string(created_at)
        cypher_q_member = f"""
            MATCH (u:User {{id: {created_by}}}) MATCH (c:Community {{id: {community_id}}})
            MERGE (u)-[r:MEMBER_OF]->(c) SET r.joined_at = {joined_at_quoted}
        """
        execute_cypher(cursor, cypher_q_member)
        return community_id
    except psycopg2.Error as db_err:
        print(f"CRUD DB Error creating community: {db_err}")
        raise
    except Exception as e:
        print(f"CRUD Unexpected error creating community: {e}")
        raise

def get_community_by_id(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
    cursor.execute(
        """SELECT id, name, description, created_by, created_at,
                  interest, location_address, 
                  ST_X(location::geometry) as longitude, 
                  ST_Y(location::geometry) as latitude
           FROM public.communities WHERE id = %s""",
        (community_id,)
    )
    return cursor.fetchone()

def get_communities_db(cursor: psycopg2.extensions.cursor, limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
    query = """
        SELECT id, name, description, created_by, created_at,
               interest, location_address, 
               ST_X(location::geometry) as longitude, 
               ST_Y(location::geometry) as latitude
        FROM public.communities
        ORDER BY created_at DESC
        LIMIT %s OFFSET %s;
    """
    cursor.execute(query, (limit, offset))
    return cursor.fetchall()

def get_community_counts(cursor: psycopg2.extensions.cursor, community_id: int) -> Dict[str, int]:
    cypher_m = f"MATCH (member:User)-[:MEMBER_OF]->(c:Community {{id: {community_id}}}) RETURN count(member) as m_count"
    expected = [('m_count', 'agtype')]
    member_count = 0
    try:
        res_m = execute_cypher(cursor, cypher_m, fetch_one=True, expected_columns=expected)
        member_count = int(res_m.get('m_count', 0)) if res_m else 0
    except Exception as e: print(f"Warning: Failed getting member count for C:{community_id}: {e}")
    return {"member_count": member_count, "online_count": 0}

def check_is_member(cursor: psycopg2.extensions.cursor, viewer_id: int, community_id: int) -> bool:
    cypher_q = f"MATCH (viewer:User {{id: {viewer_id}}})-[:MEMBER_OF]->(community:Community {{id: {community_id}}}) RETURN viewer.id as vid"
    expected_cols_check_member = [('vid', 'agtype')]
    try:
        result = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected_cols_check_member)
        return result is not None and result.get('vid') is not None
    except Exception as e: print(f"Error checking membership (U:{viewer_id}-C:{community_id}): {e}"); return False

def get_community_members_graph(cursor: psycopg2.extensions.cursor, community_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    cypher_q = f"""
        MATCH (u:User)-[:MEMBER_OF]->(c:Community {{id: {community_id}}})
        RETURN u.id as id, u.username as username, u.name as name, u.image_path as image_path
        ORDER BY u.username SKIP {offset} LIMIT {limit}
    """
    expected_cols_members_graph = [('id', 'agtype'), ('username', 'agtype'), ('name', 'agtype'), ('image_path', 'agtype')]
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols_members_graph) or []
        return [r for r in results if isinstance(r, dict)]
    except Exception as e: print(f"CRUD Error getting community members graph for C:{community_id}: {e}"); raise

def update_community_details_db(
        cursor: psycopg2.extensions.cursor,
        community_id: int,
        update_data: Dict[str, Any]
) -> bool:
    relational_set_clauses = []
    relational_params = []
    graph_props_to_update = {}

    allowed_relational_map = { # Map input keys to DB columns
        'name': 'name', 'description': 'description', 'interest': 'interest',
        'location_address': 'location_address' # Input 'location_address' maps to DB 'location_address'
    }
    allowed_graph_props = ['name', 'interest', 'longitude', 'latitude'] # Graph node properties

    for key, value in update_data.items():
        db_column = allowed_relational_map.get(key)
        if db_column:
            relational_set_clauses.append(f"{db_column} = %s")
            relational_params.append(value)

        if key == 'location_coords_wkt': # Special handling for geography column
            if value is not None:
                relational_set_clauses.append("location = ST_SetSRID(ST_GeomFromText(%s), 4326)")
                relational_params.append(value)
            else: # Allow clearing coords
                relational_set_clauses.append("location = NULL")

        # Update graph properties if relevant keys are present
        if key in allowed_graph_props:
            graph_props_to_update[key] = value
        elif key == 'location_coords_wkt' and value: # Parse WKT for graph lon/lat if provided
            try:
                coords_match = re.match(r"POINT\s*\(\s*([-\d\.]+)\s+([-\d\.]+)\s*\)", value, re.IGNORECASE)
                if coords_match:
                    graph_props_to_update['longitude'] = float(coords_match.group(1))
                    graph_props_to_update['latitude'] = float(coords_match.group(2))
            except: # nosec
                pass # Ignore parsing errors for graph props

    rows_affected = 0
    if not relational_set_clauses: # No direct field updates, check if community exists
        cursor.execute("SELECT 1 FROM public.communities WHERE id = %s", (community_id,))
        if cursor.fetchone(): rows_affected = 1 # User exists, no fields changed, but graph might
        else: return False # Community not found
    else:
        relational_params.append(community_id)
        sql = f"UPDATE public.communities SET {', '.join(relational_set_clauses)} WHERE id = %s;"
        cursor.execute(sql, tuple(relational_params))
        rows_affected = cursor.rowcount
        if rows_affected == 0: return False # Community not found or no changes made

    # Update graph properties if any are staged and DB update was successful
    if graph_props_to_update and rows_affected > 0:
        set_clauses_str = build_cypher_set_clauses('c', graph_props_to_update)
        if set_clauses_str:
            cypher_q_graph_update = f"MATCH (c:Community {{id: {community_id}}}) SET {set_clauses_str}"
            try:
                execute_cypher(cursor, cypher_q_graph_update)
                print(f"CRUD: AGE vertex updated for community {community_id}.")
            except Exception as age_err:
                print(f"CRUD WARNING: Failed updating AGE vertex for community {community_id}: {age_err}")
                # Continue even if graph update fails, as relational is primary
    return rows_affected > 0

def update_community_logo_path_db(cursor: psycopg2.extensions.cursor, community_id: int, logo_minio_path: Optional[str]) -> bool:
    try:
        media_id = None
        if logo_minio_path:
            cursor.execute("SELECT id FROM public.media_items WHERE minio_object_name = %s", (logo_minio_path,))
            media_item_result = cursor.fetchone()
            if media_item_result: media_id = media_item_result['id']
            else:
                print(f"CRUD WARN: Media item not found for MinIO path {logo_minio_path} during logo update.")
                return False # Media item for the path must exist

        if media_id:
            cursor.execute(
                """
                INSERT INTO public.community_logo (community_id, media_id, set_at)
                VALUES (%s, %s, NOW())
                ON CONFLICT (community_id) DO UPDATE SET
                  media_id = EXCLUDED.media_id,
                  set_at = NOW();
                """,
                (community_id, media_id)
            )
            return cursor.rowcount > 0
        else: # Removing logo
            cursor.execute("DELETE FROM public.community_logo WHERE community_id = %s;", (community_id,))
            return True # Idempotent delete considered success
    except psycopg2.Error as e:
        print(f"CRUD DB Error updating community logo link (C:{community_id}): {e}")
        raise
    except Exception as e:
        print(f"CRUD Unexpected Error updating community logo link (C:{community_id}): {e}")
        raise

def get_trending_communities_db(cursor: psycopg2.extensions.cursor, limit: int = 15) -> List[Dict[str, Any]]:
    query = f"""
        WITH RecentActivityScores AS (
            SELECT
                c.id as community_id,
                (COALESCE(recent_members.count, 0) * 2) + 
                (COALESCE(recent_posts.count, 0) * 3) +
                (COALESCE(recent_events.count, 0) * 5)
                AS activity_score
            FROM public.communities c
            LEFT JOIN (SELECT community_id, COUNT(*) as count FROM public.community_members WHERE joined_at >= NOW() - INTERVAL '72 hours' GROUP BY community_id) AS recent_members ON c.id = recent_members.community_id
            LEFT JOIN (SELECT cp.community_id, COUNT(*) as count FROM public.community_posts cp JOIN public.posts p ON cp.post_id = p.id WHERE p.created_at >= NOW() - INTERVAL '72 hours' GROUP BY cp.community_id) AS recent_posts ON c.id = recent_posts.community_id
            LEFT JOIN (SELECT community_id, COUNT(*) as count FROM public.events WHERE created_at >= NOW() - INTERVAL '72 hours' GROUP BY community_id) AS recent_events ON c.id = recent_events.community_id
        )
        SELECT
            c.id, c.name, c.description, c.interest, 
            c.location_address, -- text address
            c.created_by, c.created_at,
            ST_X(c.location::geometry) as longitude, 
            ST_Y(c.location::geometry) as latitude,
            COALESCE(ras.activity_score, 0) AS recent_activity_score
        FROM public.communities c
        LEFT JOIN RecentActivityScores ras ON c.id = ras.community_id
        ORDER BY recent_activity_score DESC, c.created_at DESC
        LIMIT %s;
     """
    cursor.execute(query, (limit,))
    return cursor.fetchall()

def get_community_details_db(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
    community_relational = get_community_by_id(cursor, community_id)
    if not community_relational: return None
    counts = get_community_counts(cursor, community_id)
    combined_data = dict(community_relational)
    combined_data.update(counts)
    return combined_data

def delete_community_db(cursor: psycopg2.extensions.cursor, community_id: int) -> bool:
    cypher_q = f"MATCH (c:Community {{id: {community_id}}}) DETACH DELETE c"
    try:
        execute_cypher(cursor, cypher_q)
    except Exception as age_err:
        print(f"CRUD WARNING: Failed to delete AGE vertex for community {community_id}: {age_err}")
        raise age_err
    cursor.execute("DELETE FROM public.communities WHERE id = %s;", (community_id,))
    return cursor.rowcount > 0

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

def get_community_member_ids(cursor: psycopg2.extensions.cursor, community_id: int, limit: int, offset: int) -> List[int]:
    cypher_q = f"""
        MATCH (u:User)-[:MEMBER_OF]->(c:Community {{id: {community_id}}})
        RETURN u.id as id, u.username as username
        ORDER BY u.username ASC
        SKIP {offset} LIMIT {limit}
    """
    # Note: Removed the problematic comment from here as well.
    expected_cols_member_ids = [('id', 'agtype'), ('username', 'agtype')]
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols_member_ids) or []
        return [int(r['id']) for r in results if isinstance(r, dict) and r.get('id') is not None]
    except Exception as e:
        print(f"CRUD Error getting community member IDs for C:{community_id}: {e}")
        # Re-raise if this is critical for a transaction
        # raise
        return []

def get_community_event_ids(cursor: psycopg2.extensions.cursor, community_id: int, limit: int, offset: int) -> List[int]:
    sql = """
        SELECT id FROM public.events
        WHERE community_id = %s
        ORDER BY event_timestamp DESC
        LIMIT %s OFFSET %s
    """
    try:
        cursor.execute(sql, (community_id, limit, offset))
        results = cursor.fetchall()
        return [row['id'] for row in results]
    except Exception as e:
        print(f"CRUD Error getting community event IDs for C:{community_id}: {e}")
        return []

def get_post_ids_for_community(cursor: psycopg2.extensions.cursor, community_id: int, limit: int, offset: int) -> List[int]:
    cypher_q = f"""
        MATCH (c:Community {{id: {community_id}}})-[:HAS_POST]->(p:Post)
        RETURN p.id as id, p.created_at as created_at
        ORDER BY p.created_at DESC
        SKIP {offset} LIMIT {limit}
    """
    expected_cols_post_ids = [('id', 'agtype'), ('created_at', 'agtype')]
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols_post_ids) or []
        return [int(r['id']) for r in results if isinstance(r, dict) and r.get('id') is not None]
    except Exception as e:
        print(f"CRUD Error getting post IDs for community {community_id}: {e}")
        return []

def get_nearby_communities_db(
        cursor: psycopg2.extensions.cursor,
        longitude: float, latitude: float, radius_meters: int,
        limit: int, offset: int
) -> List[Dict[str, Any]]:
    radius_meters_int = int(radius_meters)
    query = """
        SELECT 
            c.id, c.name, c.description, c.created_by, c.created_at, c.interest, 
            c.location_address, 
            ST_X(c.location::geometry) as longitude, 
            ST_Y(c.location::geometry) as latitude,
            ST_Distance(c.location, ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography) as distance_meters
        FROM public.communities c
        WHERE c.location IS NOT NULL AND ST_DWithin(
            c.location,
            ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography,
            %s 
        )
        ORDER BY distance_meters ASC, c.name ASC 
        LIMIT %s OFFSET %s;
    """
    params = (longitude, latitude, longitude, latitude, radius_meters_int, limit, offset)
    try:
        cursor.execute(query, params)
        return cursor.fetchall()
    except psycopg2.Error as db_err:
        print(f"CRUD DB Error fetching nearby communities: {db_err}")
        traceback.print_exc()
        raise
    except Exception as e:
        print(f"CRUD Unexpected error fetching nearby communities: {e}")
        traceback.print_exc()
        raise