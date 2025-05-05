# src/crud/_search.py

import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any

from .. import utils # For get_minio_url if adding image paths directly

def search_all(
    cursor: psycopg2.extensions.cursor,
    search_query: str,
    entity_type: Optional[str] = None, # 'user', 'community', 'post', or None for all
    limit: int = 20,
    offset: int = 0
) -> List[Dict[str, Any]]:
    """
    Performs a full-text search across users, communities, and posts.
    Returns a list of results suitable for the SearchResultItem schema.
    """
    # Use websearch_to_tsquery for more flexibility with user input
    # Use 'english' config, consider making configurable or using 'simple'
    # Add coalesce to handle potential NULLs in indexed columns
    ts_query_sql = "websearch_to_tsquery('english', %s)"

    # Build parts of the UNION ALL query
    select_parts = []
    params = []

    # --- User Search ---
    if not entity_type or entity_type == 'user':
        select_parts.append(f"""
            SELECT
                id,
                'user' AS type,
                username AS name,
                name AS snippet, -- Use real name as snippet? Or college?
                NULL AS image_url_placeholder, -- Placeholder, URL generated later
                NULL AS author_name,
                NULL AS community_name,
                created_at, -- User creation time
                ts_rank_cd(to_tsvector('english', coalesce(name, '') || ' ' || coalesce(username, '')), query) AS rank
            FROM public.users, {ts_query_sql} query
            WHERE query @@ to_tsvector('english', coalesce(name, '') || ' ' || coalesce(username, ''))
        """)
        params.append(search_query)

    # --- Community Search ---
    if not entity_type or entity_type == 'community':
         select_parts.append(f"""
            SELECT
                c.id,
                'community' AS type,
                c.name AS name,
                c.description AS snippet,
                cl.media_id AS image_url_placeholder, -- Get media ID for logo
                NULL AS author_name,
                NULL AS community_name,
                c.created_at,
                ts_rank_cd(to_tsvector('english', coalesce(c.name, '') || ' ' || coalesce(c.description, '')), query) AS rank
            FROM public.communities c
            LEFT JOIN public.community_logo cl ON c.id = cl.community_id, -- Join to get logo media ID
            {ts_query_sql} query
            WHERE query @@ to_tsvector('english', coalesce(c.name, '') || ' ' || coalesce(c.description, ''))
        """)
         params.append(search_query)

    # --- Post Search ---
    if not entity_type or entity_type == 'post':
         select_parts.append(f"""
            SELECT
                p.id,
                'post' AS type,
                p.title AS name,
                p.content AS snippet, -- Consider truncating snippet later
                pm.media_id AS image_url_placeholder, -- Get first media ID for post image
                u.username AS author_name,
                coalesce(cm.name, '') AS community_name, -- Get community name if linked
                p.created_at,
                ts_rank_cd(to_tsvector('english', coalesce(p.title, '') || ' ' || coalesce(p.content, '')), query) AS rank
            FROM public.posts p
            JOIN public.users u ON p.user_id = u.id -- Join for author name
            LEFT JOIN public.community_posts cp ON p.id = cp.post_id -- Join to get community link
            LEFT JOIN public.communities cm ON cp.community_id = cm.id -- Join to get community name
            LEFT JOIN ( -- Subquery to get the *first* media item for a post
                 SELECT DISTINCT ON (post_id) post_id, media_id
                 FROM public.post_media
                 ORDER BY post_id, display_order ASC, media_id ASC -- Define order to get consistent first media
            ) pm ON p.id = pm.post_id,
            {ts_query_sql} query
            WHERE query @@ to_tsvector('english', coalesce(p.title, '') || ' ' || coalesce(p.content, ''))
        """)
         params.append(search_query)

    if not select_parts:
        return [] # No valid entity type selected

    # Combine parts with UNION ALL
    full_query = " UNION ALL ".join(select_parts)

    # Add ordering and pagination
    full_query = f"""
        SELECT id, type, name, snippet, image_url_placeholder, author_name, community_name, created_at
        FROM ({full_query}) AS combined_results
        ORDER BY rank DESC, created_at DESC
        LIMIT %s OFFSET %s;
    """
    params.extend([limit, offset])

    print(f"CRUD Search Query: {full_query[:500]}...") # Log truncated query
    # print(f"CRUD Search Params: {params}") # Careful logging params

    try:
        cursor.execute(full_query, tuple(params))
        results = cursor.fetchall()
        print(f"CRUD Search: Found {len(results)} raw results.")
        return results # Return list of dicts (RealDictRow)
    except psycopg2.Error as db_err:
        print(f"!!! DB Search Error ({db_err.pgcode}): {db_err}")
        print(f"    Query approx: {full_query[:500]}...")
        raise db_err # Re-raise for router handling
    except Exception as e:
        print(f"!!! Unexpected Search Error: {e}")
        raise e
