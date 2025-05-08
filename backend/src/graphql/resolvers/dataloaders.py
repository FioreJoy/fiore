# src/graphql/resolvers/dataloaders.py

from typing import List, Optional, Dict, Any
import psycopg2
import traceback
from collections import defaultdict
from strawberry.types import Info # Import Info
from aiodataloader import DataLoader # For type hinting if needed

# --- Local Imports ---
# Need access to CRUD functions and DB connection
from ... import crud
from ...database import get_db_connection
# Need access to GQL Types for return type hinting and mapping functions
# Import types directly from the consolidated types file
from ..types import UserType, CommunityType, PostType, ReplyType, EventType, MediaItemDisplay
from ..mappings import ( # Import mappings
    map_db_user_to_gql_user, map_db_community_to_gql_community,
    map_db_post_to_gql_post, map_db_reply_to_gql_reply,
    map_db_event_to_gql_event, map_db_media_to_gql_media
)
from ... import utils # For get_minio_url if needed directly

# --- Helper for Ordering Results ---
def _map_results_to_keys(keys: List[Any], results_map: Dict[Any, Any]) -> List[Any]:
    """Orders results based on the original keys list."""
    return [results_map.get(key) for key in keys]

# --- Batch Loading Functions ---

async def batch_load_users_fn(user_ids: List[int]) -> List[Optional[UserType]]:
    """Batch loads User objects by their IDs."""
    print(f"DataLoader: Batch loading users for IDs: {user_ids}")
    if not user_ids: return []
    conn = None
    results_map: Dict[int, Optional[UserType]] = {key: None for key in user_ids}
    unique_ids = list(set(user_ids))
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Fetch base user data
        sql_users = "SELECT * FROM public.users WHERE id = ANY(%s)"
        cursor.execute(sql_users, (unique_ids,))
        users_by_id = {user['id']: user for user in cursor.fetchall()}
        # Fetch profile pics
        sql_pics = """
            SELECT upp.user_id, mi.* FROM public.user_profile_picture upp
            JOIN public.media_items mi ON upp.media_id = mi.id
            WHERE upp.user_id = ANY(%s)"""
        cursor.execute(sql_pics, (unique_ids,))
        pics_by_user_id = {pic['user_id']: pic for pic in cursor.fetchall()}
        # Fetch counts (N+1 per user - requires optimization later)
        counts_by_user_id = {}
        for user_id in unique_ids:
            try: counts_by_user_id[user_id] = crud.get_user_graph_counts(cursor, user_id)
            except Exception: counts_by_user_id[user_id] = {}

        # Map results
        for user_id in unique_ids:
            db_user = users_by_id.get(user_id)
            if db_user:
                pic_media_db = pics_by_user_id.get(user_id)
                counts = counts_by_user_id.get(user_id, {})
                results_map[user_id] = map_db_user_to_gql_user(
                    db_user,
                    counts=counts,
                    profile_pic_media=pic_media_db
                    # viewer status (is_followed) handled by resolver needing viewer context
                )
        return _map_results_to_keys(user_ids, results_map)
    except Exception as e:
        print(f"DataLoader ERROR users: {e}"); traceback.print_exc(); return [None] * len(user_ids)
    finally:
        if conn: conn.close()


async def batch_load_communities_fn(community_ids: List[int]) -> List[Optional[CommunityType]]:
    """Batch loads Community objects by their IDs."""
    print(f"DataLoader: Batch loading communities for IDs: {community_ids}")
    if not community_ids: return []
    conn = None
    results_map: Dict[int, Optional[CommunityType]] = {key: None for key in community_ids}
    unique_ids = list(set(community_ids))
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Fetch communities
        sql_comms = "SELECT * FROM public.communities WHERE id = ANY(%s)"
        cursor.execute(sql_comms, (unique_ids,))
        db_comms = {c['id']: c for c in cursor.fetchall()}
        # Fetch logos
        sql_logos = """
            SELECT cl.community_id, mi.* FROM public.community_logo cl
            JOIN public.media_items mi ON cl.media_id = mi.id
            WHERE cl.community_id = ANY(%s)"""
        cursor.execute(sql_logos, (unique_ids,))
        db_logos = {logo['community_id']: logo for logo in cursor.fetchall()}
        # Fetch counts (N+1 per community)
        counts_by_id = {cid: crud.get_community_counts(cursor, cid) for cid in unique_ids}

        for cid in unique_ids:
            db_comm = db_comms.get(cid)
            if db_comm:
                logo_media_db = db_logos.get(cid)
                counts = counts_by_id.get(cid, {})
                # viewer status (is_member) handled by resolver needing viewer context
                results_map[cid] = map_db_community_to_gql_community(
                    db_comm, counts=counts, logo_media=logo_media_db
                )
        return _map_results_to_keys(community_ids, results_map)
    except Exception as e: print(f"DataLoader ERROR communities: {e}"); traceback.print_exc(); return [None] * len(community_ids)
    finally:
        if conn: conn.close()


