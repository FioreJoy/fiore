# src/routers/feed.py

from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional, Dict, Any
import psycopg2
import traceback

from .. import schemas, crud, auth, utils, security
from ..database import get_db_connection

router = APIRouter(
    prefix="/feed",
    tags=["Feeds"],
    # Apply auth based on endpoint needs
)

@router.get("/following", response_model=List[schemas.PostDisplay])
async def get_feed_following(
        current_user_id: int = Depends(auth.get_current_user), # Requires auth
        limit: int = Query(20, ge=1, le=100),
        offset: int = Query(0, ge=0),
):
    # ... (Implementation from previous step) ...
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        feed_items_db = crud.get_following_feed(cursor, current_user_id, limit, offset)
        processed_feed: List[schemas.PostDisplay] = []
        for item_db in feed_items_db:
            post_data = dict(item_db); post_id = post_data['id']
            media_list_processed = []
            if 'media' in post_data and isinstance(post_data['media'], list):
                for media_item in post_data['media']:
                    media_dict = dict(media_item); media_dict['url'] = utils.get_minio_url(media_dict.get('minio_object_name')); media_list_processed.append(schemas.MediaItemDisplay(**media_dict))
            post_data['media'] = media_list_processed
            author_avatar_path = post_data.get('author_avatar') # Get path stored by CRUD
            post_data['author_avatar_url'] = utils.get_minio_url(author_avatar_path)
            viewer_vote = None; is_favorited = False # Fetch viewer status
            try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=post_id)
            except Exception as e: print(f"WARN feed: vote status check failed P:{post_id}: {e}")
            try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=post_id)
            except Exception as e: print(f"WARN feed: fav status check failed P:{post_id}: {e}")
            post_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
            post_data['viewer_has_favorited'] = is_favorited
            post_data.setdefault('upvotes', 0); post_data.setdefault('downvotes', 0); post_data.setdefault('reply_count', 0); post_data.setdefault('favorite_count', 0); post_data.setdefault('image_url', None)
            try: processed_feed.append(schemas.PostDisplay(**post_data))
            except Exception as pydantic_err: print(f"ERROR: Pydantic validation failed for following feed post {post_id}: {pydantic_err}\nData: {post_data}")
        return processed_feed
    except psycopg2.Error as db_err: print(f"DB Error fetching following feed for user {current_user_id}: {db_err}"); raise HTTPException(status_code=500, detail="Database error fetching feed.")
    except Exception as e: print(f"Unexpected error fetching following feed for user {current_user_id}: {e}"); traceback.print_exc(); raise HTTPException(status_code=500, detail="An error occurred while fetching the feed.")
    finally:
        if conn: conn.close()


# --- ADD DISCOVER ENDPOINT ---
@router.get("/discover", response_model=List[schemas.PostDisplay])
async def get_feed_discover(
        # Auth is optional for discover feed
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional),
        limit: int = Query(20, ge=1, le=100),
        offset: int = Query(0, ge=0),
):
    """
    Fetches posts for discovery, potentially ranked by recent activity.
    """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Call the new CRUD function
        feed_items_db = crud.get_discover_feed(cursor, current_user_id, limit, offset)

        # Process results (same augmentation logic as following feed)
        processed_feed: List[schemas.PostDisplay] = []
        for item_db in feed_items_db:
            post_data = dict(item_db)
            post_id = post_data['id']

            # Generate media URLs
            media_list_processed = []
            if 'media' in post_data and isinstance(post_data['media'], list):
                for media_item in post_data['media']:
                    media_dict = dict(media_item)
                    media_dict['url'] = utils.get_minio_url(media_dict.get('minio_object_name'))
                    media_list_processed.append(schemas.MediaItemDisplay(**media_dict))
            post_data['media'] = media_list_processed

            # Generate author avatar URL
            author_avatar_path = post_data.get('author_avatar')
            post_data['author_avatar_url'] = utils.get_minio_url(author_avatar_path)

            # Fetch viewer vote/favorite status only if user is logged in
            viewer_vote = None; is_favorited = False
            if current_user_id is not None:
                try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=post_id)
                except Exception as e: print(f"WARN discover feed: vote status check failed P:{post_id}: {e}")
                try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=post_id)
                except Exception as e: print(f"WARN discover feed: fav status check failed P:{post_id}: {e}")

            post_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
            post_data['viewer_has_favorited'] = is_favorited

            # Ensure defaults
            post_data.setdefault('upvotes', 0); post_data.setdefault('downvotes', 0); post_data.setdefault('reply_count', 0); post_data.setdefault('favorite_count', 0); post_data.setdefault('image_url', None)

            try:
                processed_feed.append(schemas.PostDisplay(**post_data))
            except Exception as pydantic_err:
                print(f"ERROR: Pydantic validation failed for discover feed post {post_id}: {pydantic_err}\nData: {post_data}")

        return processed_feed

    except psycopg2.Error as db_err:
        print(f"DB Error fetching discover feed: {db_err}")
        raise HTTPException(status_code=500, detail="Database error fetching discover feed.")
    except Exception as e:
        print(f"Unexpected error fetching discover feed: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="An error occurred while fetching the discover feed.")
    finally:
        if conn: conn.close()