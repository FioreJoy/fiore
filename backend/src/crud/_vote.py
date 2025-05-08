# backend/src/crud/_vote.py
import psycopg2
import psycopg2.extras
from typing import Optional, Dict, Any
from datetime import datetime, timezone
import traceback
import json

from ._graph import execute_cypher
from .. import utils

def cast_vote_db(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        post_id: Optional[int],
        reply_id: Optional[int],
        vote_type: bool
) -> bool:
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None:
        raise ValueError("Vote target missing: Must provide post_id or reply_id")

    now_iso = datetime.now(timezone.utc).isoformat()
    created_at_cypher = utils.quote_cypher_string(now_iso)
    vote_type_cypher = utils.quote_cypher_string(vote_type)

    # Step 1: Ensure the edge exists. MERGE also acts as a MATCH if the edge exists.
    # We don't need to return anything from this if the next step will explicitly set and return.
    merge_q = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (target:{target_label} {{id: {target_id}}})
        MERGE (u)-[r:VOTED]->(target)
    """
    try:
        print(f"CRUD cast_vote_db (Step 1 - MERGE): Ensuring VOTED edge exists (U:{user_id} to {target_label}:{target_id})")
        execute_cypher(cursor, merge_q) # No fetch needed, just ensure it runs
        print(f"CRUD cast_vote_db (Step 1 - MERGE): Edge ensured.")
    except Exception as e_merge:
        print(f"CRUD Error during MERGE in cast_vote_db: {e_merge}")
        traceback.print_exc()
        raise

        # Step 2: Explicitly SET properties on the matched/merged edge and then RETURN the property.
    # This ensures we are reading the property after the SET operation.
    set_and_return_q = f"""
        MATCH (u:User {{id: {user_id}}})-[r:VOTED]->(target:{target_label} {{id: {target_id}}})
        SET r.vote_type = {vote_type_cypher}, r.created_at = {created_at_cypher}
        RETURN r.vote_type as set_vote_type
    """
    expected_cols = [('set_vote_type', 'agtype')]
    try:
        print(f"CRUD cast_vote_db (Step 2 - SET & RETURN): Setting properties. vote_type = {vote_type_cypher}")
        result_map = execute_cypher(cursor, set_and_return_q, fetch_one=True, expected_columns=expected_cols)
        print(f"CRUD cast_vote_db (Step 2 - SET & RETURN): Raw result from graph: {result_map}")

        if result_map and 'set_vote_type' in result_map:
            persisted_vote_type = result_map.get('set_vote_type')
            if persisted_vote_type == vote_type:
                print(f"CRUD cast_vote_db: Successfully SET and VERIFIED vote_type to {persisted_vote_type}")
                return True
            else:
                print(f"ERROR CRUD cast_vote_db: SET vote_type mismatch. Persisted: {persisted_vote_type} (type: {type(persisted_vote_type)}), Expected: {vote_type}")
                return False
        else:
            print(f"ERROR CRUD cast_vote_db: SET properties query did not return 'set_vote_type'. Result: {result_map}")
            # This could happen if the MATCH in step 2 failed, which implies the MERGE in step 1 also had an issue.
            return False
    except Exception as e_set:
        print(f"CRUD Error during SET & RETURN in cast_vote_db (U:{user_id} on {target_label}:{target_id}): {e_set}")
        traceback.print_exc()
        raise

# --- remove_vote_db and get_viewer_vote_status remain unchanged from the previous successful iteration ---
def remove_vote_db(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        post_id: Optional[int],
        reply_id: Optional[int]
) -> bool:
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None: raise ValueError("Vote target missing")

    cypher_q_remove = f"""
        MATCH (u:User {{id: {user_id}}})-[r:VOTED]->(target:{target_label} {{id: {target_id}}})
        DELETE r
        RETURN true AS was_deleted 
    """
    expected_cols_remove = [('was_deleted', 'agtype')]
    try:
        print(f"CRUD: Removing vote (U:{user_id} -> {target_label}:{target_id})...")
        result_map = execute_cypher(cursor, cypher_q_remove, fetch_one=True, expected_columns=expected_cols_remove)

        if result_map and result_map.get('was_deleted') is True:
            print(f"CRUD: remove_vote_db executed. Edge was found and deleted.")
            return True
        else:
            print(f"CRUD: remove_vote_db executed. No edge found to delete or 'was_deleted' not true. Result: {result_map}")
            return False
    except psycopg2.Error as db_err:
        print(f"CRUD DB Error removing vote: {db_err} (Code: {db_err.pgcode}).")
        return False
    except Exception as e:
        print(f"CRUD Generic Error removing vote: {e}")
        traceback.print_exc()
        raise

def get_viewer_vote_status(cursor: psycopg2.extensions.cursor, viewer_id: int, post_id: Optional[int] = None, reply_id: Optional[int] = None) -> Optional[bool]:
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None: return None

    cypher_vote = f"MATCH (:User {{id:{viewer_id}}})-[r:VOTED]->(:{target_label} {{id:{target_id}}}) RETURN r.vote_type as vt"
    expected = [('vt', 'agtype')]
    try:
        result_map = execute_cypher(cursor, cypher_vote, fetch_one=True, expected_columns=expected)

        if result_map is not None and 'vt' in result_map:
            vote_value = result_map['vt']
            #print(f"DEBUG get_viewer_vote_status for U:{viewer_id} on {target_label}:{target_id} - Raw 'vt' from graph (after parse_agtype): {vote_value} (type: {type(vote_value)})")

            if isinstance(vote_value, bool):
                return vote_value
            elif vote_value is None:
                print(f"WARN get_viewer_vote_status: 'vt' property is NULL for {target_label} {target_id}.")
                return None
            else:
                print(f"WARN get_viewer_vote_status: 'vt' property was '{vote_value}' (type: {type(vote_value)}), which is not a Python bool nor None after parsing, for {target_label} {target_id}. Returning None.")
                return None

        #print(f"DEBUG get_viewer_vote_status for U:{viewer_id} on {target_label}:{target_id} - No vote edge found or 'vt' property not returned by Cypher (result_map: {result_map}).")
        return None
    except Exception as e:
        print(f"Error checking vote status V:{viewer_id} -> {target_label}:{target_id} : {e}")
        traceback.print_exc()
        return None