# backend/src/gql_resolvers.py
import strawberry
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone

# Use the central crud import
from . import crud, utils, schemas
from .database import get_db_connection
# Import graph helpers if needed directly (usually called by crud)
from .crud._graph import execute_cypher
# Import GQL Types
from .gql_types import UserType, CommunityType, PostType, ReplyType, EventType, LocationType, MediaItemDisplay

# ===========================================
# === Mapping Helper Functions FIRST ===
# ===========================================

def map_db_user_to_gql_user(db_user: Optional[Dict[str, Any]], counts: Optional[Dict[str, int]] = None) -> Optional[UserType]:
    # ... (implementation as provided before) ...
    if not db_user: return None
    user_data = dict(db_user); user_data.update(counts or {})
    location_obj = None; location_point_str = user_data.get('current_location')
    if location_point_str: location_dict = utils.parse_point_string(str(location_point_str)); location_obj = LocationType(**location_dict) if location_dict else None
    interests_db = user_data.get('interest'); interests_list = interests_db.split(',') if interests_db and interests_db.strip() else []
    return UserType(
        id=strawberry.ID(str(user_data.get('id'))), name=user_data.get('name', ''), username=user_data.get('username', ''),
        email=user_data.get('email'), gender=user_data.get('gender', ''), college=user_data.get('college'),
        interest=interests_db, interests_list=interests_list, image_url=utils.get_minio_url(user_data.get('image_path')),
        current_location=location_obj, current_location_address=user_data.get('current_location_address'),
        created_at=user_data.get('created_at', datetime.now(timezone.utc)), last_seen=user_data.get('last_seen'),
        followers_count=int(user_data.get('followers_count', 0)), following_count=int(user_data.get('following_count', 0)),
        is_followed_by_viewer=None
    )

def map_db_community_to_gql_community(db_community: Optional[Dict[str, Any]]) -> Optional[CommunityType]:
    # ... (implementation as provided before) ...
    if not db_community: return None
    comm_data = dict(db_community)
    location_obj = None; location_point_str = comm_data.get('primary_location')
    if location_point_str: location_dict = utils.parse_point_string(str(location_point_str)); location_obj = LocationType(**location_dict) if location_dict else None
    return CommunityType(
        id=strawberry.ID(str(comm_data.get('id'))), name=comm_data.get('name', ''), description=comm_data.get('description'),
        created_by_id=int(comm_data.get('created_by', 0)), created_at=comm_data.get('created_at', datetime.now(timezone.utc)),
        primary_location=location_obj, interest=comm_data.get('interest'), logo_url=utils.get_minio_url(comm_data.get('logo_path')),
        member_count=int(comm_data.get('member_count', 0)), online_count=int(comm_data.get('online_count', 0)),
        is_member_by_viewer=None
    )

def map_db_post_to_gql_post(db_post: Optional[Dict[str, Any]], viewer_id: Optional[int] = None) -> Optional[PostType]:
    # ... (implementation as provided before) ...
    if not db_post: return None
    post_data = dict(db_post)
    # Ensure necessary counts are present from db_post (fetched by get_posts_db)
    return PostType(
        id=strawberry.ID(str(post_data.get('id'))), title=post_data.get('title', ''), content=post_data.get('content', ''),
        created_at=post_data.get('created_at', datetime.now(timezone.utc)), image_url=utils.get_minio_url(post_data.get('image_path')),
        reply_count=int(post_data.get('reply_count', 0)), upvotes=int(post_data.get('upvotes', 0)),
        downvotes=int(post_data.get('downvotes', 0)), favorite_count=int(post_data.get('favorite_count', 0)),
        author=None, community=None, viewer_vote_type=None, viewer_has_favorited=None
    )

