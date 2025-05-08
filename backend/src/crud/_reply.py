# backend/src/crud/_reply.py
import traceback

import psycopg2
import psycopg2.extras
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone

# Import graph helpers and utils
from ._graph import execute_cypher, build_cypher_set_clauses
from .. import utils
from ._user import (get_user_by_id)
# =========================================
# Reply CRUD (Relational + Graph + Media Link)
# =========================================

def create_reply_db(
        cursor: psycopg2.extensions.cursor, post_id: int, user_id: int, content: str,
        parent_reply_id: Optional[int]
        # Media linking handled separately by router
) -> Optional[int]:
    """
    Creates reply in public.replies, :Reply vertex, :WROTE edge, :REPLIED_TO edge.
    Requires CALLING function to handle transaction commit/rollback.
    """
    reply_id = None
    # No outer try/except, let caller handle transaction
    # 1. Insert into public.replies
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

    # 2. Create :Reply vertex (Wrap in try/except)
    try:
        reply_props = {'id': reply_id, 'created_at': created_at}
        set_clauses_str = build_cypher_set_clauses('r', reply_props)
        cypher_q_vertex = f"CREATE (r:Reply {{id: {reply_id}}})"
        if set_clauses_str: cypher_q_vertex += f" SET {set_clauses_str}"
        print(f"CRUD: Creating AGE vertex for reply {reply_id}...")
        execute_cypher(cursor, cypher_q_vertex)
        print(f"CRUD: AGE vertex created for reply {reply_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed create AGE vertex reply {reply_id}: {age_err}")
        raise age_err # Fail the whole create if graph fails here

    # 3. Create :WROTE edge (User -> Reply) (Wrap in try/except)
    try:
        created_at_quoted = utils.quote_cypher_string(created_at)
        cypher_q_wrote = f"""
            MATCH (u:User {{id: {user_id}}}) MATCH (rep:Reply {{id: {reply_id}}})
            MERGE (u)-[r:WROTE]->(rep) SET r.created_at = {created_at_quoted} """
        execute_cypher(cursor, cypher_q_wrote)
        print(f"CRUD: :WROTE edge created for reply {reply_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed create :WROTE edge reply {reply_id}: {age_err}")
        raise age_err

    # 4. Create :REPLIED_TO edge (Reply -> Post or Reply -> Reply) (Wrap in try/except)
    try:
        target_id = parent_reply_id if parent_reply_id is not None else post_id
        target_label = "Reply" if parent_reply_id is not None else "Post"
        cypher_q_replied = f"""
            MATCH (child:Reply {{id: {reply_id}}}) MATCH (parent:{target_label} {{id: {target_id}}})
            MERGE (child)-[r:REPLIED_TO]->(parent) SET r.created_at = {created_at_quoted} """
        execute_cypher(cursor, cypher_q_replied)
        print(f"CRUD: :REPLIED_TO edge created reply {reply_id} -> {target_label} {target_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed create :REPLIED_TO edge reply {reply_id}: {age_err}")
        raise age_err

    return reply_id # Return ID

def get_reply_by_id(cursor: psycopg2.extensions.cursor, reply_id: int) -> Optional[Dict[str, Any]]:
    """Fetches reply details from relational table ONLY."""
    cursor.execute(
        "SELECT id, user_id, post_id, content, parent_reply_id, created_at FROM public.replies WHERE id = %s",
        (reply_id,)
    )
    return cursor.fetchone()

