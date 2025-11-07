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
        vote_type: bool # Python boolean
) -> bool:
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None:
        raise ValueError("Vote target missing: Must provide post_id or reply_id")

    now_iso = datetime.now(timezone.utc).isoformat()
    created_at_cypher = utils.quote_cypher_string(now_iso)
    # utils.quote_cypher_string will convert Python True/False to Cypher true/false
    vote_type_cypher = utils.quote_cypher_string(vote_type)

    # First check if this is a vote change (e.g., from upvote to downvote)
    # If so, we need to update counts differently
    existing_vote = get_viewer_vote_status(cursor, user_id, post_id, reply_id)

    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (target:{target_label} {{id: {target_id}}})
        MERGE (u)-[r:VOTED]->(target)
        SET r.vote_type = {vote_type_cypher}, r.created_at = {created_at_cypher}
        RETURN r.vote_type as set_vote_type 
    """
    expected_cols = [('set_vote_type', 'agtype')]
    try:
        #print(f"CRUD: Casting/Updating vote (U:{user_id} on {target_label}:{target_id} to {vote_type}) with Cypher: SET r.vote_type = {vote_type_cypher}")
        result_map = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected_cols)

        #print(f"CRUD cast_vote_db: Raw result from graph SET: {result_map}")

        # Now update the vote counts for the target
        if existing_vote is not None:
            # This is a vote change, so decrement old type and increment new type
            if existing_vote != vote_type:
                # Decrement the old count and increment the new count
                update_vote_counts(cursor, target_label, target_id,
                                   decrement_upvote=(existing_vote==True),
                                   decrement_downvote=(existing_vote==False),
                                   increment_upvote=(vote_type==True),
                                   increment_downvote=(vote_type==False))
        else:
            # This is a new vote, just increment the appropriate count
            update_vote_counts(cursor, target_label, target_id,
                               increment_upvote=(vote_type==True),
                               increment_downvote=(vote_type==False))

        if result_map and result_map.get('set_vote_type') is not None:
            persisted_vote_type = result_map.get('set_vote_type') # Should be Python bool after parse_agtype

            if persisted_vote_type == vote_type: # Direct boolean comparison
                print(f"CRUD cast_vote_db: Successfully SET and VERIFIED vote_type to {persisted_vote_type}")
                return True
            else:
                print(f"ERROR CRUD cast_vote_db: SET vote_type mismatch. Persisted: {persisted_vote_type} (type: {type(persisted_vote_type)}), Expected: {vote_type}")
                return False
        else:
            print(f"ERROR CRUD cast_vote_db: Query did not return expected 'set_vote_type' or result was None. Result: {result_map}")
            return False

    except psycopg2.Error as db_err:
        print(f"CRUD DB Error during cast_vote_db: {db_err} (Code: {db_err.pgcode}), Message: {db_err.pgerror})")
        traceback.print_exc()
        raise # Re-raise for transaction rollback
    except Exception as e:
        print(f"CRUD Error casting vote (U:{user_id} on {target_label}:{target_id}): {e}")
        traceback.print_exc()
        raise

def remove_vote_db(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        post_id: Optional[int],
        reply_id: Optional[int]
) -> bool: # Returns True if a vote was found and deleted
    target_id = post_id if post_id is not None else reply_id
    target_label = "Post" if post_id is not None else "Reply"
    if target_id is None: raise ValueError("Vote target missing")

    # First get the current vote type so we know which counter to decrement
    existing_vote = get_viewer_vote_status(cursor, user_id, post_id, reply_id)

    # We want to know if an edge was actually deleted.
    # One way is to try to delete and return the count of deleted edges.
    # `WITH r DELETE r RETURN count(r)` should work with AGE if count(r) refers to the matched edge.
    cypher_q = f"""
        MATCH (u:User {{id: {user_id}}})-[r:VOTED]->(target:{target_label} {{id: {target_id}}})
        WITH r // Ensure 'r' is bound before DELETE for count to work as expected
        DELETE r
        RETURN count(r) as deleted_count 
    """
    expected_cols = [('deleted_count', 'agtype')]
    try:
        print(f"CRUD: Removing vote (U:{user_id} -> {target_label}:{target_id})...")
        result_map = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected_cols)

        deleted_count_raw = result_map.get('deleted_count') if result_map else 0
        deleted_count = 0
        if deleted_count_raw is not None:
            try:
                deleted_count = int(deleted_count_raw)
            except (ValueError, TypeError):
                deleted_count = 0

        print(f"CRUD: remove_vote_db executed. Raw deleted_count: '{deleted_count_raw}', Parsed int: {deleted_count}")

        # If a vote was deleted, update the vote counts
        if deleted_count > 0 and existing_vote is not None:
            # Decrement the appropriate counter
            update_vote_counts(cursor, target_label, target_id,
                               decrement_upvote=(existing_vote==True),
                               decrement_downvote=(existing_vote==False))

        return deleted_count > 0
    except psycopg2.Error as db_err:
        print(f"CRUD DB Error removing vote: {db_err} (Code: {db_err.pgcode}), Message: {db_err.pgerror}).")
        traceback.print_exc()
        return False # If MATCH fails or other DB error, nothing was deleted by this call.
    except Exception as e:
        print(f"CRUD Generic Error removing vote: {e}")
        traceback.print_exc()
        raise

# New helper function to update vote counts
def update_vote_counts(
        cursor: psycopg2.extensions.cursor,
        target_label: str,
        target_id: int,
        increment_upvote: bool = False,
        increment_downvote: bool = False,
        decrement_upvote: bool = False,
        decrement_downvote: bool = False
) -> bool:
    """Update the upvote and downvote counts on a target node."""
    upvote_change = 0
    downvote_change = 0

    if increment_upvote:
        upvote_change += 1
    if decrement_upvote:
        upvote_change -= 1
    if increment_downvote:
        downvote_change += 1
    if decrement_downvote:
        downvote_change -= 1

    if upvote_change == 0 and downvote_change == 0:
        return True  # Nothing to do

    # Create a cypher query to update the counts
    cypher_q = f"""
        MATCH (target:{target_label} {{id: {target_id}}})
        SET target.upvotes = toInteger(CASE WHEN target.upvotes IS NULL THEN 0 ELSE target.upvotes END) + {upvote_change},
            target.downvotes = toInteger(CASE WHEN target.downvotes IS NULL THEN 0 ELSE target.downvotes END) + {downvote_change}
        RETURN target.upvotes as new_upvotes, target.downvotes as new_downvotes
    """
    expected_cols = [('new_upvotes', 'agtype'), ('new_downvotes', 'agtype')]

    try:
        result = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected_cols)
        print(f"CRUD: Updated {target_label} {target_id} vote counts: {result}")
        return True
    except Exception as e:
        print(f"Error updating vote counts for {target_label} {target_id}: {e}")
        traceback.print_exc()
        return False

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
