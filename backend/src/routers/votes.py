# backend/src/routers/votes.py
from fastapi import APIRouter, Depends, HTTPException, status
from typing import Optional, Dict, Any
import psycopg2
import traceback

from .. import schemas, crud, auth, utils
from ..crud import execute_cypher
from ..database import get_db_connection

router = APIRouter(
    prefix="/votes",
    tags=["Votes"],
)
#
# @router.post("", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
# async def manage_vote(
#         vote_data: schemas.VoteCreate,
#         current_user_id: int = Depends(auth.get_current_user)
# ):
#     if not ((vote_data.post_id is not None and vote_data.reply_id is None) or \
#             (vote_data.post_id is None and vote_data.reply_id is not None)):
#         raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
#                             detail="Must vote on exactly one of post_id or reply_id")
#
#     conn = None
#     post_id = vote_data.post_id
#     reply_id = vote_data.reply_id
#     requested_vote_type = vote_data.vote_type # The vote user wants to set (True for up, False for down)
#     target_type_str = "Post" if post_id else "Reply"
#     target_id = post_id if post_id else reply_id
#
#     try:
#         # Use a single connection/cursor for the whole operation
#         conn = get_db_connection(); cursor = conn.cursor()
#
#         # 1. Get current vote state (use the same cursor that will perform writes)
#         current_db_vote_type: Optional[bool] = crud.get_viewer_vote_status(
#             cursor, current_user_id, post_id=post_id, reply_id=reply_id
#         )
#
#         print(f"DEBUG manage_vote: User {current_user_id} on {target_type_str} {target_id} - Current DB vote (before op): {current_db_vote_type}, Requested vote: {requested_vote_type}")
#
#         action_for_response = ""  # What the API response "action" field will be
#         operation_successful = False # Did the DB operation achieve the desired state?
#
#         if current_db_vote_type == requested_vote_type:
#             # User clicked the same vote button again (e.g., already upvoted, clicks upvote again)
#             # Intent: Remove the vote.
#             print(f"  Intent: REMOVE vote. Current: {current_db_vote_type}, Requested: {requested_vote_type}")
#             db_op_succeeded = crud.remove_vote_db(cursor, current_user_id, post_id, reply_id)
#             if db_op_succeeded:
#                 print(f"  CRUD remove_vote_db: Successfully removed vote.")
#                 action_for_response = "removed"
#                 operation_successful = True
#             else:
#                 # remove_vote_db returns False if no edge was found/deleted.
#                 # This means the vote was already not there, so desired "removed" state is met.
#                 print(f"  CRUD remove_vote_db: No vote found to remove, or failed. (Returned False)")
#                 action_for_response = "removed" # Still, the desired state is "removed"
#                 operation_successful = True # Considered success as vote is not present
#
#         else: # current_db_vote_type is different from requested_vote_type, OR current_db_vote_type is None
#             # Intent: Cast a new vote or change an existing one.
#             print(f"  Intent: CAST/UPDATE vote. Current: {current_db_vote_type}, Requested: {requested_vote_type}")
#             db_op_succeeded = crud.cast_vote_db(cursor, current_user_id, post_id, reply_id, requested_vote_type)
#             if db_op_succeeded:
#                 print(f"  CRUD cast_vote_db: Successfully cast/updated vote.")
#                 action_for_response = "cast/updated"
#                 operation_successful = True
#             else:
#                 # cast_vote_db returned False (e.g. SET property mismatch or other failure)
#                 print(f"  CRUD cast_vote_db: Failed to cast/update vote. (Returned False)")
#                 action_for_response = "cast_or_update_failed"
#                 operation_successful = False
#
#         conn.commit()
#         print(f"DEBUG manage_vote: Transaction committed. Action for response: '{action_for_response}'")
#
#         counts = {}
#         # Fetch counts using a new cursor to see committed data
#         with get_db_connection() as count_conn:
#             with count_conn.cursor() as count_cursor:
#                 if target_id is not None:
#                     if post_id: counts = crud.get_post_counts(count_cursor, post_id)
#                     elif reply_id: counts = crud.get_reply_counts(count_cursor, reply_id)
#
#         print(f"✅ Vote action outcome: '{action_for_response}'. API Response Success: {operation_successful}. New Counts: {counts}")
#
#         return {"message": f"Vote action: {action_for_response}", "action": action_for_response, "success": operation_successful, "new_counts": counts}
#
#     except ValueError as ve: # From crud functions for invalid args
#         if conn: conn.rollback()
#         print(f"❌ Vote Value Error: {ve}")
#         raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
#     except psycopg2.Error as db_err: # DB level errors
#         if conn: conn.rollback()
#         print(f"❌ Vote DB Error: {db_err} (Code: {db_err.pgcode})")
#         traceback.print_exc()
#         raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error during voting operation.")
#     except Exception as e: # Other unexpected errors
#         if conn: conn.rollback()
#         print(f"❌ Vote general error [{type(e).__name__}]: {e}")
#         traceback.print_exc()
#         raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected error occurred: {e}")
#     finally:
#         if conn: conn.close()

