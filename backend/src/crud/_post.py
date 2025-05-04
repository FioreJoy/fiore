# backend/src/crud/_post.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses
from .. import utils # Import root utils for quote_cypher_string and potentially get_minio_url

# =========================================
# Post CRUD (Relational + Graph + Media Link)
# =========================================

def create_post_db(
        cursor: psycopg2.extensions.cursor,
        user_id: int,
        title: str,
        content: str,
        community_id: Optional[int] = None
        # Removed image_path parameter
) -> Optional[int]:
    """
    Creates post in public.posts, :Post vertex, and :WROTE edge.
    Linking to community (:HAS_POST edge) and media (post_media table)
    are handled separately by the caller (router) after getting the post_id.
    Requires CALLING function to handle transaction commit/rollback.
    Returns post ID on success.
    """
    post_id = None
    # No try/except here, let caller handle transaction
    # 1. Insert into relational table (without image_path)
    cursor.execute(
        """
        INSERT INTO public.posts (user_id, title, content)
        VALUES (%s, %s, %s) RETURNING id, created_at;
        """,
        (user_id, title, content),
    )
    result = cursor.fetchone()
    if not result or 'id' not in result: return None
    post_id = result['id']
    created_at = result['created_at']
    print(f"CRUD: Inserted post {post_id} into public.posts.")

    # 2. Create :Post vertex
    try:
        # Store minimal props: id, title (searchable), created_at (sorting)
        post_props = {'id': post_id, 'title': title, 'created_at': created_at}
        set_clauses_str = build_cypher_set_clauses('p', post_props)
        cypher_q_vertex = f"CREATE (p:Post {{id: {post_id}}})"
        if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
        print(f"CRUD: Creating AGE vertex for post {post_id}...")
        execute_cypher(cursor, cypher_q_vertex)
        print(f"CRUD: AGE vertex created for post {post_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed to create AGE vertex for new post {post_id}: {age_err}")
        # Allow relational part to succeed, caller handles transaction

    # 3. Create :WROTE edge (User -> Post)
    try:
        created_at_quoted = utils.quote_cypher_string(created_at)
        cypher_q_wrote = f"""
            MATCH (u:User {{id: {user_id}}})
            MATCH (p:Post {{id: {post_id}}})
            MERGE (u)-[r:WROTE]->(p)
            SET r.created_at = {created_at_quoted}
        """
        execute_cypher(cursor, cypher_q_wrote)
        print(f"CRUD: :WROTE edge created for post {post_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed to create :WROTE edge for post {post_id}: {age_err}")
        # Allow relational part to succeed

    # Note: Linking to community (:HAS_POST) is now done via crud.add_post_to_community_db
    # which is called by the router *after* this function succeeds.

    return post_id # Return ID

def get_post_by_id(cursor: psycopg2.extensions.cursor, post_id: int) -> Optional[Dict[str, Any]]:
    """Fetches post details from relational table ONLY. Media/Counts fetched separately."""
    # Removed image_path
    cursor.execute(
        "SELECT id, user_id, content, title, created_at FROM public.posts WHERE id = %s",
        (post_id,)
    )
    return cursor.fetchone()

