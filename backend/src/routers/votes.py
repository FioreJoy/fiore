# backend/src/routers/votes.py
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
import psycopg2
from typing import Dict, Set, Tuple, Any

# Use the central crud import
from .. import schemas, crud, auth
from ..database import get_db_connection
# Import graph helpers only if needed directly here (unlikely now)
# from ..crud._graph import execute_cypher, parse_agtype

router = APIRouter(
    prefix="/votes",
    tags=["Votes"],
    # dependencies=[Depends(auth.get_current_user)] # Apply auth dependency here
)

@router.post("", status_code=status.HTTP_200_OK, response_model=Dict[str, Any]) # Return simple status message
async def manage_vote(
        vote_data: schemas.VoteCreate, # Input: post_id OR reply_id, vote_type (true=up, false=down)
        current_user_id: int = Depends(auth.get_current_user)
):
    """
    Casts, updates (by overwriting), or removes a vote based on user action.
    - If user votes (up/down) and no vote exists -> Creates vote.
    - If user votes (up/down) and same vote exists -> Removes vote (toggle off).
    - If user votes (up/down) and different vote exists -> Updates vote type.
    """
    conn = None
    post_id = vote_data.post_id
    reply_id = vote_data.reply_id
    new_vote_type = vote_data.vote_type # The vote action the user just performed

    target_type = "post" if post_id else "reply"
    target_id = post_id if post_id else reply_id

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check the *current* vote state in the graph
        # We need a way to fetch the existing vote type if it exists
        cypher_check = f"""
            MATCH (u:User {{id: {current_user_id}}})-[r:VOTED]->(target:{target_type} {{id: {target_id}}})
            RETURN r.vote_type as current_vote_type
        """
        existing_vote_agtype = crud.execute_cypher(cursor, cypher_check, fetch_one=True)
        existing_vote_map = crud.parse_agtype(existing_vote_agtype)
        current_vote_type = existing_vote_map.get('current_vote_type') if isinstance(existing_vote_map, dict) else None

        # 2. Determine action based on current state and new action
        action_taken = ""
        success = False
        if current_vote_type == new_vote_type:
            # User clicked the same button again - Remove the vote
            print(f"Attempting to remove existing {target_type} vote (User {current_user_id} -> {target_id})")
            success = crud.remove_vote_db(cursor, current_user_id, post_id, reply_id)
            action_taken = "removed" if success else "remove_failed (not found?)"
        else:
            # No vote exists, or user clicked the *other* button - Cast/Update the vote
            print(f"Attempting to cast/update {target_type} vote (User {current_user_id} -> {target_id}, Type: {new_vote_type})")
            success = crud.cast_vote_db(cursor, current_user_id, post_id, reply_id, new_vote_type)
            action_taken = "cast/updated" if success else "cast/update_failed"

        conn.commit() # Commit transaction if DB operations succeeded

        # 3. Fetch updated counts to return in response
        # This makes the response more useful for the frontend UI update
        counts = {}
        if post_id:
            counts = crud.get_post_counts(cursor, post_id)
        elif reply_id:
            counts = crud.get_reply_counts(cursor, reply_id)

        print(f"✅ Vote action '{action_taken}' completed for User {current_user_id} on {target_type} {target_id}. Success: {success}")

        return {
            "message": f"Vote {action_taken}",
            "action": action_taken, # More specific status
            "success": success,
            "new_counts": counts # Return updated counts
        }

    except ValueError as ve: # Catch programmer errors like missing ID
        if conn: conn.rollback()
        print(f"❌ Vote Value Error: {ve}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except psycopg2.Error as db_err: # Catch specific DB errors from execute_cypher
        if conn: conn.rollback()
        print(f"❌ Vote DB Error: {db_err} (Code: {db_err.pgcode})")
        # Check common errors if needed (e.g., node not found during MATCH)
        # if db_err.pgcode == '...': raise HTTPException(...)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error during voting.")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Vote error [{type(e).__name__}]: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="An unexpected error occurred during voting.")
    finally:
        if conn: conn.close()

# Remove GET /votes endpoint as it's generally not needed by clients
# @router.get("", ...)