async def batch_load_media_items_fn(media_ids: List[int]) -> List[Optional[MediaItemDisplay]]:
    """Batch loads MediaItemDisplay objects by their IDs."""
    print(f"DataLoader: Batch loading media items for IDs: {media_ids}")
    if not media_ids: return []
    conn = None
    results_map: Dict[int, Optional[MediaItemDisplay]] = {key: None for key in media_ids}
    unique_ids = list(set(media_ids))
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        sql = "SELECT * FROM public.media_items WHERE id = ANY(%s)"
        cursor.execute(sql, (unique_ids,))
        db_items = {item['id']: item for item in cursor.fetchall()}
        for mid in unique_ids:
            db_item = db_items.get(mid)
            if db_item: results_map[mid] = map_db_media_to_gql_media(db_item)
        return _map_results_to_keys(media_ids, results_map)
    except Exception as e: print(f"DataLoader ERROR media items: {e}"); traceback.print_exc(); return [None] * len(media_ids)
    finally:
        if conn: conn.close()


async def batch_load_post_media_fn(post_ids: List[int]) -> List[List[MediaItemDisplay]]:
    """Batch loads lists of MediaItemDisplay for multiple post IDs."""
    print(f"DataLoader: Batch loading media for Post IDs: {post_ids}")
    if not post_ids: return [[] for _ in post_ids]
    conn = None
    media_by_post_id = defaultdict(list)
    unique_ids = list(set(post_ids))
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        sql = """
            SELECT pm.post_id, mi.*, pm.display_order FROM public.post_media pm
            JOIN public.media_items mi ON pm.media_id = mi.id
            WHERE pm.post_id = ANY(%s) ORDER BY pm.post_id, pm.display_order ASC, mi.created_at ASC;"""
        cursor.execute(sql, (unique_ids,))
        db_media_items = cursor.fetchall()
        for item_db in db_media_items:
            gql_media = map_db_media_to_gql_media(item_db)
            if gql_media: media_by_post_id[item_db['post_id']].append(gql_media)
        return [media_by_post_id.get(pid, []) for pid in post_ids]
    except Exception as e: print(f"DataLoader ERROR post media: {e}"); traceback.print_exc(); return [[] for _ in post_ids]
    finally:
        if conn: conn.close()


async def batch_load_reply_media_fn(reply_ids: List[int]) -> List[List[MediaItemDisplay]]:
    """Batch loads lists of MediaItemDisplay for multiple reply IDs."""
    print(f"DataLoader: Batch loading media for Reply IDs: {reply_ids}")
    if not reply_ids: return [[] for _ in reply_ids]
    conn = None
    media_by_reply_id = defaultdict(list)
    unique_ids = list(set(reply_ids))
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        sql = """
            SELECT rm.reply_id, mi.*, rm.display_order FROM public.reply_media rm
            JOIN public.media_items mi ON rm.media_id = mi.id
            WHERE rm.reply_id = ANY(%s) ORDER BY rm.reply_id, rm.display_order ASC, mi.created_at ASC;"""
        cursor.execute(sql, (unique_ids,))
        db_media_items = cursor.fetchall()
        for item_db in db_media_items:
            gql_media = map_db_media_to_gql_media(item_db)
            if gql_media: media_by_reply_id[item_db['reply_id']].append(gql_media)
        return [media_by_reply_id.get(rid, []) for rid in reply_ids]
    except Exception as e: print(f"DataLoader ERROR reply media: {e}"); traceback.print_exc(); return [[] for _ in reply_ids]
    finally:
        if conn: conn.close()