# --- Fetch reply counts from graph (Python counting) ---
def get_reply_counts(cursor: psycopg2.extensions.cursor, reply_id: int) -> Dict[str, int]:
    # --- Add this debug query ---
    debug_vote_edges_q = f"MATCH ()-[r:VOTED]->(rep:Reply {{id: {reply_id}}}) RETURN r as edge_props"
    debug_expected_edges = [('edge_props', 'agtype')]
    try:
        all_vote_edges = execute_cypher(cursor, debug_vote_edges_q, fetch_all=True, expected_columns=debug_expected_edges)
        #print(f"DEBUG get_reply_counts R:{reply_id} - All VOTED edges found: {all_vote_edges}")
        if all_vote_edges:
            for edge_data_item in all_vote_edges:
                parsed_edge_dict = edge_data_item.get('edge_props')
                if isinstance(parsed_edge_dict, dict) and 'properties' in parsed_edge_dict:
                    print(f"  Edge properties for Reply {reply_id}: {parsed_edge_dict.get('properties')}")
                else:
                    print(f"  Edge data for Reply {reply_id} (not expected dict or no props): {parsed_edge_dict}")
    except Exception as debug_e:
        print(f"DEBUG get_reply_counts R:{reply_id} - Error fetching raw edges: {debug_e}")
    # --- End debug query ---

    cypher_q = f"""
        MATCH (rep:Reply {{id: {reply_id}}})
        OPTIONAL MATCH (upvoter:User)-[v_up:VOTED]->(rep) WHERE v_up.vote_type = true
        OPTIONAL MATCH (downvoter:User)-[v_down:VOTED]->(rep) WHERE v_down.vote_type = false
        OPTIONAL MATCH (fv:User)-[:FAVORITED]->(rep)
        RETURN count(DISTINCT upvoter) as upvotes,
               count(DISTINCT downvoter) as downvotes,
               count(DISTINCT fv) as favorite_count
    """
    expected_counts = [('upvotes', 'agtype'), ('downvotes', 'agtype'), ('favorite_count', 'agtype')]
    try:
        result_map = execute_cypher(cursor, cypher_q, fetch_one=True, expected_columns=expected_counts)
        #print(f"DEBUG get_reply_counts for R:{reply_id} - Raw result_map from graph count query: {result_map}")
        if isinstance(result_map, dict):
            return {
                "upvotes": int(result_map.get('upvotes', 0) or 0),
                "downvotes": int(result_map.get('downvotes', 0) or 0),
                "favorite_count": int(result_map.get('favorite_count', 0) or 0)
            }
        else: return {"upvotes": 0, "downvotes": 0, "favorite_count": 0}
    except Exception as e:
        print(f"Warning: Failed getting graph counts for reply {reply_id}: {e}")
        traceback.print_exc()
        return {"upvotes": 0, "downvotes": 0, "favorite_count": 0}

# --- Fetch list of replies for a post (Combines relational + graph counts) ---
def get_replies_for_post_db(cursor: psycopg2.extensions.cursor, post_id: int) -> List[Dict[str, Any]]:
    """ Fetches replies from relational table, adds graph counts and author info."""
    # Fetch relational reply data including author info
    sql = """
        SELECT
            r.id, r.post_id, r.user_id, r.content, r.parent_reply_id, r.created_at,
            u.username AS author_name,
            -- Fetch author's user ID to get avatar path separately if needed
            u.id AS author_id
        FROM public.replies r
        JOIN public.users u ON r.user_id = u.id
        WHERE r.post_id = %s
        ORDER BY r.created_at ASC;
    """
    cursor.execute(sql, (post_id,))
    replies_relational = cursor.fetchall()

    augmented_replies = []
    # Fetch author avatars in a batch for efficiency (Optional Optimization)
    # author_ids = {r['author_id'] for r in replies_relational if r.get('author_id')}
    # avatars = get_user_avatars(cursor, list(author_ids)) # Need a new batch fetch function

    for reply_rel in replies_relational:
        reply_data = dict(reply_rel)
        reply_id = reply_data['id']
        author_id = reply_data.get('author_id')

        # Fetch counts for this reply
        counts = {"upvotes": 0, "downvotes": 0, "favorite_count": 0}
        try:
            counts = get_reply_counts(cursor, reply_id)
        except Exception as e:
            print(f"CRUD Warning: Failed get counts for reply {reply_id}: {e}")
        reply_data.update(counts)

        # Fetch author avatar path (if not batch fetched)
        # Need to fetch user details to get image_path if not included above
        if author_id:
            author_details = get_user_by_id(cursor, author_id) # This is N+1 !
            reply_data['author_avatar'] = author_details.get('image_path') if author_details else None
        else:
            reply_data['author_avatar'] = None

        augmented_replies.append(reply_data)

    return augmented_replies

# --- delete_reply_db ---
def delete_reply_db(cursor: psycopg2.extensions.cursor, reply_id: int) -> bool:
    """
    Deletes reply from public.replies AND AGE graph.
    Requires CALLING function to handle media item deletion.
    """
    # 1. Delete from AGE graph
    cypher_q = f"MATCH (r:Reply {{id: {reply_id}}}) DETACH DELETE r"
    print(f"CRUD: Deleting AGE vertex/edges for reply {reply_id}...")
    try:
        execute_cypher(cursor, cypher_q)
        print(f"CRUD: AGE vertex/edges deleted for reply {reply_id}.")
    except Exception as age_err:
        print(f"CRUD WARNING: Failed delete AGE vertex for reply {reply_id}: {age_err}")
        raise age_err

    # 2. Delete from relational table
    cursor.execute("DELETE FROM public.replies WHERE id = %s;", (reply_id,))
    rows_deleted = cursor.rowcount
    print(f"CRUD: Deleted reply {reply_id} from public.replies (Rows: {rows_deleted}).")

    return rows_deleted > 0