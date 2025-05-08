# backend/src/crud/_post.py
import traceback

import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses
from .. import utils # Import root utils for quote_cypher_string and potentially get_minio_url

# =========================================
# Post CRUD (Relational + Graph + Media Link)
# =========================================
def create_post_db(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        title: str,
        content: str,
) -> Optional[int]: # Removed community_id from direct params, handled by router
    post_id = None
    try:
        cursor.execute(
            """
            INSERT INTO public.posts (user_id, title, content)
            VALUES (%s, %s, %s) RETURNING id, created_at;
            """,
            (user_id, title, content),
        )
        result = cursor.fetchone()
        if not result or 'id' not in result: return None
        post_id = result['id']
        created_at = result['created_at']
        print(f"CRUD: Inserted post {post_id} into public.posts.")

        post_props = {'id': post_id, 'title': title, 'created_at': created_at}
        set_clauses_str = build_cypher_set_clauses('p', post_props)
        cypher_q_vertex = f"CREATE (p:Post {{id: {post_id}}})"
        if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
        execute_cypher(cursor, cypher_q_vertex)

        created_at_quoted = utils.quote_cypher_string(created_at)
        cypher_q_wrote = f"""
            MATCH (u:User {{id: {user_id}}})
            MATCH (p:Post {{id: {post_id}}})
            MERGE (u)-[r:WROTE]->(p)
            SET r.created_at = {created_at_quoted}
        """
        execute_cypher(cursor, cypher_q_wrote)
        return post_id
    except psycopg2.Error as db_err:
        print(f"CRUD DB Error creating post: {db_err}")
        raise
    except Exception as e:
        print(f"CRUD Unexpected error creating post: {e}")
        raise

def get_post_by_id(cursor: psycopg2.extensions.cursor, post_id: int) -> Optional[Dict[str, Any]]:
    cursor.execute(
        "SELECT id, user_id, content, title, created_at FROM public.posts WHERE id = %s",
        (post_id,)
    )
    return cursor.fetchone()