def map_db_reply_to_gql_reply(db_reply: Optional[Dict[str, Any]], viewer_id: Optional[int] = None) -> Optional[ReplyType]:
    # ... (implementation as provided before) ...
    if not db_reply: return None
    reply_data = dict(db_reply)
    # Ensure counts are present from db_reply (fetched by get_replies_for_post_db)
    return ReplyType(
        id=strawberry.ID(str(reply_data.get('id'))), content=reply_data.get('content', ''),
        created_at=reply_data.get('created_at', datetime.now(timezone.utc)), post_id=int(reply_data.get('post_id', 0)),
        parent_reply_id=reply_data.get('parent_reply_id'), upvotes=int(reply_data.get('upvotes', 0)),
        downvotes=int(reply_data.get('downvotes', 0)), favorite_count=int(reply_data.get('favorite_count', 0)),
        author=None, viewer_vote_type=None, viewer_has_favorited=None
    )

def map_db_event_to_gql_event(db_event: Optional[Dict[str, Any]], viewer_id: Optional[int] = None) -> Optional[EventType]:
    # ... (implementation as provided before) ...
    if not db_event: return None
    event_data = dict(db_event)
    # Ensure participant_count is present (fetched by get_event_details_db)
    return EventType(
        id=strawberry.ID(str(event_data.get('id'))), title=event_data.get('title', ''), description=event_data.get('description'),
        location=event_data.get('location', ''), event_timestamp=event_data.get('event_timestamp', datetime.now(timezone.utc)),
        max_participants=int(event_data.get('max_participants', 0)), image_url=event_data.get('image_url'),
        created_at=event_data.get('created_at', datetime.now(timezone.utc)), creator_id=int(event_data.get('creator_id', 0)),
        community_id=int(event_data.get('community_id', 0)), participant_count=int(event_data.get('participant_count', 0)),
        is_participating_by_viewer=None
    )

def get_viewer_status_for_item(cursor, viewer_id: int, item_id: int, item_label: str) -> Dict[str, Any]:
    """Fetches viewer's vote and favorite status for a Post or Reply."""
    status = {'vote_type': None, 'is_favorited': False}
    if not viewer_id: return status

    # Determine post_id and reply_id based on item_label
    post_id_arg = item_id if item_label == 'Post' else None
    reply_id_arg = item_id if item_label == 'Reply' else None

    try: # Wrap DB calls
        # Use the correct arguments for the CRUD function
        vote_status = crud.get_viewer_vote_status(cursor, viewer_id, post_id=post_id_arg, reply_id=reply_id_arg)
        status['vote_type'] = 'UP' if vote_status is True else ('DOWN' if vote_status is False else None)
    except Exception as e: print(f"Warning: Failed getting viewer vote status for {item_label} {item_id}: {e}")
    try:
        # Use the correct arguments for the CRUD function
        status['is_favorited'] = crud.get_viewer_favorite_status(cursor, viewer_id, post_id=post_id_arg, reply_id=reply_id_arg)
    except Exception as e: print(f"Warning: Failed getting viewer favorite status for {item_label} {item_id}: {e}")
    return status


# ===========================================
# === Resolver Functions AFTER Mappers ===
# ===========================================

# --- User Resolvers ---
async def get_user_resolver(info: strawberry.Info, id: strawberry.ID, viewer_id_if_different: Optional[int] = None) -> Optional[UserType]:
    # ... (implementation uses map_db_user_to_gql_user) ...
    # No changes needed here if mapper is defined above
    print(f"GraphQL Resolver: get_user(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id") if viewer_id_if_different is None else viewer_id_if_different
    try:
        user_id_int = int(id); conn = get_db_connection(); cursor = conn.cursor()
        db_user = crud.get_user_by_id(cursor, user_id_int)
        if not db_user: return None
        counts = crud.get_user_graph_counts(cursor, user_id_int)
        gql_user = map_db_user_to_gql_user(db_user, counts) # CALL MAPPER
        if not gql_user: return None
        if viewer_id is not None and viewer_id != user_id_int:
            try: gql_user.is_followed_by_viewer = crud.check_is_following(cursor, viewer_id, user_id_int)
            except Exception as e: print(f"Warn: check follow failed: {e}"); gql_user.is_followed_by_viewer = False
        else: gql_user.is_followed_by_viewer = False
        return gql_user
    except ValueError: return None
    except Exception as e: print(f"Error in get_user resolver: {e}"); import traceback; traceback.print_exc(); return None
    finally:
        if conn: conn.close()


