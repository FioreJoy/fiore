# src/crud/_feed.py

import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any

from ._graph import execute_cypher
# Import other CRUD functions needed to augment post details
from ._post import get_post_by_id, get_post_counts
from ._user import get_user_by_id
from ._community import get_community_by_id # To get community name if post is linked
# --- Corrected Media Import ---
from ._media import get_media_items_for_post, get_media_item_by_id, get_user_profile_picture_media # <-- ADD IT HERE

def get_following_feed(
        cursor: psycopg2.extensions.cursor,
        viewer_id: int,
        limit: int = 20,
        offset: int = 0
) -> List[Dict[str, Any]]:
    """
    Fetches posts from users followed by the viewer using graph traversal.
    Then augments results with relational data (N+1 issue exists).
    """
    print(f"CRUD: Fetching following feed for User ID: {viewer_id}, Limit: {limit}, Offset: {offset}")

    # 1. Get Post IDs and Author IDs from Graph
    cypher_q = f"""
        MATCH (viewer:User {{id: {viewer_id}}})-[:FOLLOWS]->(author:User)-[:WROTE]->(p:Post)
        RETURN p.id as post_id, p.created_at as post_created_at, author.id as author_id
        ORDER BY p.created_at DESC
        SKIP {offset} LIMIT {limit}
    """
    expected_cols = [('post_id', 'agtype'), ('post_created_at', 'agtype'), ('author_id', 'agtype')]
    post_author_refs = []
    try:
        post_author_refs = execute_cypher(cursor, cypher_q, fetch_all=True, expected_columns=expected_cols) or []
        print(f"CRUD: Found {len(post_author_refs)} post references from followed users.")
    except Exception as e:
        print(f"CRUD ERROR fetching following feed graph query: {e}")
        raise e

    # 2. Augment results with details
    feed_items = []
    for ref in post_author_refs:
        if not isinstance(ref, dict): continue
        post_id = ref.get('post_id')
        author_id = ref.get('author_id')
        if not post_id or not author_id: continue

        try:
            post_details = get_post_by_id(cursor, post_id)
            if not post_details: continue
            post_data = dict(post_details)

            author_details = get_user_by_id(cursor, author_id)
            post_data['author_name'] = author_details.get('username') if author_details else 'Unknown'

            # Fetch Author Avatar URL properly using get_user_profile_picture_media
            author_avatar_media = get_user_profile_picture_media(cursor, author_id) # Now function is imported
            post_data['author_avatar'] = author_avatar_media.get('minio_object_name') if author_avatar_media else None

            # Fetch Community Link
            cypher_q_comm = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {post_id}}}) RETURN c.id as id, c.name as name LIMIT 1"
            expected_comm = [('id', 'agtype'), ('name', 'agtype')]
            comm_res = execute_cypher(cursor, cypher_q_comm, fetch_one=True, expected_columns=expected_comm)
            post_data['community_id'] = comm_res.get('id') if comm_res else None
            post_data['community_name'] = comm_res.get('name') if comm_res else None

            # Fetch Counts
            counts = get_post_counts(cursor, post_id)
            post_data.update(counts)

            # Fetch Media items
            media_items = get_media_items_for_post(cursor, post_id)
            post_data['media'] = media_items

            feed_items.append(post_data)

        except Exception as augment_err:
            print(f"WARN: Failed to augment details for post {post_id} in following feed: {augment_err}")
            # Log the traceback for debugging augmentation errors
            import traceback
            traceback.print_exc()

    print(f"CRUD: Returning {len(feed_items)} fully augmented feed items.")
    return feed_items

