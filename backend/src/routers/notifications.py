# backend/src/routers/notifications.py
from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional

from .. import schemas, crud, auth, utils # utils might be needed for image URLs
from ..database import get_db_connection
import psycopg2
import traceback

router = APIRouter(
    prefix="/notifications",
    tags=["Notifications"],
    dependencies=[Depends(auth.get_current_user)] # All notification routes require auth
)

@router.get("", response_model=List[schemas.NotificationDisplay])
async def get_my_notifications(
    current_user_id: int = Depends(auth.get_current_user),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    unread_only: Optional[bool] = Query(None, description="Filter by unread status (true=unread, false=read, null=all)")
):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        notifications_db = crud.get_notifications_for_user(
            cursor, user_id=current_user_id, limit=limit, offset=offset, unread_only=unread_only
        )
        # The CRUD function already structures the data well, including actor and related entity info.
        return [schemas.NotificationDisplay(**notif) for notif in notifications_db]
    except psycopg2.Error as db_err:
        print(f"DB Error fetching notifications for user {current_user_id}: {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching notifications.")
    except Exception as e:
        print(f"Error fetching notifications for user {current_user_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Failed to fetch notifications.")
    finally:
        if conn: conn.close()

@router.post("/read", status_code=status.HTTP_200_OK)
async def mark_notifications_read_route(
    update_request: schemas.NotificationReadUpdate,
    current_user_id: int = Depends(auth.get_current_user)
):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Ensure user can only mark their own notifications
        # The CRUD function already filters by recipient_user_id, so this is an extra check if needed here
        # or rely on CRUD to correctly handle permissions.

        affected_count = crud.mark_notifications_as_read(
            cursor, user_id=current_user_id, notification_ids=update_request.notification_ids, read_status=update_request.is_read
        )
        conn.commit()
        
        if affected_count == 0 and update_request.notification_ids:
             # This could mean notifications didn't exist or didn't belong to user, or already in desired state
             print(f"Mark read: 0 notifications affected for user {current_user_id}, IDs: {update_request.notification_ids}")
             # Not necessarily an error, could be no-op.
        
        return {"message": f"{affected_count} notifications updated.", "affected_count": affected_count}
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        print(f"DB Error marking notifications read for user {current_user_id}: {db_err}")
        raise HTTPException(status_code=500, detail="Database error updating notifications.")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error marking notifications read for user {current_user_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Failed to update notifications.")
    finally:
        if conn: conn.close()


@router.post("/read-all", status_code=status.HTTP_200_OK)
async def mark_all_my_notifications_read_route(
    current_user_id: int = Depends(auth.get_current_user)
):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        affected_count = crud.mark_all_notifications_as_read(cursor, user_id=current_user_id)
        conn.commit()
        return {"message": f"{affected_count} notifications marked as read.", "affected_count": affected_count}
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        print(f"DB Error marking all notifications read for user {current_user_id}: {db_err}")
        raise HTTPException(status_code=500, detail="Database error updating notifications.")
    except Exception as e:
        if conn: conn.rollback()
        print(f"Error marking all notifications read for user {current_user_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Failed to update notifications.")
    finally:
        if conn: conn.close()


@router.get("/unread-count", response_model=schemas.UnreadNotificationCount)
async def get_my_unread_notification_count_route(
    current_user_id: int = Depends(auth.get_current_user)
):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        count = crud.get_unread_notification_count(cursor, user_id=current_user_id)
        return schemas.UnreadNotificationCount(count=count)
    except psycopg2.Error as db_err:
        print(f"DB Error getting unread notification count for user {current_user_id}: {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching count.")
    except Exception as e:
        print(f"Error getting unread notification count for user {current_user_id}: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Failed to fetch count.")
    finally:
        if conn: conn.close()

# --- Device Token Management ---
@router.post("/device-tokens", status_code=status.HTTP_201_CREATED, response_model=schemas.UserDeviceTokenDisplay)
async def register_device_token_route(
    token_data: schemas.UserDeviceTokenCreate,
    current_user_id: int = Depends(auth.get_current_user)
):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        token_id = crud.register_user_device_token(
            cursor, user_id=current_user_id, device_token=token_data.device_token, platform=token_data.platform.value
        )
        if not token_id:
            conn.rollback()
            raise HTTPException(status_code=500, detail="Failed to register device token.")
        conn.commit()
        # Fetch the created/updated record to return full details
        cursor.execute("SELECT * FROM public.user_device_tokens WHERE id = %s", (token_id,))
        created_token_db = cursor.fetchone()
        return schemas.UserDeviceTokenDisplay(**created_token_db)

    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        # Handle specific errors like unique constraint violation if needed
        raise HTTPException(status_code=500, detail=f"Database error registering token: {db_err.pgerror or str(db_err)}")
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to register device token: {e}")
    finally:
        if conn: conn.close()

@router.delete("/device-tokens", status_code=status.HTTP_204_NO_CONTENT)
async def unregister_device_token_route(
    device_token: str = Query(...), # Pass token as query param for DELETE
    current_user_id: int = Depends(auth.get_current_user)
):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        success = crud.unregister_user_device_token(cursor, user_id=current_user_id, device_token=device_token)
        conn.commit()
        if not success:
            # This might mean the token didn't exist for this user
            print(f"WARN: No device token '{device_token}' found for user {current_user_id} to unregister.")
            # Still return 204 as the desired state (not registered) is achieved
        return None
    except psycopg2.Error as db_err:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=f"Database error unregistering token: {db_err.pgerror or str(db_err)}")
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to unregister device token: {e}")
    finally:
        if conn: conn.close()