async def get_viewer(info: strawberry.Info) -> Optional[UserType]:
    # ... (implementation uses get_user_resolver) ...
    # No changes needed here
    print(f"GraphQL Resolver: get_viewer")
    viewer_id: Optional[int] = info.context.get("user_id")
    if viewer_id is None: return None
    return await get_user_resolver(info, strawberry.ID(str(viewer_id)))

# --- Post Resolvers ---
async def get_post_resolver(info: strawberry.Info, id: strawberry.ID) -> Optional[PostType]:
    """ Resolver to fetch a single post by ID. """
    print(f"GraphQL Resolver: get_post(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        post_id_int = int(id)
        conn = get_db_connection(); cursor = conn.cursor()

        # Fetch relational post data
        db_post = crud.get_post_by_id(cursor, post_id_int)
        if not db_post: return None

        gql_post = map_db_post_to_gql_post(db_post, viewer_id) # Use existing mapper
        if not gql_post: return None # Mapper should handle basic mapping

        # Augment with Author, Community, Media, Counts, Viewer Status
        # (Similar logic as in GET /posts/{post_id} REST endpoint)

        # Author
        db_author = crud.get_user_by_id(cursor, db_post['user_id'])
        gql_post.author = map_db_user_to_gql_user(db_author)

        # Community
        # Community
        comm_id = None; comm_name = None # Placeholder
        try: # Check graph edge for community link
            cypher_q_comm = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {post_id_int}}}) RETURN c.id as id LIMIT 1"
            # --- FIX: Add expected_columns ---
            expected_comm_link = [('id', 'agtype')]
            comm_res = execute_cypher(cursor, cypher_q_comm, fetch_one=True, expected_columns=expected_comm_link)
            # --- End Fix ---
            if comm_res and isinstance(comm_res, dict): comm_id = comm_res.get('id')
        except Exception as e: print(f"WARN GQL: Failed fetching comm link P:{post_id_int}: {e}")
        if comm_id:
            db_community = crud.get_community_by_id(cursor, comm_id)
            gql_post.community = map_db_community_to_gql_community(db_community)

        # Media
        try:
            db_media = crud.get_media_items_for_post(cursor, post_id_int)
            # Map DB media to GQL MediaItemDisplay (needs mapper or inline logic)
            gql_post.media = [
                MediaItemDisplay(id=str(m['id']), url=m.get('url'), mime_type=m['mime_type'])
                for m in db_media
            ]
        except Exception as e: print(f"WARN GQL: Failed getting media P:{post_id_int}: {e}"); gql_post.media = []


        # Viewer Status (Vote/Favorite) - Re-fetch counts too
        try: counts = crud.get_post_counts(cursor, post_id_int); gql_post.reply_count=counts.get('reply_count',0); gql_post.upvotes=counts.get('upvotes',0); gql_post.downvotes=counts.get('downvotes',0); gql_post.favorite_count=counts.get('favorite_count',0)
        except Exception as e: print(f"WARN GQL: Failed counts P:{post_id_int}: {e}")

        if viewer_id:
            status = get_viewer_status_for_item(cursor, viewer_id, post_id_int, 'Post') # Use helper
            gql_post.viewer_vote_type = status['vote_type']
            gql_post.viewer_has_favorited = status['is_favorited']

        return gql_post

    except ValueError: return None # Invalid ID format
    except Exception as e: print(f"Error in get_post resolver: {e}"); traceback.print_exc(); return None
    finally:
        if conn: conn.close()

