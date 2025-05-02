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
        conn = get_db_connection()
        cursor = conn.cursor()

        # Optional: Add validation here if needed (e.g., check if post exists)
        # post_exists = crud.get_post_by_id(cursor, reply_data.post_id)
        # if not post_exists:
        #     raise HTTPException(status_code=404, detail="Post not found")
        # If parent_reply_id is given, check if it exists and belongs to the same post
        # ...

        # Call the combined create function
        reply_id = crud.create_reply_db(
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
        # Keep auth optional depending on whether public viewing is allowed
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional) # Use Optional Auth
):
    """ Fetches replies for a specific post. Includes graph counts and author avatars."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # get_replies_for_post_db now fetches relational data + graph counts
        replies_db = crud.get_replies_for_post_db(cursor, post_id)

        processed_replies = []
        # TODO: Optimize fetching user's vote/favorite status for *all* replies in one go if possible
        for reply in replies_db:
            reply_data = dict(reply)
            # Generate URLs
            reply_data['author_avatar_url'] = get_minio_url(reply.get('author_avatar'))

            # Fetch user's vote/favorite status IF authenticated
            # This currently involves N+1 queries, consider optimizing later
            has_upvoted = False
            has_downvoted = False
            is_favorited = False
            if current_user_id is not None:
                reply_id = reply_data['id']
                # Check vote
                cypher_vote = f"MATCH (:User {{id:{current_user_id}}})-[r:VOTED]->(:Reply {{id:{reply_id}}}) RETURN r.vote_type as vt"
                vote_res = crud.execute_cypher(cursor, cypher_vote, fetch_one=True)
                vote_map = utils.parse_agtype(vote_res)
                if isinstance(vote_map, dict) and 'vt' in vote_map:
                    has_upvoted = vote_map['vt'] == True
                    has_downvoted = vote_map['vt'] == False

                # Check favorite
                cypher_fav = f"RETURN EXISTS( (:User {{id:{current_user_id}}})-[:FAVORITED]->(:Reply {{id:{reply_id}}}) ) as fav"
                fav_res = crud.execute_cypher(cursor, cypher_fav, fetch_one=True)
                fav_map = utils.parse_agtype(fav_res)
                is_favorited = fav_map.get('fav', False) if isinstance(fav_map, dict) else False

            reply_data['has_upvoted'] = has_upvoted
            reply_data['has_downvoted'] = has_downvoted
            reply_data['is_favorited'] = is_favorited # Add to schema if not present

            processed_replies.append(schemas.ReplyDisplay(**reply_data)) # Validate

        print(f"✅ Fetched {len(processed_replies)} replies for post {post_id}")
        return processed_replies
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