# --- Fetch post counts from graph (Python counting workaround) ---
def get_post_counts(cursor: psycopg2.extensions.cursor, post_id: int) -> Dict[str, int]:
    cypher_q = f"""
        MATCH (p:Post {{id: {post_id}}})
        OPTIONAL MATCH (reply:Reply)-[:REPLIED_TO]->(p)
        OPTIONAL MATCH (upvoter:User)-[:VOTED {{vote_type: true}}]->(p)
        OPTIONAL MATCH (downvoter:User)-[:VOTED {{vote_type: false}}]->(p)
        OPTIONAL MATCH (favUser:User)-[:FAVORITED]->(p)
        RETURN count(DISTINCT reply) as reply_count,
               count(DISTINCT upvoter) as upvotes,
               count(DISTINCT downvoter) as downvotes,
               count(DISTINCT favUser) as favorite_count
    """
    expected = [('reply_count', 'agtype'), ('upvotes', 'agtype'), ('downvotes', 'agtype'), ('favorite_count', 'agtype')]
    try:
        result_map = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected)
        if isinstance(result_map, dict):
            return {
                "reply_count": int(result_map.get('reply_count', 0)),
                "upvotes": int(result_map.get('upvotes', 0)),
                "downvotes": int(result_map.get('downvotes', 0)),
                "favorite_count": int(result_map.get('favorite_count', 0)),
            }
        else: return {"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0}
    except Exception as e: print(f"Warning: Failed getting graph counts for post {post_id}: {e}"); return {"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0}

# --- Fetch list of posts (Combines relational + graph counts) ---
def get_posts_db(
        cursor: psycopg2.extensions.cursor,
        community_id: Optional[int] = None,
        user_id: Optional[int] = None,
        limit: int = 50,
        offset: int = 0
) -> List[Dict[str, Any]]:
    """
    Fetches posts from relational table, adds graph counts and author/community info.
    Media items are fetched separately by the router.
    """
    # Base query for relational post data (no image_path)
    sql = """
        SELECT
            p.id, p.user_id, p.content, p.title, p.created_at,
            u.username AS author_name,
            u.id AS author_id, -- Include author ID for fetching avatar later
            c.id as community_id,
            c.name as community_name
        FROM public.posts p
        JOIN public.users u ON p.user_id = u.id
        -- Still use relational join for filtering/getting community info
        LEFT JOIN public.community_posts cp ON p.id = cp.post_id
        LEFT JOIN public.communities c ON cp.community_id = c.id
    """
    params = []
    filters = []
    if community_id is not None: filters.append("cp.community_id = %s"); params.append(community_id)
    if user_id is not None: filters.append("p.user_id = %s"); params.append(user_id)

    if filters: sql += " WHERE " + " AND ".join(filters)
    sql += " ORDER BY p.created_at DESC"
    sql += " LIMIT %s OFFSET %s;"
    params.extend([limit, offset])

    cursor.execute(sql, tuple(params))
    posts_relational = cursor.fetchall()

    # Augment with graph counts
    augmented_posts = []
    for post_rel in posts_relational:
        post_data = dict(post_rel)
        post_id = post_data['id']
        counts = {"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0}
        try:
            counts = get_post_counts(cursor, post_id) # Fetch counts
        except Exception as e:
            print(f"CRUD Warning: Failed get counts for post {post_id}: {e}")
        post_data.update(counts)
        augmented_posts.append(post_data)

    return augmented_posts


# --- delete_post_db ---
def delete_post_db(cursor: psycopg2.extensions.cursor, post_id: int) -> bool:
    """
    Deletes post from public.posts AND AGE graph.
    Requires CALLING function to handle media item deletion.
    """
    # 1. Delete from AGE graph
    cypher_q = f"MATCH (p:Post {{id: {post_id}}}) DETACH DELETE p"
    print(f"CRUD: Deleting AGE vertex/edges for post {post_id}...")
    try:
        execute_cypher(cursor, cypher_q)
        print(f"CRUD: AGE vertex/edges deleted for post {post_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed delete AGE vertex for post {post_id}: {age_err}")
        raise age_err # Fail delete if graph part fails

    # 2. Delete from relational table (CASCADE should handle post_media links)
    cursor.execute("DELETE FROM public.posts WHERE id = %s;", (post_id,))
    rows_deleted = cursor.rowcount
    print(f"CRUD: Deleted post {post_id} from public.posts (Rows: {rows_deleted}).")

    return rows_deleted > 0


# --- Complex Graph Query ---
def get_followed_posts_in_community_graph(cursor: psycopg2.extensions.cursor, viewer_id: int, community_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    """
    Fetches posts in a community authored by users the viewer follows.
    Includes basic info and counts fetched via Python count workaround.
    """
    # Fetch IDs first, then counts for each post (less efficient but bypasses count() bug)
    cypher_ids = f"""
        MATCH (viewer:User {{id: {viewer_id}}})-[:FOLLOWS]->(author:User)-[:WROTE]->(p:Post)
        MATCH (:Community {{id: {community_id}}})-[:HAS_POST]->(p)
        RETURN p.id as id, author.id as author_id
        ORDER BY p.created_at DESC  // Assuming created_at IS stored on Post vertex now
        SKIP {offset}
        LIMIT {limit}
    """
    try:
        print(f"CRUD: Fetching followed post IDs in comm {community_id} for viewer {viewer_id}")
        post_author_ids = execute_cypher(cursor, cypher_ids, fetch_all=True, expected_columns=expected) or []

        results = []
        for item in post_author_ids:
            if not isinstance(item, dict) or 'id' not in item or 'author_id' not in item: continue
            post_id = item['id']
            author_id = item['author_id']

            # Fetch relational details for post and author
            post_details = get_post_by_id(cursor, post_id)
            author_details = crud.get_user_by_id(cursor, author_id) # Use user crud function
            community_details = crud.get_community_by_id(cursor, community_id) # Get comm name

            if post_details and author_details:
                post_data = dict(post_details)
                post_data['author_name'] = author_details.get('username')
                post_data['author_avatar'] = author_details.get('image_path') # Get path for URL gen
                post_data['community_id'] = community_id
                post_data['community_name'] = community_details.get('name') if community_details else None

                # Fetch counts for this post
                counts = get_post_counts(cursor, post_id)
                post_data.update(counts)
                results.append(post_data)
            else:
                print(f"Warning: Couldn't fetch full details for followed post {post_id} or author {author_id}")

        return results

    except Exception as e:
        print(f"CRUD Error get_followed_posts C:{community_id} V:{viewer_id}: {e}")
        raise
def add_post_to_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> bool:
    """Creates :HAS_POST edge from Community to Post."""
    # Use datetime directly
    now_iso = datetime.now(timezone.utc).isoformat()
    added_at_quoted = utils.quote_cypher_string(now_iso)
    # ... rest of function using execute_cypher ...
    cypher_q = f"""
        MATCH (c:Community {{id: {community_id}}}) MATCH (p:Post {{id: {post_id}}})
        MERGE (c)-[r:HAS_POST]->(p) SET r.added_at = {added_at_quoted} """
    try: return execute_cypher(cursor, cypher_q)
    except Exception as e: print(f"Error adding post to community: {e}"); return False

def remove_post_from_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> bool:
    """Deletes :HAS_POST edge between Community and Post."""
    # Avoid count()
    cypher_q = f"MATCH (c:Community {{id: {community_id}}})-[r:HAS_POST]->(p:Post {{id: {post_id}}}) DELETE r"
    try: return execute_cypher(cursor, cypher_q) # Assume success if no error
    except Exception as e: print(f"Error removing post from community: {e}"); return False