# --- Community Resolvers ---
async def get_community_resolver(info: strawberry.Info, id: strawberry.ID, requesting_viewer_id: Optional[int] = None) -> Optional[CommunityType]:
    # ... (implementation uses map_db_community_to_gql_community, check_is_member) ...
    # Ensure mapper is defined above
    print(f"GraphQL Resolver: get_community(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id") if requesting_viewer_id is None else requesting_viewer_id
    try:
        comm_id_int = int(id); conn = get_db_connection(); cursor = conn.cursor()
        db_community = crud.get_community_details_db(cursor, comm_id_int)
        gql_community = map_db_community_to_gql_community(db_community) # CALL MAPPER
        if not gql_community: return None
        if viewer_id:
            try: gql_community.is_member_by_viewer = crud.check_is_member(cursor, viewer_id, comm_id_int) # Use specific check
            except Exception as e: print(f"Warn: check member failed: {e}"); gql_community.is_member_by_viewer = False
        else: gql_community.is_member_by_viewer = False
        return gql_community
    except ValueError: return None
    except Exception as e: print(f"Error in get_community resolver: {e}"); import traceback; traceback.print_exc(); return None
    finally:
        if conn: conn.close()

async def get_communities(info: strawberry.Info) -> List[CommunityType]:
    # ... (implementation uses map_db_community_to_gql_community, check_is_member) ...
    # Ensure mapper is defined above
    print("GraphQL Resolver: get_communities")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        db_communities = crud.get_communities_db(cursor) # Gets relational list
        gql_communities: List[CommunityType] = []
        for db_comm in db_communities:
            comm_id_int = db_comm['id']
            counts = crud.get_community_counts(cursor, comm_id_int)
            db_comm_with_counts = dict(db_comm); db_comm_with_counts.update(counts)
            gql_comm = map_db_community_to_gql_community(db_comm_with_counts) # CALL MAPPER
            if gql_comm:
                if viewer_id:
                    try: gql_comm.is_member_by_viewer = crud.check_is_member(cursor, viewer_id, comm_id_int) # Use specific check
                    except Exception as e: print(f"Warn: check member failed for comm {comm_id_int}: {e}"); gql_comm.is_member_by_viewer = False
                else: gql_comm.is_member_by_viewer = False
                gql_communities.append(gql_comm)
        return gql_communities
    except Exception as e: print(f"Error in get_communities resolver: {e}"); return []
    finally:
        if conn: conn.close()

async def get_trending_communities_resolver(info: strawberry.Info) -> List[CommunityType]:
    # ... (implementation uses map_db_community_to_gql_community, check_is_member) ...
    # Ensure mapper is defined above
    print("GraphQL Resolver: get_trending_communities")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        db_communities = crud.get_trending_communities_db(cursor) # Uses relational counts
        gql_communities: List[CommunityType] = []
        for db_comm in db_communities:
            comm_id_int = db_comm['id']
            # Fetch graph online count to augment SQL results
            graph_counts = crud.get_community_counts(cursor, comm_id_int)
            db_comm_with_counts = dict(db_comm); db_comm_with_counts.update(graph_counts)
            gql_comm = map_db_community_to_gql_community(db_comm_with_counts) # CALL MAPPER
            if gql_comm:
                if viewer_id:
                    try: gql_comm.is_member_by_viewer = crud.check_is_member(cursor, viewer_id, comm_id_int) # Use specific check
                    except Exception as e: print(f"Warn: check member failed for trend comm {comm_id_int}: {e}"); gql_comm.is_member_by_viewer = False
                else: gql_comm.is_member_by_viewer = False
                gql_communities.append(gql_comm)
        return gql_communities
    except Exception as e: print(f"Error in get_trending_communities resolver: {e}"); return []
    finally:
        if conn: conn.close()