# Fix for backend/src/routers/votes.py

# The core issue is in the vote router - when a user tries to remove a vote by clicking
# the same button again, the comparison isn't working correctly

@router.post("", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def manage_vote(
        vote_data: schemas.VoteCreate,
        current_user_id: int = Depends(auth.get_current_user)
):
    if not ((vote_data.post_id is not None and vote_data.reply_id is None) or
            (vote_data.post_id is None and vote_data.reply_id is not None)):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail="Must vote on exactly one of post_id or reply_id")

    conn = None
    post_id = vote_data.post_id
    reply_id = vote_data.reply_id
    requested_vote_type = vote_data.vote_type
    target_type_str = "Post" if post_id else "Reply"
    target_id = post_id if post_id else reply_id

    try:
        conn = get_db_connection(); cursor = conn.cursor()

        # 1. Get current vote state FROM A FRESH CURSOR to ensure visibility
        current_db_vote_type: Optional[bool] = None
        # This is important if the previous operation in the same test function committed.
        with get_db_connection() as fresh_conn: # Create a new connection context
            with fresh_conn.cursor() as fresh_cursor:
                current_db_vote_type = crud.get_viewer_vote_status(
                    fresh_cursor, current_user_id, post_id=post_id, reply_id=reply_id
                )

        print(f"DEBUG manage_vote: User {current_user_id} on {target_type_str} {target_id} - Current DB vote: {current_db_vote_type}, Requested vote: {requested_vote_type}")

        action_taken_api_string = "" # For the API response "action" field
        successful_operation = False # Overall success of the user's intent

        # FIX: Make sure to correctly compare boolean values
        # The problem might be with the comparison of None and boolean values
        if current_db_vote_type is not None and current_db_vote_type == requested_vote_type:
            # User clicked the same vote button again (e.g., upvoted, clicks upvote again) -> remove vote
            print(f"  Attempting to remove existing vote for {target_type_str} {target_id}")
            db_op_removed = crud.remove_vote_db(cursor, current_user_id, post_id, reply_id)
            if db_op_removed:
                action_taken_api_string = "removed"
                successful_operation = True
                print(f"  Vote successfully removed.")
            else:
                # This means there was no vote to remove (edge didn't exist or delete failed for other reason)
                # If no vote existed, the state is already "removed", so user intent is met.
                action_taken_api_string = "removed" # Or "not_voted_initially"
                successful_operation = True # State is as if removed
                print(f"  No existing vote found to remove, or DB remove_vote_db returned False.")
        else:
            # New vote or changing existing vote
            print(f"  Attempting to cast/update vote for {target_type_str} {target_id} to {requested_vote_type}")
            db_op_cast = crud.cast_vote_db(cursor, current_user_id, post_id, reply_id, requested_vote_type)
            if db_op_cast:
                action_taken_api_string = "cast/updated"
                successful_operation = True
                print(f"  Vote successfully cast/updated.")
            else:
                action_taken_api_string = "cast_or_update_failed"
                successful_operation = False # CRUD call failed
                print(f"  CRUD cast_vote_db returned False.")

        conn.commit()
        print(f"DEBUG manage_vote: Transaction committed. Router action: '{action_taken_api_string}'")

        counts = {}
        # Fetch counts using a new cursor to ensure we see committed data
        with get_db_connection() as count_conn:
            with count_conn.cursor() as count_cursor:
                if target_id is not None:
                    if post_id: counts = crud.get_post_counts(count_cursor, post_id)
                    elif reply_id: counts = crud.get_reply_counts(count_cursor, reply_id)

        print(f"✅ Vote action '{action_taken_api_string}' completed. API Response Success: {successful_operation}. Counts: {counts}")

        return {"message": f"Vote action: {action_taken_api_string}", "action": action_taken_api_string, "success": successful_operation, "new_counts": counts}

    except ValueError as ve:
        if conn: conn.rollback()
        print(f"❌ Vote Value Error: {ve}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        print(f"❌ Vote DB Error: {db_err} (Code: {db_err.pgcode})")
        traceback.print_exc()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error during voting.")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Vote error [{type(e).__name__}]: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"An unexpected error occurred during voting: {e}")
    finally:
        if conn: conn.close()


# Fix for _vote.py - Need to update the functions to correctly update vote counts

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
        print(f"CRUD: Casting/Updating vote (U:{user_id} on {target_label}:{target_id} to {vote_type}) with Cypher: SET r.vote_type = {vote_type_cypher}")
        result_map = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected_cols)

        print(f"CRUD cast_vote_db: Raw result from graph SET: {result_map}")

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
        print(f"CRUD DB Error removing vote: {db_err} (Code: {db_err.pgcode}). Assuming no vote to remove or other DB issue.")
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
        SET target.upvotes = COALESCE(target.upvotes, 0) + {upvote_change},
            target.downvotes = COALESCE(target.downvotes, 0) + {downvote_change}
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