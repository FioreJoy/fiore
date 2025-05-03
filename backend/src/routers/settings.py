# backend/src/routers/settings.py
from fastapi import APIRouter, Depends, HTTPException, status
from typing import Dict, Any
import psycopg2

# Use central imports
from .. import schemas, crud, auth
from ..database import get_db_connection

router = APIRouter(
    prefix="/settings",
    tags=["Settings"],
    # Apply auth dependency to all routes in this router
    dependencies=[Depends(auth.get_current_user)]
)

@router.get("/notifications", response_model=schemas.NotificationSettings)
async def read_notification_settings(current_user_id: int = Depends(auth.get_current_user)):
    """Fetches the current user's notification settings."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        settings = crud.get_notification_settings(cursor, current_user_id)
        if settings is None:
            # If user exists but settings fetch failed, maybe return defaults? Or 500?
            # If user doesn't exist (shouldn't happen due to Depends), this won't be reached.
            # Let's assume settings should exist if user does.
            raise HTTPException(status_code=404, detail="Settings not found for user.")
        # Validate against schema before returning
        return schemas.NotificationSettings(**settings)
    except psycopg2.Error as db_err:
        print(f"Error fetching settings: {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching settings")
    except Exception as e:
        print(f"Error fetching notification settings: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch settings")
    finally:
        if conn: conn.close()

@router.put("/notifications", response_model=schemas.NotificationSettings)
async def write_notification_settings(
        settings_data: schemas.NotificationSettings, # Expect full settings object
        current_user_id: int = Depends(auth.get_current_user)
):
    """Updates the current user's notification settings."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Convert Pydantic model to dict
        update_dict = settings_data.model_dump() if hasattr(settings_data, 'model_dump') else settings_data.dict()

        success = crud.update_notification_settings(cursor, current_user_id, update_dict)
        if not success:
            # Assume user not found if rowcount was 0
            conn.rollback()
            raise HTTPException(status_code=404, detail="User not found or no settings changed")

        conn.commit() # Commit successful update

        # Fetch and return the updated settings
        updated_settings = crud.get_notification_settings(cursor, current_user_id)
        if updated_settings is None:
            # This would be unusual if update succeeded
            raise HTTPException(status_code=500, detail="Failed to fetch updated settings")
        return schemas.NotificationSettings(**updated_settings) # Validate

    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc # Re-raise explicit HTTP exceptions
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        print(f"DB Error updating settings: {db_err}")
        raise HTTPException(status_code=500, detail="Database error updating settings")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error updating notification settings: {e}")
        raise HTTPException(status_code=500, detail="Failed to update settings")
    finally:
        if conn: conn.close()