# --- Event Resolvers ---
async def get_event_resolver(info: strawberry.Info, id: strawberry.ID, requesting_viewer_id: Optional[int] = None) -> Optional[EventType]:
    # ... (implementation uses map_db_event_to_gql_event, check_is_participating) ...
    # Ensure mapper is defined above
    print(f"GraphQL Resolver: get_event(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id") if requesting_viewer_id is None else requesting_viewer_id
    try:
        event_id_int = int(id); conn = get_db_connection(); cursor = conn.cursor()
        db_event = crud.get_event_details_db(cursor, event_id_int)
        gql_event = map_db_event_to_gql_event(db_event, viewer_id) # CALL MAPPER
        if not gql_event: return None
        if viewer_id:
            try: gql_event.is_participating_by_viewer = crud.check_is_participating(cursor, viewer_id, event_id_int) # Use specific check
            except Exception as e: print(f"Warn: check participation failed: {e}"); gql_event.is_participating_by_viewer = False
        else: gql_event.is_participating_by_viewer = False
        return gql_event
    except ValueError: return None
    except Exception as e: print(f"Error in get_event resolver: {e}"); return None
    finally:
        if conn: conn.close()

# --- Reply Resolvers ---
async def get_reply_resolver(info: strawberry.Info, id: strawberry.ID, viewer_id_if_different: Optional[int] = None) -> Optional[ReplyType]:
    # ... (implementation uses map_db_reply_to_gql_reply, get_viewer_status_for_item) ...
    # Ensure mapper is defined above
    print(f"GraphQL Resolver: get_reply(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id") if viewer_id_if_different is None else viewer_id_if_different
    try:
        reply_id_int = int(id); conn = get_db_connection(); cursor = conn.cursor()
        db_reply = crud.get_reply_by_id(cursor, reply_id_int)
        if not db_reply: return None
        counts = crud.get_reply_counts(cursor, reply_id_int)
        db_reply_with_counts = dict(db_reply); db_reply_with_counts.update(counts)
        gql_reply = map_db_reply_to_gql_reply(db_reply_with_counts, viewer_id) # CALL MAPPER
        if not gql_reply: return None

        # Fetch Author
        db_author = crud.get_user_by_id(cursor, db_reply['user_id'])
        gql_reply.author = map_db_user_to_gql_user(db_author) # CALL MAPPER

        # Fetch Viewer Status
        if viewer_id:
            status = get_viewer_status_for_item(cursor, viewer_id, reply_id_int, 'Reply')
            gql_reply.viewer_vote_type = status['vote_type']
            gql_reply.viewer_has_favorited = status['is_favorited']
        return gql_reply
    except ValueError: return None
    except Exception as e: print(f"Error in get_reply resolver: {e}"); return None
    finally:
        if conn: conn.close()

# --- Field Resolvers (for nested data) ---

async def get_community_members_resolver(info: strawberry.Info, community_id_int: int, limit: int, offset: int, requesting_viewer_id: Optional[int]) -> List[UserType]:
    # ... (implementation uses map_db_user_to_gql_user, check_is_following) ...
    # Ensure mapper defined above
    print(f"Resolver: get_community_members(comm_id={community_id_int}, limit={limit}, offset={offset})")
    conn = None
    viewer_id: Optional[int] = requesting_viewer_id # Use passed viewer ID
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        db_members = crud.get_community_members_graph(cursor, community_id_int, limit, offset)
        gql_members: List[UserType] = []
        for db_member in db_members:
            gql_user = map_db_user_to_gql_user(db_member) # CALL MAPPER
            if gql_user:
                if viewer_id is not None and viewer_id != db_member['id']:
                    try: gql_user.is_followed_by_viewer = crud.check_is_following(cursor, viewer_id, db_member['id']) # Use specific check
                    except Exception as e: print(f"Warn: check follow failed in members: {e}"); gql_user.is_followed_by_viewer = False
                else: gql_user.is_followed_by_viewer = False
                gql_members.append(gql_user)
        return gql_members
    except Exception as e: print(f"Error get_community_members_resolver: {e}"); return []
    finally:
        if conn: conn.close()

