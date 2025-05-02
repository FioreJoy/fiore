# backend/src/crud/_vote.py
import psycopg2
import psycopg2.extras
from typing import Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher
from .. import utils # Import root utils for quote_cypher_string

# =========================================
# Vote CRUD (Purely Graph Operations)
# =========================================

def cast_vote_db(
    cursor: psycopg2.extensions.cursor,
    user_id: int,
    post_id: Optional[int],
    reply_id: Optional[int],
    vote_type: bool # True=Up, False=Down
) -> bool:
    """
    Creates or updates a :VOTED edge in AGE between a User and a Post/Reply.
    Sets/overwrites the vote_type and created_at properties.
    Requires CALLING function to handle transaction commit/rollback.
    Returns True on success.
    """
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None:
        raise ValueError("Vote target missing: Must provide post_id or reply_id")

    now_iso = datetime.now(timezone.utc).isoformat()
    created_at_quoted = utils.quote_cypher_string(now_iso)
    vote_type_cypher = 'true' if vote_type else 'false'

    # MERGE finds or creates the edge, SET ensures properties are updated
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (target:{target_label} {{id: {target_id}}})
        MERGE (u)-[r:VOTED]->(target)
        SET r.vote_type = {vote_type_cypher}, r.created_at = {created_at_quoted}
    """
    try:
        print(f"CRUD: Casting vote (U:{user_id} -> {target_label}:{target_id}, Type:{vote_type})...")
        execute_cypher(cursor, cypher_q) # Assumes raises on error
        print(f"CRUD: Vote cast/updated successfully.")
        return True
    except Exception as e:
        print(f"CRUD Error casting vote (U:{user_id} -> {target_label}:{target_id}): {e}")
        raise # Re-raise for transaction rollback

def remove_vote_db(
    cursor: psycopg2.extensions.cursor,
    user_id: int,
    post_id: Optional[int],
    reply_id: Optional[int]
) -> bool:
    """
    Removes a :VOTED edge in AGE between a User and a Post/Reply.
    Requires CALLING function to handle transaction commit/rollback.
    Returns True if an edge was deleted, False otherwise.
    """
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None:
        raise ValueError("Vote target missing: Must provide post_id or reply_id")

    # MATCH the specific edge and DELETE it
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[r:VOTED]->(target:{target_label} {{id: {target_id}}})
        DELETE r
        RETURN count(r) as deleted_count
    """
    try:
        print(f"CRUD: Removing vote (U:{user_id} -> {target_label}:{target_id})...")
        result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
        if result_agtype is None:
             print(f"CRUD: Vote edge not found for removal.")
             return False # Edge didn't exist
        result_map = utils.parse_agtype(result_agtype)
        deleted_count = int(result_map.get('deleted_count', 0)) if isinstance(result_map, dict) else 0
        print(f"CRUD: Vote removal result - Deleted count: {deleted_count}")
        return deleted_count > 0 # True if count is 1
    except Exception as e:
        print(f"CRUD Error removing vote (U:{user_id} -> {target_label}:{target_id}): {e}")
        raise # Re-raise for transaction rollback

# Note: Getting vote counts is handled by get_post_counts and get_reply_counts
# in their respective files (_post.py, _reply.py)