# --- ADD DISCOVER/TRENDING FEED FUNCTION ---
def get_discover_feed(
        cursor: psycopg2.extensions.cursor,
        viewer_id: Optional[int], # Optional: May use for personalization later
        limit: int = 20,
        offset: int = 0,
        time_window_hours: int = 48 # How far back to look for activity score
) -> List[Dict[str, Any]]:
    """
    Fetches posts for discovery/trending feed.
    Current implementation ranks by an activity score based on recent votes and replies.
    Falls back to recent posts if scoring fails.
    """
    print(f"CRUD: Fetching discover feed. Limit: {limit}, Offset: {offset}, Window: {time_window_hours}h")

    # --- Option 1: Simple Recency (Fallback or Initial Implementation) ---
    # sql = """
    #     SELECT p.*, u.username as author_name
    #     FROM public.posts p
    #     JOIN public.users u ON p.user_id = u.id
    #     ORDER BY p.created_at DESC
    #     LIMIT %s OFFSET %s;
    # """
    # params = (limit, offset)

    # --- Option 2: Activity Score Based Ranking (More Complex) ---
    # Weights for scoring (adjust as needed)
    vote_weight = 2
    reply_weight = 3
    # Add more factors like favorites, shares, time decay later

    sql = f"""
        WITH RecentActivity AS (
            -- Calculate recent activity score for each post
            SELECT
                p.id as post_id,
                p.created_at,
                (COALESCE(rv.vote_score, 0) + COALESCE(rr.reply_score, 0)) /
                    -- Optional: Apply time decay (e.g., divide by age in hours + 1)
                    -- GREATEST(1, EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 3600)
                    1.0 -- No time decay for now
                    AS activity_score
            FROM public.posts p
            LEFT JOIN (
                -- Recent Upvotes Score
                SELECT post_id, COUNT(*) * %s AS vote_score
                FROM public.votes
                WHERE vote_type = true AND created_at >= NOW() - INTERVAL '%s hours'
                GROUP BY post_id
            ) rv ON p.id = rv.post_id
            LEFT JOIN (
                -- Recent Replies Score
                SELECT post_id, COUNT(*) * %s AS reply_score
                FROM public.replies
                WHERE created_at >= NOW() - INTERVAL '%s hours'
                GROUP BY post_id
            ) rr ON p.id = rr.post_id
            -- Only consider posts from the last week for trending? (Optional)
            -- WHERE p.created_at >= NOW() - INTERVAL '7 days'
        )
        -- Select post details JOINED with score and order
        SELECT
            p.*, -- Select all columns from posts
            u.username AS author_name,
            ra.activity_score
        FROM public.posts p
        JOIN public.users u ON p.user_id = u.id
        JOIN RecentActivity ra ON p.id = ra.post_id
        ORDER BY
            ra.activity_score DESC, -- Primary sort: activity score
            p.created_at DESC      -- Secondary sort: creation date
        LIMIT %s OFFSET %s;
    """
    params = (
        vote_weight, time_window_hours,
        reply_weight, time_window_hours,
        limit, offset
    )

    try:
        cursor.execute(sql, params)
        posts_db = cursor.fetchall()
        print(f"CRUD: Discover feed query returned {len(posts_db)} posts.")

        # Augment results (N+1 again)
        discover_items = []
        for post_row in posts_db:
            try:
                post_data = dict(post_row)
                post_id = post_data['id']
                author_id = post_data['user_id']

                # Author Avatar (using helper function now)
                author_avatar_media = get_user_profile_picture_media(cursor, author_id)
                post_data['author_avatar'] = author_avatar_media.get('minio_object_name') if author_avatar_media else None

                # Community Info (using helper function)
                cypher_q_comm = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {post_id}}}) RETURN c.id as id, c.name as name LIMIT 1"
                expected_comm = [('id', 'agtype'), ('name', 'agtype')]
                comm_res = execute_cypher(cursor, cypher_q_comm, fetch_one=True, expected_columns=expected_comm)
                post_data['community_id'] = comm_res.get('id') if comm_res else None
                post_data['community_name'] = comm_res.get('name') if comm_res else None

                # Counts (using helper function)
                counts = get_post_counts(cursor, post_id)
                post_data.update(counts)

                # Media (using helper function)
                media_items = get_media_items_for_post(cursor, post_id)
                post_data['media'] = media_items

                discover_items.append(post_data)
            except Exception as augment_err:
                print(f"WARN: Failed to augment details for post {post_data.get('id','N/A')} in discover feed: {augment_err}")

        print(f"CRUD: Returning {len(discover_items)} augmented discover items.")
        return discover_items

    except psycopg2.Error as db_err:
        print(f"!!! DB Discover Feed Error ({db_err.pgcode}): {db_err}")
        # Fallback to simple recency if scoring fails? Or just raise.
        raise db_err
    except Exception as e:
        print(f"!!! Unexpected Discover Feed Error: {e}")
        raise e
