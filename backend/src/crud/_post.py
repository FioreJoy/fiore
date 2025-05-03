# backend/src/crud/_post.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses, get_graph_counts
from .. import utils # Import root utils for quote_cypher_string

# =========================================
# Post CRUD (Relational + Graph)
# =========================================

def create_post_db(
    cursor: psycopg2.extensions.cursor, user_id: int, title: str, content: str,
    image_path: Optional[str] = None, community_id: Optional[int] = None
) -> Optional[int]:
    """
    Creates post in public.posts, :Post vertex, :WROTE edge, and optional :HAS_POST edge.
    Requires CALLING function to handle transaction commit/rollback.
    """
    post_id = None
    # No try/except here, let caller handle transaction
    # 1. Insert into public.posts
    cursor.execute(
        """
        INSERT INTO public.posts (user_id, title, content, image_path)
        VALUES (%s, %s, %s, %s) RETURNING id, created_at;
        """,
        (user_id, title, content, image_path),
    )
    result = cursor.fetchone()
    if not result or 'id' not in result: return None
    post_id = result['id']
    created_at = result['created_at']
    print(f"CRUD: Inserted post {post_id} into public.posts.")

    # 2. Create :Post vertex
    post_props = {'id': post_id, 'title': title, 'created_at': created_at} # Store props needed for graph queries
    set_clauses_str = build_cypher_set_clauses('p', post_props)
    cypher_q_vertex = f"CREATE (p:Post {{id: {post_id}}})"
    if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
    print(f"CRUD: Creating AGE vertex for post {post_id}...")
    execute_cypher(cursor, cypher_q_vertex)
    print(f"CRUD: AGE vertex created for post {post_id}.")

    # 3. Create :WROTE edge (User -> Post)
    created_at_quoted = utils.quote_cypher_string(created_at)
    cypher_q_wrote = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (p:Post {{id: {post_id}}})
        MERGE (u)-[r:WROTE]->(p)
        SET r.created_at = {created_at_quoted}
    """
    execute_cypher(cursor, cypher_q_wrote)
    print(f"CRUD: :WROTE edge created for post {post_id}.")

    # 4. Optionally create :HAS_POST edge (Community -> Post)
    if community_id is not None:
        added_at_quoted = quote_cypher_string(created_at) # Use post creation time
        cypher_q_has_post = f"""
            MATCH (c:Community {{id: {community_id}}})
            MATCH (p:Post {{id: {post_id}}})
            MERGE (c)-[r:HAS_POST]->(p)
            SET r.added_at = {added_at_quoted}
        """
        execute_cypher(cursor, cypher_q_has_post)
        print(f"CRUD: :HAS_POST edge created for post {post_id} in community {community_id}.")

    return post_id # Return ID on success

def get_post_by_id(cursor: psycopg2.extensions.cursor, post_id: int) -> Optional[Dict[str, Any]]:
    """Fetches post details from relational table ONLY."""
    # Counts and graph-specific data fetched separately
    cursor.execute(
        "SELECT id, user_id, content, title, created_at, image_path FROM public.posts WHERE id = %s",
        (post_id,)
    )
    return cursor.fetchone()

# --- Fetch post counts from graph ---
def get_post_counts(cursor: psycopg2.extensions.cursor, post_id: int) -> Dict[str, int]:
    """Fetches reply count and vote counts for a post from AGE graph."""
    # This uses the generic graph count helper
    count_specs = [
        {'name': 'reply_count', 'pattern': '(rep:Reply)-[:REPLIED_TO]->(n)', 'distinct_var': 'rep'},
        {'name': 'upvotes', 'pattern': '(uv:User)-[:VOTED {vote_type: true}]->(n)', 'distinct_var': 'uv'},
        {'name': 'downvotes', 'pattern': '(dv:User)-[:VOTED {vote_type: false}]->(n)', 'distinct_var': 'dv'},
        {'name': 'favorite_count', 'pattern': '(fv:User)-[:FAVORITED]->(n)', 'distinct_var': 'fv'} # Added favorite count
    ]
    return get_graph_counts(cursor, 'Post', post_id, count_specs)

# --- Fetch list of posts (combines relational + graph) ---
def get_posts_db(
    cursor: psycopg2.extensions.cursor,
    community_id: Optional[int] = None,
    user_id: Optional[int] = None,
    limit: int = 50, # Added limit/offset
    offset: int = 0
) -> List[Dict[str, Any]]:
    """ Fetches posts from relational table, adds graph counts and author/community info."""
    # Base query for relational post data
    sql = """
        SELECT
            p.id, p.user_id, p.content, p.title, p.created_at, p.image_path,
            u.username AS author_name,
            u.image_path AS author_avatar, -- Relational user table still has image path
            c.id as community_id,           -- Get community ID if joined
            c.name as community_name        -- Get community name if joined
        FROM public.posts p
        JOIN public.users u ON p.user_id = u.id
        -- LEFT JOIN needed to filter by community *and* get community name if present
        -- Note: Using the relational community_posts table here for filtering still works
        -- even if we also model HAS_POST in the graph, as long as the table isn't dropped.
        -- If community_posts is dropped, filtering needs a graph query first.
        LEFT JOIN public.community_posts cp ON p.id = cp.post_id
        LEFT JOIN public.communities c ON cp.community_id = c.id
    """
    params = []
    filters = []
    if community_id is not None:
        # Ensure posts are linked to the specific community via the relational table
        filters.append("cp.community_id = %s")
        params.append(community_id)
    if user_id is not None:
        filters.append("p.user_id = %s")
        params.append(user_id)

    if filters:
        sql += " WHERE " + " AND ".join(filters)
    sql += " ORDER BY p.created_at DESC" # Order by creation time
    sql += " LIMIT %s OFFSET %s;" # Add pagination
    params.extend([limit, offset])

    cursor.execute(sql, tuple(params))
    posts_relational = cursor.fetchall()

    # Augment with graph counts
    augmented_posts = []
    for post_rel in posts_relational:
        post_data = dict(post_rel)
        post_id = post_data['id']
        # Fetch counts for this post
        try:
            counts = get_post_counts(cursor, post_id)
            post_data.update(counts)
        except Exception as e:
             print(f"CRUD Warning: Failed to get graph counts for post {post_id}: {e}")
             # Add default counts if graph query fails
             post_data.update({"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0})

        augmented_posts.append(post_data)

    return augmented_posts


def delete_post_db(cursor: psycopg2.extensions.cursor, post_id: int) -> bool:
    """
    Deletes post from public.posts AND AGE graph (:Post vertex and relationships).
    Requires CALLING function to handle transaction commit/rollback.
    """
    # 1. Delete from AGE graph using DETACH DELETE
    cypher_q = f"MATCH (p:Post {{id: {post_id}}}) DETACH DELETE p"
    print(f"CRUD: Deleting AGE vertex and edges for post {post_id}...")
    execute_cypher(cursor, cypher_q) # Assumes raises on error
    print(f"CRUD: AGE vertex/edges deleted for post {post_id}.")

    # 2. Delete from relational table
    cursor.execute("DELETE FROM public.posts WHERE id = %s;", (post_id,))
    rows_deleted = cursor.rowcount
    print(f"CRUD: Deleted post {post_id} from public.posts (Rows affected: {rows_deleted}).")

    return rows_deleted > 0

# --- NEW Complex Graph Query Function ---
def get_followed_posts_in_community_graph(cursor: psycopg2.extensions.cursor, viewer_id: int, community_id: int, limit: int, offset: int) -> List[Dict[str, Any]]:
    """
    Fetches posts in a specific community authored by users the viewer follows.
    Includes basic post/author info and graph-based counts.
    """
    # This query combines following, authorship, community membership, and counts
    cypher_q = f"""
        MATCH (viewer:User {{id: {viewer_id}}})-[:FOLLOWS]->(author:User)-[:WROTE]->(p:Post)
        // Ensure post is in the target community using the graph relationship
        MATCH (c:Community {{id: {community_id}}})-[:HAS_POST]->(p)

        // Use OPTIONAL MATCH for counts to include posts with 0 counts
        OPTIONAL MATCH (p)<-[:REPLIED_TO]-(rep:Reply)
        OPTIONAL MATCH (upvoter:User)-[:VOTED {{vote_type: true}}]->(p)
        OPTIONAL MATCH (downvoter:User)-[:VOTED {{vote_type: false}}]->(p)
        OPTIONAL MATCH (favUser:User)-[:FAVORITED]->(p)

        // Aggregation using WITH clause
        WITH p, author, c, // Pass through nodes
             count(DISTINCT rep) as reply_count,
             count(DISTINCT upvoter) as upvotes,
             count(DISTINCT downvoter) as downvotes,
             count(DISTINCT favUser) as favorite_count

        // Return data needed for PostType and potentially nested Author/Community types
        RETURN p.id as id, p.title as title, p.created_at as created_at, p.image_path as image_path,
               author.id as user_id, author.username as author_name, author.image_path as author_avatar,
               c.id as community_id, c.name as community_name, // Include community info
               reply_count, upvotes, downvotes, favorite_count

        ORDER BY p.created_at DESC
        SKIP {offset}
        LIMIT {limit}
    """
    try:
        print(f"CRUD: Fetching followed posts in comm {community_id} for viewer {viewer_id}")
        results_agtype = execute_cypher(cursor, cypher_q, fetch_all=True)
        # Results are list of maps with all returned fields
        return results_agtype if isinstance(results_agtype, list) else []
    except Exception as e:
        print(f"CRUD Error getting followed posts graph for V:{viewer_id}, C:{community_id}: {e}")
        raise # Re-raise for transaction handling
# --- END NEW FUNCTION ---
# Note: Functions for voting on posts or favoriting posts will be in _vote.py and _favorite.py (or combined).
# Note: Functions for adding/removing post from community are in _community.py