def get_post_counts(cursor: psycopg2.extensions.cursor, post_id: int) -> Dict[str, int]:
    cypher_q = f"""
        MATCH (p:Post {{id: {post_id}}})
        OPTIONAL MATCH (reply:Reply)-[:REPLIED_TO]->(p)
        OPTIONAL MATCH (upvoter:User)-[v_up:VOTED {{vote_type: true}}]->(p)
        OPTIONAL MATCH (downvoter:User)-[v_down:VOTED {{vote_type: false}}]->(p)
        OPTIONAL MATCH (favUser:User)-[:FAVORITED]->(p)
        RETURN count(DISTINCT reply) as reply_count,
               count(DISTINCT upvoter) as upvotes,
               count(DISTINCT downvoter) as downvotes,
               count(DISTINCT favUser) as favorite_count
    """
    # Corrected property access in OPTIONAL MATCH for votes
    expected_counts = [('reply_count', 'agtype'), ('upvotes', 'agtype'), ('downvotes', 'agtype'), ('favorite_count', 'agtype')]
    try:
        result_map = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected_counts)
        if isinstance(result_map, dict):
            return {
                "reply_count": int(result_map.get('reply_count', 0) or 0),
                "upvotes": int(result_map.get('upvotes', 0) or 0),
                "downvotes": int(result_map.get('downvotes', 0) or 0),
                "favorite_count": int(result_map.get('favorite_count', 0) or 0),
            }
        else: return {"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0}
    except Exception as e:
        print(f"Warning: Failed getting graph counts for post {post_id}: {e}")
        traceback.print_exc()
        return {"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0}

def get_posts_db(
        cursor: psycopg2.extensions.cursor,
        community_id: Optional[int] = None,
        user_id: Optional[int] = None,
        limit: int = 50,
        offset: int = 0
) -> List[Dict[str, Any]]:
    sql = """
        SELECT
            p.id, p.user_id, p.content, p.title, p.created_at,
            u.username AS author_name,
            u.id AS author_id,
            c.id as community_id,    -- This will be NULL if not linked via community_posts
            c.name as community_name -- This will be NULL if not linked
        FROM public.posts p
        JOIN public.users u ON p.user_id = u.id
        LEFT JOIN public.community_posts cp ON p.id = cp.post_id
        LEFT JOIN public.communities c ON cp.community_id = c.id
    """
    params = []
    filters = []
    if community_id is not None: filters.append("cp.community_id = %s"); params.append(community_id)
    if user_id is not None: filters.append("p.user_id = %s"); params.append(user_id)

    if filters: sql += " WHERE " + " AND ".join(filters)
    sql += " ORDER BY p.created_at DESC"
    sql += " LIMIT %s OFFSET %s;"
    params.extend([limit, offset])

    cursor.execute(sql, tuple(params))
    posts_relational = cursor.fetchall()

    augmented_posts = []
    for post_rel_dict in posts_relational:
        post_data = dict(post_rel_dict) # Ensure it's a mutable dict
        post_id = post_data['id']
        counts = {"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0}
        try:
            counts = get_post_counts(cursor, post_id)
        except Exception as e:
            print(f"CRUD Warning: Failed get counts for post {post_id}: {e}")
        post_data.update(counts)
        augmented_posts.append(post_data)
    return augmented_posts

def delete_post_db(cursor: psycopg2.extensions.cursor, post_id: int) -> bool:
    cypher_q = f"MATCH (p:Post {{id: {post_id}}}) DETACH DELETE p"
    try:
        execute_cypher(cursor, cypher_q)
    except Exception as age_err:
        print(f"CRUD WARNING: Failed delete AGE vertex for post {post_id}: {age_err}")
        raise age_err
    cursor.execute("DELETE FROM public.posts WHERE id = %s;", (post_id,))
    return cursor.rowcount > 0

def get_followed_posts_in_community_graph(
        cursor: psycopg2.extensions.cursor, viewer_id: int, community_id: int,
        limit: int, offset: int
) -> List[Dict[str, Any]]:
    # This query assumes Post nodes have 'created_at' property.
    cypher_ids = f"""
        MATCH (viewer:User {{id: {viewer_id}}})-[:FOLLOWS]->(author:User)-[:WROTE]->(p:Post)
        MATCH (:Community {{id: {community_id}}})-[:HAS_POST]->(p)
        RETURN p.id as id, author.id as author_id, p.created_at as post_created_at
        ORDER BY p.created_at DESC
        SKIP {offset}
        LIMIT {limit}
    """
    # Define expected columns for this specific query's RETURN statement
    expected_cols_followed = [('id', 'agtype'), ('author_id', 'agtype'), ('post_created_at', 'agtype')]
    try:
        post_author_ids_data = execute_cypher(cursor, cypher_ids, fetch_all=True, expected_columns=expected_cols_followed) or []
        results = []
        for item_data in post_author_ids_data: # item_data is a dict
            if not isinstance(item_data, dict) or 'id' not in item_data or 'author_id' not in item_data:
                continue
            post_id_val = item_data['id']
            author_id_val = item_data['author_id']

            post_details = get_post_by_id(cursor, post_id_val) # Fetch relational data
            # Need to import full crud to call crud.get_user_by_id etc.
            # For now, assuming these are simple dict lookups or simplified fetching:
            # This part might need adjustment based on how you want to structure calls between CRUD modules.
            # If calling other CRUD functions, ensure `from . import _user` etc. is present.
            # For this fix, we'll assume author_name and community_name are fetched via graph or simple lookup.

            if post_details:
                post_data = dict(post_details)
                # Simplified fetching of author/community names for this context.
                # A more robust solution might involve calling their respective get_by_id functions.
                cursor.execute("SELECT username FROM public.users WHERE id = %s", (author_id_val,))
                author_res = cursor.fetchone()
                post_data['author_name'] = author_res['username'] if author_res else "Unknown Author"

                cursor.execute("SELECT name FROM public.communities WHERE id = %s", (community_id,))
                comm_res = cursor.fetchone()
                post_data['community_name'] = comm_res['name'] if comm_res else "Unknown Community"
                post_data['community_id'] = community_id

                counts = get_post_counts(cursor, post_id_val)
                post_data.update(counts)
                results.append(post_data)
            else:
                print(f"Warning: Couldn't fetch full details for followed post {post_id_val}")
        return results
    except Exception as e:
        print(f"CRUD Error get_followed_posts_in_community_graph C:{community_id} V:{viewer_id}: {e}")
        traceback.print_exc()
        raise

def get_reply_ids_for_post(cursor: psycopg2.extensions.cursor, post_id: int, limit: int, offset: int) -> List[int]:
    cypher_q = f"""
        MATCH (r:Reply)-[:REPLIED_TO]->(p:Post {{id: {post_id}}})
        WHERE r.parent_reply_id IS NULL 
        RETURN r.id as id, r.created_at as created_at
        ORDER BY r.created_at ASC 
        SKIP {offset} LIMIT {limit}
    """
    expected_cols_reply_ids = [('id', 'agtype'), ('created_at', 'agtype')]
    try:
        results = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols_reply_ids) or []
        return [int(r['id']) for r in results if isinstance(r, dict) and r.get('id') is not None]
    except Exception as e:
        print(f"CRUD Error getting reply IDs for post {post_id}: {e}")
        return []
def add_post_to_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> bool:
    """Creates :HAS_POST edge from Community to Post."""
    # Use datetime directly
    now_iso = datetime.now(timezone.utc).isoformat()
    added_at_quoted = utils.quote_cypher_string(now_iso)
    # ... rest of function using execute_cypher ...
    cypher_q = f"""
        MATCH (c:Community {{id: {community_id}}}) MATCH (p:Post {{id: {post_id}}})
        MERGE (c)-[r:HAS_POST]->(p) SET r.added_at = {added_at_quoted} """
    try: return execute_cypher(cursor, cypher_q)
    except Exception as e: print(f"Error adding post to community: {e}"); return False

def remove_post_from_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> bool:
    """Deletes :HAS_POST edge between Community and Post."""
    # Avoid count()
    cypher_q = f"MATCH (c:Community {{id: {community_id}}})-[r:HAS_POST]->(p:Post {{id: {post_id}}}) DELETE r"
    try: return execute_cypher(cursor, cypher_q) # Assume success if no error
    except Exception as e: print(f"Error removing post from community: {e}"); return False

