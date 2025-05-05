# src/routers/search.py

from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional, Dict, Any, Literal
import psycopg2

from .. import schemas, crud, auth, utils, security # Import utils
from ..database import get_db_connection
# Import specific CRUD functions if needed (e.g., for getting media paths)
from ..crud import get_media_item_by_id # Example (needs implementation in _media.py)

router = APIRouter(
    prefix="/search",
    tags=["Search"],
    # Apply API key dependency - search can be public, but maybe rate-limited
    dependencies=[Depends(security.get_api_key)]
)

# --- Temporary Helper (Move to crud/_media.py later) ---
def get_media_object_name_by_id(cursor, media_id: int) -> Optional[str]:
    """ Fetches minio_object_name for a given media_id. """
    if not media_id: return None
    try:
        cursor.execute("SELECT minio_object_name FROM public.media_items WHERE id = %s", (media_id,))
        result = cursor.fetchone()
        return result['minio_object_name'] if result else None
    except Exception as e:
        print(f"WARN: Failed to get media object name for ID {media_id}: {e}")
        return None
# --- End Temporary Helper ---


@router.get("", response_model=schemas.SearchResponse)
async def perform_search(
    q: str = Query(..., min_length=1, description="Search query term"),
    type: Optional[Literal['user', 'community', 'post']] = Query(None, description="Filter results by type"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    # Optional auth to personalize results later if needed
    # current_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    """Performs a full-text search across users, communities, and posts."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Call CRUD search function
        search_results_db = crud.search_all(
            cursor, search_query=q, entity_type=type, limit=limit, offset=offset
        )

        # Process results to generate image URLs and format snippet
        processed_results: List[schemas.SearchResultItem] = []
        for item_db in search_results_db:
            item_dict = dict(item_db)
            item_type = item_dict.get('type')
            media_id_placeholder = item_dict.get('image_url_placeholder') # Media ID from search query
            image_url = None

            # Fetch object name based on type and placeholder (media_id)
            # This requires extra queries - potentially optimize later
            object_name = None
            if media_id_placeholder:
                 object_name = get_media_object_name_by_id(cursor, media_id_placeholder)
                 if object_name: image_url = utils.get_minio_url(object_name)

            # If no specific media ID, try fetching based on user/community ID (less direct)
            elif item_type == 'user':
                user_media = crud.get_user_profile_picture_media(cursor, item_dict['id'])
                image_url = user_media.get('url') if user_media else None
            elif item_type == 'community':
                comm_media = crud.get_community_logo_media(cursor, item_dict['id'])
                image_url = comm_media.get('url') if comm_media else None

            # Truncate snippet if needed
            snippet = item_dict.get('snippet')
            if snippet and len(snippet) > 150:
                 snippet = snippet[:150] + '...'

            processed_results.append(
                schemas.SearchResultItem(
                    id=item_dict['id'],
                    type=item_type,
                    name=item_dict['name'],
                    snippet=snippet,
                    image_url=image_url,
                    author_name=item_dict.get('author_name'),
                    community_name=item_dict.get('community_name'),
                    created_at=item_dict.get('created_at')
                )
            )

        # TODO: Implement total_estimated count if performant (might require separate COUNT query)

        return schemas.SearchResponse(
            query=q,
            results=processed_results,
            offset=offset,
            limit=limit
        )

    except psycopg2.Error as db_err:
        print(f"DB Error during search for '{q}': {db_err}")
        raise HTTPException(status_code=500, detail="Database error during search.")
    except Exception as e:
        print(f"Unexpected error during search for '{q}': {e}")
        traceback.print_exc() # Ensure traceback is imported
        raise HTTPException(status_code=500, detail="An error occurred during search.")
    finally:
        if conn: conn.close()