# --- Updated Batch Loaders for Posts, Replies, Events ---
# These still have N+1 calls for counts/viewer status internally
# Viewer status MUST be handled/added by the calling resolver using info.context

async def batch_load_posts_fn(post_ids: List[int]) -> List[Optional[PostType]]:
    print(f"DataLoader: Batch loading posts for IDs: {post_ids} (N+1 fallback)")
    if not post_ids: return []
    # viewer_id = info.context.get("user_id") # CANNOT get viewer_id here easily
    results = []
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        sql_posts = "SELECT * FROM public.posts WHERE id = ANY(%s)"
        cursor.execute(sql_posts, (list(set(post_ids)),))
        db_posts = {p['id']: p for p in cursor.fetchall()}
        # Batch fetch counts (N+1 per post still)
        counts_by_id = {pid: crud.get_post_counts(cursor, pid) for pid in list(set(post_ids))}

        for post_id in post_ids: # Iterate original list for order
            db_post = db_posts.get(post_id)
            if db_post:
                counts = counts_by_id.get(post_id, {})
                db_post_augmented = {**db_post, **counts}
                # Map without viewer status - resolver will add it
                results_map[post_id] = map_db_post_to_gql_post(db_post_augmented)
            else:
                results_map[post_id] = None

        return _map_results_to_keys(post_ids, results_map) # Return in order

    except Exception as e: print(f"DataLoader ERROR posts fallback: {e}"); return [None] * len(post_ids)
    finally:
        if conn: conn.close()


# Remove 'info: Info' from the function definition
async def batch_load_replies_fn(reply_ids: List[int]) -> List[Optional[ReplyType]]:
    print(f"DataLoader: Batch loading replies for IDs: {reply_ids} (N+1 fallback)")
    if not reply_ids: return []
    results = []
    conn = None
    # viewer_id = info.context.get("user_id") # CANNOT get viewer_id here easily
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        sql_replies = "SELECT * FROM public.replies WHERE id = ANY(%s)"
        cursor.execute(sql_replies, (list(set(reply_ids)),))
        db_replies = {r['id']: r for r in cursor.fetchall()}
        counts_by_id = {rid: crud.get_reply_counts(cursor, rid) for rid in list(set(reply_ids))}

        results_map: Dict[int, Optional[ReplyType]] = {key: None for key in reply_ids}
        for rid in unique_ids:
            db_reply = db_replies.get(rid)
            if db_reply:
                counts = counts_by_id.get(rid, {})
                db_reply_augmented = {**db_reply, **counts}
                results_map[rid] = map_db_reply_to_gql_reply(db_reply_augmented) # No viewer status
        return _map_results_to_keys(reply_ids, results_map)

    except Exception as e: print(f"DataLoader ERROR replies fallback: {e}"); return [None] * len(reply_ids)
    finally:
        if conn: conn.close()


# Remove 'info: Info' from the function definition
async def batch_load_events_fn(event_ids: List[int]) -> List[Optional[EventType]]:
    print(f"DataLoader: Batch loading events for IDs: {event_ids} (N+1 fallback)")
    if not event_ids: return []
    results = []
    conn = None
    # viewer_id = info.context.get("user_id") # CANNOT get viewer_id here
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        sql_events = "SELECT * FROM public.events WHERE id = ANY(%s)"
        cursor.execute(sql_events, (list(set(event_ids)),))
        db_events = {e['id']: e for e in cursor.fetchall()}
        counts_by_id = {eid: {'participant_count': crud.get_event_participant_count(cursor, eid)} for eid in list(set(event_ids))}

        results_map: Dict[int, Optional[EventType]] = {key: None for key in event_ids}
        for eid in unique_ids:
            db_event = db_events.get(eid)
            if db_event:
                counts = counts_by_id.get(eid, {})
                db_event_augmented = {**db_event, **counts}
                results_map[eid] = map_db_event_to_gql_event(db_event_augmented) # No viewer status
        return _map_results_to_keys(event_ids, results_map)

    except Exception as e: print(f"DataLoader ERROR events fallback: {e}"); return [None] * len(event_ids)
    finally:
        if conn: conn.close()