async def get_community_events_resolver(info: strawberry.Info, community_id_int: int, limit: int, offset: int, requesting_viewer_id: Optional[int]) -> List[EventType]:
    # ... (implementation uses map_db_event_to_gql_event, check_is_participating) ...
    # Ensure mapper defined above
    print(f"Resolver: get_community_events(comm_id={community_id_int}, limit={limit}, offset={offset})")
    conn = None
    viewer_id: Optional[int] = requesting_viewer_id
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        db_events = crud.get_events_for_community_db(cursor, community_id_int) # Add limit/offset here if possible
        db_events_paginated = db_events[offset : offset + limit] # Slice if not done in CRUD

        gql_events: List[EventType] = []
        for db_event in db_events_paginated:
            gql_event = map_db_event_to_gql_event(db_event, viewer_id) # CALL MAPPER
            if gql_event:
                if viewer_id:
                    event_id_int = int(gql_event.id)
                    try: gql_event.is_participating_by_viewer = crud.check_is_participating(cursor, viewer_id, event_id_int) # Use specific check
                    except Exception as e: print(f"Warn: check participation failed in events: {e}"); gql_event.is_participating_by_viewer = False
                else: gql_event.is_participating_by_viewer = False
                gql_events.append(gql_event)
        return gql_events
    except Exception as e: print(f"Error get_community_events_resolver: {e}"); return []
    finally:
        if conn: conn.close()

async def get_event_participants_resolver(info: strawberry.Info, event_id_int: int, limit: int, offset: int, requesting_viewer_id: Optional[int]) -> List[UserType]:
    # ... (implementation uses map_db_user_to_gql_user, check_is_following) ...
    # Ensure mapper defined above
    print(f"Resolver: get_event_participants(event_id={event_id_int}, limit={limit}, offset={offset})")
    conn = None
    viewer_id: Optional[int] = requesting_viewer_id
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        db_participants = crud.get_event_participants_graph(cursor, event_id_int, limit, offset)
        gql_participants: List[UserType] = []
        for db_participant in db_participants:
            gql_user = map_db_user_to_gql_user(db_participant) # CALL MAPPER
            if gql_user:
                if viewer_id is not None and viewer_id != db_participant['id']:
                    try: gql_user.is_followed_by_viewer = crud.check_is_following(cursor, viewer_id, db_participant['id']) # Use specific check
                    except Exception as e: print(f"Warn: check follow failed in participants: {e}"); gql_user.is_followed_by_viewer = False
                else: gql_user.is_followed_by_viewer = False
                gql_participants.append(gql_user)
        return gql_participants
    except Exception as e: print(f"Error get_event_participants_resolver: {e}"); return []
    finally:
        if conn: conn.close()

async def get_replies_resolver(info: strawberry.Info, post_id_int: int, limit: int, offset: int, viewer_id_if_different: Optional[int]) -> List[ReplyType]:
    # ... (implementation uses map_db_reply_to_gql_reply, get_viewer_status_for_item) ...
    # Ensure mapper defined above
    print(f"Resolver: get_replies(post_id={post_id_int}, limit={limit}, offset={offset})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id") if viewer_id_if_different is None else viewer_id_if_different
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Assumes get_replies_for_post_db returns combined data
        db_replies = crud.get_replies_for_post_db(cursor, post_id_int) # Add limit/offset here?
        db_replies_paginated = db_replies[offset : offset + limit] # Slice for now

        gql_replies: List[ReplyType] = []
        for db_reply in db_replies_paginated:
            gql_reply = map_db_reply_to_gql_reply(db_reply, viewer_id) # CALL MAPPER
            if gql_reply:
                reply_id_int = int(gql_reply.id)
                # Fetch Author
                db_author = crud.get_user_by_id(cursor, db_reply['user_id'])
                gql_reply.author = map_db_user_to_gql_user(db_author) # CALL MAPPER

                # Fetch Viewer Status
                if viewer_id:
                    status = get_viewer_status_for_item(cursor, viewer_id, reply_id_int, 'Reply')
                    gql_reply.viewer_vote_type = status['vote_type']
                    gql_reply.viewer_has_favorited = status['is_favorited']

                gql_replies.append(gql_reply)
        return gql_replies
    except Exception as e: print(f"Error in get_replies_resolver: {e}"); return []
    finally:
        if conn: conn.close()

# --- Add other field resolvers: community.creator, event.creator, event.community, reply.parent_reply ---