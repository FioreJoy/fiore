# backend/src/crud/_reply.py
import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses, get_graph_counts
from .. import utils # Import root utils for quote_cypher_string

# =========================================
# Reply CRUD (Relational + Graph)
# =========================================

def create_reply_db(
    cursor: psycopg2.extensions.cursor, post_id: int, user_id: int, content: str,
    parent_reply_id: Optional[int]
) -> Optional[int]:
    """
    Creates reply in public.replies, :Reply vertex, :WROTE edge, and :REPLIED_TO edge.
    Requires CALLING function to handle transaction commit/rollback.
    """
    reply_id = None
    # No try/except here, let caller handle transaction
    # 1. Insert into public.replies
    # We still insert parent_reply_id here for potential relational queries or easier data access,
    # even though the graph also stores this relationship.
    cursor.execute(
        """
        INSERT INTO public.replies (post_id, user_id, content, parent_reply_id)
        VALUES (%s, %s, %s, %s) RETURNING id, created_at;
        """,
        (post_id, user_id, content, parent_reply_id)
    )
    result = cursor.fetchone()
    if not result or 'id' not in result: return None
    reply_id = result['id']
    created_at = result['created_at']
    print(f"CRUD: Inserted reply {reply_id} into public.replies.")

    # 2. Create :Reply vertex
    reply_props = {'id': reply_id, 'created_at': created_at} # Store minimal props
    set_clauses_str = build_cypher_set_clauses('r', reply_props)
    cypher_q_vertex = f"CREATE (r:Reply {{id: {reply_id}}})"
    if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
    print(f"CRUD: Creating AGE vertex for reply {reply_id}...")
    execute_cypher(cursor, cypher_q_vertex)
    print(f"CRUD: AGE vertex created for reply {reply_id}.")

    # 3. Create :WROTE edge (User -> Reply)
    created_at_quoted = utils.quote_cypher_string(created_at)
    cypher_q_wrote = f"""
        MATCH (u:User {{id: {user_id}}})
        MATCH (rep:Reply {{id: {reply_id}}})
        MERGE (u)-[r:WROTE]->(rep)
        SET r.created_at = {created_at_quoted}
    """
    execute_cypher(cursor, cypher_q_wrote)
    print(f"CRUD: :WROTE edge created for reply {reply_id}.")

    # 4. Create :REPLIED_TO edge (Reply -> Post or Reply -> Reply)
    target_id = parent_reply_id if parent_reply_id is not None else post_id
    target_label = "Reply" if parent_reply_id is not None else "Post"
    cypher_q_replied = f"""
        MATCH (child:Reply {{id: {reply_id}}})
        MATCH (parent:{target_label} {{id: {target_id}}})
        MERGE (child)-[r:REPLIED_TO]->(parent)
        SET r.created_at = {created_at_quoted}
    """
    execute_cypher(cursor, cypher_q_replied)
    print(f"CRUD: :REPLIED_TO edge created for reply {reply_id} -> {target_label} {target_id}.")

    return reply_id # Return ID on success

def get_reply_by_id(cursor: psycopg2.extensions.cursor, reply_id: int) -> Optional[Dict[str, Any]]:
    """Fetches reply details from relational table ONLY."""
    # Graph counts fetched separately
    cursor.execute(
        "SELECT id, user_id, post_id, content, parent_reply_id, created_at FROM public.replies WHERE id = %s",
        (reply_id,)
    )
    return cursor.fetchone()

# --- Fetch reply counts from graph ---
def get_reply_counts(cursor: psycopg2.extensions.cursor, reply_id: int) -> Dict[str, int]:
    """Fetches vote counts and potentially nested reply counts for a reply from AGE graph."""
    # Add favorite count if needed
    count_specs = [
        {'name': 'upvotes', 'pattern': '(uv:User)-[:VOTED {vote_type: true}]->(n)', 'distinct_var': 'uv'},
        {'name': 'downvotes', 'pattern': '(dv:User)-[:VOTED {vote_type: false}]->(n)', 'distinct_var': 'dv'},
        {'name': 'favorite_count', 'pattern': '(fv:User)-[:FAVORITED]->(n)', 'distinct_var': 'fv'},
        # Add count for direct replies TO this reply if needed for UI
        # {'name': 'nested_reply_count', 'pattern': '(child:Reply)-[:REPLIED_TO]->(n)', 'distinct_var': 'child'},
    ]
    return get_graph_counts(cursor, 'Reply', reply_id, count_specs)

# --- Fetch list of replies for a post (combines relational + graph) ---
def get_replies_for_post_db(cursor: psycopg2.extensions.cursor, post_id: int) -> List[Dict[str, Any]]:
    """ Fetches replies from relational table, adds graph counts and author info."""
    # 1. Fetch relational reply data including author info
    # Order by created_at is important for displaying threads correctly
    sql = """
        SELECT
            r.id, r.post_id, r.user_id, r.content, r.parent_reply_id, r.created_at,
            u.username AS author_name,
            u.image_path AS author_avatar -- Fetch path for URL generation
        FROM public.replies r
        JOIN public.users u ON r.user_id = u.id
        WHERE r.post_id = %s
        ORDER BY r.created_at ASC;
    """
    cursor.execute(sql, (post_id,))
    replies_relational = cursor.fetchall()

    # 2. Augment with graph counts for each reply
    augmented_replies = []
    for reply_rel in replies_relational:
        reply_data = dict(reply_rel)
        reply_id = reply_data['id']
        # Fetch counts for this reply
        try:
            counts = get_reply_counts(cursor, reply_id)
            reply_data.update(counts)
        except Exception as e:
             print(f"CRUD Warning: Failed to get graph counts for reply {reply_id}: {e}")
             # Add default counts if graph query fails
             reply_data.update({"upvotes": 0, "downvotes": 0, "favorite_count": 0}) # Add defaults

        augmented_replies.append(reply_data)

    # 3. Return the augmented list (still ordered by created_at)
    # The frontend will need to reconstruct the thread hierarchy based on parent_reply_id
    return augmented_replies

def delete_reply_db(cursor: psycopg2.extensions.cursor, reply_id: int) -> bool:
    """
    Deletes reply from public.replies AND AGE graph (:Reply vertex and relationships).
    Requires CALLING function to handle transaction commit/rollback.
    """
    # 1. Delete from AGE graph using DETACH DELETE
    # This will remove :WROTE, :VOTED, :FAVORITED, and :REPLIED_TO edges connected to this reply
    cypher_q = f"MATCH (r:Reply {{id: {reply_id}}}) DETACH DELETE r"
    print(f"CRUD: Deleting AGE vertex and edges for reply {reply_id}...")
    execute_cypher(cursor, cypher_q) # Assumes raises on error
    print(f"CRUD: AGE vertex/edges deleted for reply {reply_id}.")

    # 2. Delete from relational table
    # Foreign key constraints from votes/favorites tables were likely dropped,
    # but CASCADE delete from posts/users should still be handled by postgres if set up.
    # We still keep parent_reply_id potentially, so no cascade needed there unless dropped.
    cursor.execute("DELETE FROM public.replies WHERE id = %s;", (reply_id,))
    rows_deleted = cursor.rowcount
    print(f"CRUD: Deleted reply {reply_id} from public.replies (Rows affected: {rows_deleted}).")

    return rows_deleted > 0

# Note: Functions for voting on replies or favoriting replies will be in _vote.py / _favorite.py
