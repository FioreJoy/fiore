# backend/src/routers/replies.py

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional, Dict, Any # Added Dict, Any
import psycopg2

# Use the central crud import
from .. import schemas, crud, auth, utils
from ..database import get_db_connection
from ..utils import get_minio_url # For generating avatar URLs

router = APIRouter(
    prefix="/replies",
    tags=["Replies"],
    # dependencies=[Depends(auth.get_current_user)] # Apply auth dependency here
)

@router.post("", status_code=status.HTTP_201_CREATED, response_model=schemas.ReplyDisplay)
async def create_reply(
        reply_data: schemas.ReplyCreate, # Input: post_id, content, parent_reply_id?
        current_user_id: int = Depends(auth.get_current_user) # Require auth to reply
):
    """ Creates a new reply (relational + graph). """
    conn = None
    reply_id = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Call the combined create function (relational + graph)
        reply_id = crud.create_reply_db( # Use crud prefix
            cursor,
            post_id=reply_data.post_id,
            user_id=current_user_id,
            content=reply_data.content,
            parent_reply_id=reply_data.parent_reply_id
        )
        if reply_id is None:
            raise HTTPException(status_code=500, detail="Reply creation failed in database")

        # Fetch created reply details (including counts and author info) for response
        # We need a way to get a single reply with augmented data
        # Let's modify get_replies_for_post_db slightly or create get_reply_details_db
        # For now, fetch using the list method and filter (less efficient)
        all_replies_augmented = crud.get_replies_for_post_db(cursor, reply_data.post_id)
        created_reply_details = next((r for r in all_replies_augmented if r['id'] == reply_id), None)

        if not created_reply_details:
            conn.rollback() # Rollback if we can't fetch back the created reply
            print(f"Warning: Could not fetch back details for created reply {reply_id}")
            raise HTTPException(status_code=500, detail="Could not retrieve created reply details")

        conn.commit() # Commit successful creation and fetch

        # Prepare response
        response_data = dict(created_reply_details)
        # Generate author avatar URL
        response_data['author_avatar_url'] = get_minio_url(response_data.get('author_avatar'))
        # Add initial user vote/favorite status (will be false/null)
        response_data['has_upvoted'] = False
        response_data['has_downvoted'] = False
        response_data['is_favorited'] = False

        print(f"✅ Reply {reply_id} created by User {current_user_id} for Post {reply_data.post_id}")
        return schemas.ReplyDisplay(**response_data) # Validate against schema

    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ DB Error creating reply: {e} (Code: {e.pgcode})")
        detail = f"Database error: {e.pgerror}"
        if e.pgcode == '23503': # Foreign key violation likely on post_id or parent_reply_id
            detail = "Invalid post_id or parent_reply_id provided."
        raise HTTPException(status_code=400, detail=detail)
    except HTTPException as http_exc:
        if conn: conn.rollback() # Rollback if validation inside endpoint fails
        raise http_exc
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Unexpected Error creating reply: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()


@router.get("/{post_id}", response_model=List[schemas.ReplyDisplay])
async def get_replies_for_post(
        post_id: int,
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # This fetch includes counts now
        replies_db = crud.get_replies_for_post_db(cursor, post_id)

        processed_replies = []
        for reply in replies_db:
            reply_data = dict(reply)
            reply_data['author_avatar_url'] = utils.get_minio_url(reply.get('author_avatar'))

            # Get viewer status using CRUD functions if authenticated
            viewer_vote = None
            is_favorited = False
            if current_user_id is not None:
                reply_id = reply_data['id']
                # **** USE CRUD FUNCTIONS ****
                viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=None, reply_id=reply_id) # Pass post_id=None
                is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=None, reply_id=reply_id) # Pass post_id=None
                # **************************

            reply_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
            reply_data['viewer_has_favorited'] = is_favorited
            # Ensure schema has this field:
            # reply_data.setdefault('is_favorited', is_favorited)


            processed_replies.append(schemas.ReplyDisplay(**reply_data))

        print(f"✅ Fetched {len(processed_replies)} replies for post {post_id}")
        return processed_replies
    # ... (keep existing error handling) ...
    except Exception as e:
        print(f"❌ Error fetching replies for post {post_id}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Error fetching replies")
    finally:
        if conn: conn.close()


@router.delete("/{reply_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_reply(
        reply_id: int,
        current_user_id: int = Depends(auth.get_current_user) # Require auth
):
    """ Deletes a reply (requires ownership). Deletes from relational and graph. """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # 1. Check ownership BEFORE deleting
        reply = crud.get_reply_by_id(cursor, reply_id) # Fetch relational data
        if not reply:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reply not found")
        if reply["user_id"] != current_user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to delete this reply")

        # 2. Call the combined delete function
        deleted = crud.delete_reply_db(cursor, reply_id)

        if not deleted:
            # Should be caught by the initial check, but handle defensively
            conn.rollback()
            print(f"⚠️ Reply {reply_id} delete function returned false.")
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reply not found during deletion")

        conn.commit() # Commit successful deletion
        print(f"✅ Reply {reply_id} deleted successfully by User {current_user_id}")
        return None # Return None for 204 No Content

    except HTTPException as http_exc:
        if conn: conn.rollback()
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ SQL Error deleting reply {reply_id}: {e}")
        raise HTTPException(status_code=500, detail="Database error during deletion")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Unexpected Error deleting reply {reply_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not delete reply")
    finally:
        if conn: conn.close()

# --- NEW: Favorite/Unfavorite Reply Endpoints ---

@router.post("/{reply_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def favorite_reply(
        reply_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """Adds a reply to the user's favorites."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        success = crud.add_favorite_db(cursor, user_id=current_user_id, post_id=None, reply_id=reply_id)
        conn.commit()

        counts = crud.get_reply_counts(cursor, reply_id) # Fetch updated counts

        return {
            "message": "Reply favorited successfully",
            "success": success,
            "new_counts": counts
        }
    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ DB Error favoriting reply {reply_id}: {e}")
        raise HTTPException(status_code=500, detail="Database error favoriting reply")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error favoriting reply {reply_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not favorite reply")
    finally:
        if conn: conn.close()


@router.delete("/{reply_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def unfavorite_reply(
        reply_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    """Removes a reply from the user's favorites."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        deleted = crud.remove_favorite_db(cursor, user_id=current_user_id, post_id=None, reply_id=reply_id)
        conn.commit()

        counts = crud.get_reply_counts(cursor, reply_id) # Fetch updated counts

        return {
            "message": "Reply unfavorited successfully" if deleted else "Reply was not favorited",
            "success": deleted,
            "new_counts": counts
        }
    except psycopg2.Error as e:
        if conn: conn.rollback()
        print(f"❌ DB Error unfavoriting reply {reply_id}: {e}")
        raise HTTPException(status_code=500, detail="Database error unfavoriting reply")
    except Exception as e:
        if conn: conn.rollback()
        print(f"❌ Error unfavoriting reply {reply_id}: {e}")
        raise HTTPException(status_code=500, detail="Could not unfavorite reply")
    finally:
        if conn: conn.close()

