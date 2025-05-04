# backend/src/routers/replies.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, File, UploadFile
from typing import List, Optional, Dict, Any # Added Dict, Any
import psycopg2
import traceback # Ensure import

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
        # Change parameters to use Form and File
        current_user_id: int = Depends(auth.get_current_user),
        post_id: int = Form(...),
        content: str = Form(...),
        parent_reply_id: Optional[int] = Form(None),
        files: List[UploadFile] = File(default=[]) # Accept files
):
    """ Creates a new reply (relational + graph) with optional media. """
    conn = None
    reply_id = None
    media_ids_created = []
    minio_objects_created = []
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Call the combined create function (relational + graph)
        reply_id = crud.create_reply_db( # Use crud prefix
            cursor, post_id=post_id, user_id=current_user_id,
            content=content, parent_reply_id=parent_reply_id
        )
        if reply_id is None: raise HTTPException(status_code=500, detail="Reply base creation failed")

        # Link Media (similar to posts)
        for file in files:
            if file and file.filename:
                object_name_prefix = f"media/replies/{reply_id}" # Path for reply media
                upload_info = await utils.upload_file_to_minio(file, object_name_prefix)
                if upload_info:
                    minio_objects_created.append(upload_info['minio_object_name'])
                    media_id = crud.create_media_item(cursor, uploader_user_id=current_user_id, **upload_info)
                    if media_id:
                        media_ids_created.append(media_id)
                        crud.link_media_to_reply(cursor, reply_id, media_id) # Use correct linking function
                    else: print(f"WARN: Failed media_item record for reply {reply_id}")
                else: print(f"WARN: Failed upload for reply {reply_id}")

        # Fetch created reply details (needs adaptation or new function)
        # Fetch relational
        created_reply_relational = crud.get_reply_by_id(cursor, reply_id)
        if not created_reply_relational: raise HTTPException(status_code=500, detail="Could not retrieve created reply")
        created_reply_data = dict(created_reply_relational)
        # Fetch author
        author_info = crud.get_user_by_id(cursor, created_reply_data['user_id'])
        if author_info: created_reply_data['author_name']=author_info.get('username'); created_reply_data['author_avatar'] = author_info.get('image_path')
        else: created_reply_data['author_name'] = "Unknown"; created_reply_data['author_avatar'] = None
        # Fetch counts
        try: counts = crud.get_reply_counts(cursor, reply_id); created_reply_data.update(counts)
        except Exception as e: print(f"WARN: Failed counts R:{reply_id}: {e}"); created_reply_data.update({"upvotes": 0, "downvotes": 0, "favorite_count": 0})
        # Fetch media
        try: media_items = crud.get_media_items_for_reply(cursor, reply_id); created_reply_data['media'] = media_items
        except Exception as e: print(f"WARN: Failed media R:{reply_id}: {e}"); created_reply_data['media'] = []

        conn.commit()

        # Prepare response
        response_data = created_reply_data
        response_data['author_avatar_url'] = utils.get_minio_url(response_data.get('author_avatar'))
        response_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in response_data.get('media', []) ]
        response_data['viewer_vote_type'] = None; response_data['viewer_has_favorited'] = False
        # Ensure defaults for counts
        response_data.setdefault('upvotes', 0); response_data.setdefault('downvotes', 0); response_data.setdefault('favorite_count', 0)

        print(f"✅ Reply {reply_id} created by User {current_user_id} for Post {post_id}")
        return schemas.ReplyDisplay(**response_data)

    # ... (Error Handling - Adapt from create_post) ...
    except HTTPException as http_exc:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        print(f"❌ DB Error creating reply: {e} (Code: {e.pgcode})")
        detail = f"Database error: {e.pgerror}"
        if e.pgcode == '23503': detail = "Invalid post_id or parent_reply_id provided."
        raise HTTPException(status_code=400, detail=detail)
    except Exception as e:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        print(f"❌ Unexpected Error creating reply: {e}")
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
        replies_db = crud.get_replies_for_post_db(cursor, post_id)

        processed_replies = []
        for reply in replies_db:
            reply_data = dict(reply)
            reply_id = reply_data['id'] # Get reply ID

            # Generate author avatar URL
            author_avatar_path = reply.get('author_avatar')
            reply_data['author_avatar_url'] = utils.get_minio_url(author_avatar_path)

            # --- Fetch and Attach Media ---
            try:
                media_items = crud.get_media_items_for_reply(cursor, reply_id) # Use the correct getter
                reply_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items ]
                print(f"DEBUG GET /replies/{post_id}: Fetched {len(media_items)} media for reply {reply_id}") # Log
            except Exception as e:
                print(f"WARN: Failed fetching media for reply {reply_id}: {e}")
                reply_data['media'] = [] # Ensure 'media' key exists as empty list
            # --- End Fetch Media ---


            # Get viewer status using CRUD functions if authenticated
            # ... (keep existing vote/favorite status check logic) ...
            viewer_vote = None; is_favorited = False
            if current_user_id is not None:
                try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=None, reply_id=reply_id)
                except Exception as vote_err: print(f"WARN: Failed vote status R:{reply_id} U:{current_user_id}: {vote_err}")
                try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=None, reply_id=reply_id)
                except Exception as fav_err: print(f"WARN: Failed fav status R:{reply_id} U:{current_user_id}: {fav_err}")
            reply_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
            reply_data['viewer_has_favorited'] = is_favorited


            # Add defaults for counts if potentially missing
            reply_data.setdefault('upvotes', 0); reply_data.setdefault('downvotes', 0); reply_data.setdefault('favorite_count', 0)
            # Ensure media key exists even if fetch failed
            reply_data.setdefault('media', [])


            try:
                processed_replies.append(schemas.ReplyDisplay(**reply_data))
            except Exception as pydantic_err:
                print(f"ERROR: Pydantic validation failed for reply {reply_data.get('id', 'N/A')} in post {post_id}: {pydantic_err}")
                print(f"      Data: {reply_data}")


        print(f"✅ Fetched {len(processed_replies)} replies for post {post_id}")
        return processed_replies
    except psycopg2.Error as db_err:
        print(f"DB Error GET /replies/{post_id}: {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching replies")
    except Exception as e:
        print(f"❌ Error fetching replies for post {post_id}: {e}")
        traceback.print_exc() # Ensure traceback is imported
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

