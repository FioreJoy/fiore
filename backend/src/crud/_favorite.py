# backend/src/crud/_favorite.py
import psycopg2
import psycopg2.extras
from typing import Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher
from .. import utils # Import root utils for quote_cypher_string

# =========================================
# Favorite CRUD (Purely Graph Operations)
# =========================================

def add_favorite_db(
    cursor: psycopg2.extensions.cursor,
    user_id: int,
    post_id: Optional[int],
    reply_id: Optional[int]
) -> bool:
    """
    Creates/Updates a :FAVORITED edge in AGE between a User and a Post/Reply.
    Sets/overwrites the favorited_at property.
    Requires CALLING function to handle transaction commit/rollback.
    Returns True on success.
    """
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None:
        raise ValueError("Favorite target missing: Must provide post_id or reply_id")

    now_iso = datetime.now(timezone.utc).isoformat()
    favorited_at_quoted = utils.quote_cypher_string(now_iso)

    # MERGE finds or creates the edge, SET ensures properties are updated
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (target:{target_label} {{id: {target_id}}})
        MERGE (u)-[r:FAVORITED]->(target)
        SET r.favorited_at = {favorited_at_quoted}
    """
    try:
        print(f"CRUD: Adding favorite (U:{user_id} -> {target_label}:{target_id})...")
        execute_cypher(cursor, cypher_q) # Assumes raises on error
        print(f"CRUD: Favorite added/updated successfully.")
        return True
    except Exception as e:
        print(f"CRUD Error adding favorite (U:{user_id} -> {target_label}:{target_id}): {e}")
        raise # Re-raise for transaction rollback

def remove_favorite_db(
    cursor: psycopg2.extensions.cursor,
    user_id: int,
    post_id: Optional[int],
    reply_id: Optional[int]
) -> bool:
    """
    Removes a :FAVORITED edge in AGE between a User and a Post/Reply.
    Requires CALLING function to handle transaction commit/rollback.
    Returns True if an edge was deleted, False otherwise.
    """
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None:
        raise ValueError("Favorite target missing: Must provide post_id or reply_id")

    # MATCH the specific edge and DELETE it
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[r:FAVORITED]->(target:{target_label} {{id: {target_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    expected = [('deleted_count', 'agtype')] # Define expected column
    try:
        # ... (execute_cypher with expected_columns) ...
        result_map = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected) # Use map directly
        deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
        print(f"CRUD: Favorite removal result - Deleted count: {deleted_count}")
        return deleted_count > 0 # True if count is 1
    except Exception as e:
        print(f"CRUD Error removing favorite (U:{user_id} -> {target_label}:{target_id}): {e}")
        raise # Re-raise for transaction rollback

def get_viewer_favorite_status(cursor, viewer_id: int, post_id: Optional[int] = None, reply_id: Optional[int] = None) -> bool:
    """Checks if the viewer has favorited an item using MATCH."""
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None: return False

    # Use MATCH and check if a result exists
    cypher_fav = f"MATCH (:User {{id:{viewer_id}}})-[:FAVORITED]->(target:{target_label} {{id:{target_id}}}) RETURN target.id as tid"
    expected = [('tid', 'agtype')] # Define expected column
    try:
        fav_res = execute_cypher(cursor, cypher_fav, fetch_one=True, expected_columns=expected)
        return fav_res is not None and fav_res.get('tid') is not None # Check parsed dict value
    except Exception as e:
        print(f"Error checking favorite status V:{viewer_id} -> {target_label}:{target_id} : {e}")
        return False
# Note: Getting favorite counts is handled by get_post_counts and get_reply_counts
# in their respective files (_post.py, _reply.py) via the get_graph_counts helper.
