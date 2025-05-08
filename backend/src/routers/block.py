# backend/src/routers/block.py
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Dict, Any

import psycopg2
from .. import schemas, crud, auth
from ..database import get_db_connection

router = APIRouter(
    # Prefix might be better under /users/me/ ? Or keep top level? Let's use /users/me/
    prefix="/users/me",
    tags=["Blocking"],
    dependencies=[Depends(auth.get_current_user)] # All require authentication
)

# Note: BlockedUserDisplay schema needs to be defined in schemas.py
# It should match the keys returned by crud.get_blocked_users_db
# e.g., blocked_id, blocked_at, blocked_username, blocked_name, blocked_user_avatar_url

@router.get("/blocked", response_model=List[schemas.BlockedUserDisplay])
async def get_blocked_users_route(current_user_id: int = Depends(auth.get_current_user)):
    """Gets the list of users blocked by the current user."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        blocked_list = crud.get_blocked_users_db(cursor, current_user_id)
        # Data is already processed with URL in CRUD function
        return blocked_list
    except psycopg2.Error as db_err: # Catch specific DB errors
        print(f"DB Error fetching blocked users for {current_user_id}: {db_err}")
        # Don't expose internal error details unless needed
        raise HTTPException(status_code=500, detail="Database error retrieving blocked users")
    except Exception as e: # Catch any other unexpected errors
        print(f"Unexpected error in get_blocked_users_route for {current_user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve blocked users")
    finally:
        if conn: conn.close()
@router.post("/block/{user_id_to_block}", status_code=status.HTTP_204_NO_CONTENT)
async def block_user_route(
    user_id_to_block: int,
    current_user_id: int = Depends(auth.get_current_user)
):
    """Blocks the specified user."""
    if current_user_id == user_id_to_block:
        raise HTTPException(status_code=400, detail="Cannot block yourself")

    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Check if target user exists first (optional but good practice)
        target_user = crud.get_user_by_id(cursor, user_id_to_block)
        if not target_user:
            raise HTTPException(status_code=404, detail="User to block not found")

        success = crud.block_user_db(cursor, current_user_id, user_id_to_block)
        conn.commit()
        # Return 204 No Content on success (block created or already existed)
        return None
    except psycopg2.Error as db_err:
         if conn: conn.rollback()
         print(f"DB Error blocking user: {db_err}")
         raise HTTPException(status_code=500, detail="Database error blocking user")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error in block_user_route: {e}")
        raise HTTPException(status_code=500, detail="Failed to block user")
    finally:
        if conn: conn.close()

@router.delete("/unblock/{user_id_to_unblock}", status_code=status.HTTP_204_NO_CONTENT)
async def unblock_user_route(
    user_id_to_unblock: int,
    current_user_id: int = Depends(auth.get_current_user)
):
    """Unblocks the specified user."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        deleted = crud.unblock_user_db(cursor, current_user_id, user_id_to_unblock)
        conn.commit()
        print(f"Unblock result for {current_user_id} -> {user_id_to_unblock}: {deleted}")
        # Return 204 No Content whether block existed or not
        return None
    except psycopg2.Error as db_err:
         if conn: conn.rollback()
         print(f"DB Error unblocking user: {db_err}")
         raise HTTPException(status_code=500, detail="Database error unblocking user")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error in unblock_user_route: {e}")
        raise HTTPException(status_code=500, detail="Failed to unblock user")
    finally:
        if conn: conn.close()

