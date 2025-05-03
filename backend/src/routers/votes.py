# backend/src/routers/votes.py
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
import psycopg2
from typing import Dict, Set, Tuple, Any

# Use the central crud import
from .. import schemas, crud, auth, utils
from ..database import get_db_connection
# Import graph helpers only if needed directly here (unlikely now)
# from ..crud._graph import execute_cypher, parse_agtype

router = APIRouter(
    prefix="/votes",
    tags=["Votes"],
    # dependencies=[Depends(auth.get_current_user)] # Apply auth dependency here
)

@router.post("", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def manage_vote(
        vote_data: schemas.VoteCreate,
        current_user_id: int = Depends(auth.get_current_user)
):
    # ... (validation check for post_id/reply_id) ...
    if not ((vote_data.post_id is not None and vote_data.reply_id is None) or \
            (vote_data.post_id is None and vote_data.reply_id is not None)):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail="Must vote on exactly one of post_id or reply_id")

    conn = None
    post_id = vote_data.post_id
    reply_id = vote_data.reply_id
    new_vote_type = vote_data.vote_type
    target_type = "Post" if post_id else "Reply" # Capitalized for messages/logs
    target_id = post_id if post_id else reply_id

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check current vote state using CRUD function
        current_vote_type: Optional[bool] = crud.get_viewer_vote_status(
            cursor, current_user_id, post_id=post_id, reply_id=reply_id
        )
        print(f"DEBUG: Current vote status for User {current_user_id} on {target_type} {target_id}: {current_vote_type}")

        # 2. Determine action
        action_taken = ""
        success = False
        if current_vote_type == new_vote_type:
            # Remove vote
            print(f"Attempting to remove existing {target_type} vote...")
            success = crud.remove_vote_db(cursor, current_user_id, post_id, reply_id)
            action_taken = "removed" if success else "remove_failed"
        else:
            # Cast/Update vote
            print(f"Attempting to cast/update {target_type} vote to {new_vote_type}...")
            success = crud.cast_vote_db(cursor, current_user_id, post_id, reply_id, new_vote_type)
            action_taken = "cast/updated" if success else "cast/update_failed"

        conn.commit() # Commit if DB operations likely succeeded

        # 3. Fetch updated counts
        counts = {}
        if post_id:
            counts = crud.get_post_counts(cursor, post_id)
        elif reply_id:
            counts = crud.get_reply_counts(cursor, reply_id)

        print(f"✅ Vote action '{action_taken}' completed. Success: {success}")
        # Return success=True even if remove failed b/c vote didn't exist
        final_success_state = True if action_taken != "cast/update_failed" else False
        return {
            "message": f"Vote {action_taken}",
            "action": action_taken,
            "success": final_success_state,
            "new_counts": counts
        }

    # ... (keep existing error handling) ...
    except ValueError as ve:
        if conn: conn.rollback()
        print(f"❌ Vote Value Error: {ve}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        print(f"❌ Vote DB Error: {db_err} (Code: {db_err.pgcode})")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Database error during voting.")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Vote error [{type(e).__name__}]: {e}")
        import traceback; traceback.print_exc();
        # Return the actual error detail for unexpected errors
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred during voting: {e}")
    finally:
        if conn: conn.close()
# Remove GET /votes endpoint as it's generally not needed by clients
# @router.get("", ...)