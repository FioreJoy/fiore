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
from .gql_types import UserType, CommunityType, PostType, ReplyType, EventType, LocationType

# === Mapping Helper Functions (Keep as previously defined) ===
# map_db_user_to_gql_user(...)
# map_db_community_to_gql_community(...)
# map_db_post_to_gql_post(...)
# map_db_reply_to_gql_reply(...)
# map_db_event_to_gql_event(...)
# get_viewer_status_for_item(...)

# === Top-Level Query Resolvers ===

async def get_user_resolver(info: strawberry.Info, id: strawberry.ID, viewer_id_if_different: Optional[int] = None) -> Optional[UserType]:
    """Resolver for fetching a single user, handling viewer context."""
    print(f"GraphQL Resolver: get_user(id={id})")
    conn = None
    # Determine the viewer ID: either from context or passed if fetching nested author/creator
    viewer_id: Optional[int] = info.context.get("user_id") if viewer_id_if_different is None else viewer_id_if_different

    try:
        user_id_int = int(id)
        conn = get_db_connection()
        cursor = conn.cursor()

        db_user = crud.get_user_by_id(cursor, user_id_int)
        if not db_user: return None
        counts = crud.get_user_graph_counts(cursor, user_id_int)
        gql_user = map_db_user_to_gql_user(db_user, counts)
        if not gql_user: return None

        if viewer_id is not None and viewer_id != user_id_int:
            cypher_q = f"RETURN EXISTS((:User {{id: {viewer_id}}})-[:FOLLOWS]->(:User {{id: {user_id_int}}})) as following"
            follow_res = execute_cypher(cursor, cypher_q, fetch_one=True)
            follow_map = follow_res if isinstance(follow_res, dict) else {}
            gql_user.is_followed_by_viewer = bool(follow_map.get('following', False))
        else:
            gql_user.is_followed_by_viewer = False
        return gql_user
    except ValueError: return None
    except Exception as e: print(f"Error in get_user resolver: {e}"); import traceback; traceback.print_exc(); return None
    finally:
        if conn: conn.close()

async def get_viewer(info: strawberry.Info) -> Optional[UserType]:
    """Resolver for fetching the currently authenticated user."""
    print(f"GraphQL Resolver: get_viewer")
    viewer_id: Optional[int] = info.context.get("user_id")
    if viewer_id is None: return None
    # Call get_user_resolver with the viewer's own ID, viewer_id_if_different is None by default
    return await get_user_resolver(info, strawberry.ID(str(viewer_id)))

async def get_posts_resolver(
        info: strawberry.Info,
        community_id: Optional[int] = None,
        user_id: Optional[int] = None,
        limit: int = 20,
        offset: int = 0,
        # Added param to distinguish viewer when called nested vs top-level
        viewer_id_if_different: Optional[int] = None
) -> List[PostType]:
    """Resolver for fetching posts (used by top-level query and nested fields)."""
    print(f"GraphQL Resolver: get_posts (Comm: {community_id}, User: {user_id}, Limit: {limit}, Offset: {offset})")
    conn = None
    # Determine the viewer ID (from context if top-level, or passed if nested)
    viewer_id: Optional[int] = info.context.get("user_id") if viewer_id_if_different is None else viewer_id_if_different

    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # This fetches relational data + counts
        db_posts = crud.get_posts_db(
            cursor, community_id=community_id, user_id=user_id, limit=limit, offset=offset
        )

        gql_posts: List[PostType] = []
        # --- N+1 WARNING ZONE ---
        for db_post_dict in db_posts:
            # Map base data + counts
            gql_post = map_db_post_to_gql_post(db_post_dict, viewer_id)
            if gql_post:
                post_id_int = int(gql_post.id)
                # Fetch Author (could be optimized with dataloader)
                db_author = crud.get_user_by_id(cursor, db_post_dict['user_id'])
                gql_post.author = map_db_user_to_gql_user(db_author) # Map author without counts for simplicity

                # Fetch Community (could be optimized with dataloader)
                db_community_id = db_post_dict.get('community_id')
                if db_community_id:
                    db_community = crud.get_community_by_id(cursor, db_community_id) # Fetch basic community info
                    gql_post.community = map_db_community_to_gql_community(db_community) # Map basic info

                # Fetch Viewer Status (could be optimized with dataloader)
                if viewer_id:
                    status = get_viewer_status_for_item(cursor, viewer_id, post_id_int, 'Post')
                    gql_post.viewer_vote_type = status['vote_type']
                    gql_post.viewer_has_favorited = status['is_favorited']

                gql_posts.append(gql_post)
        # --- END N+1 WARNING ZONE ---
        return gql_posts
    except Exception as e:
        print(f"GraphQL Resolver Error fetching posts: {e}")
        import traceback; traceback.print_exc(); return []
    finally:
        if conn: conn.close()


async def get_community_resolver(info: strawberry.Info, id: strawberry.ID, requesting_viewer_id: Optional[int] = None) -> Optional[CommunityType]:
    """Resolver for fetching a single community, handling viewer context."""
    print(f"GraphQL Resolver: get_community(id={id})")
    conn = None
    # Determine viewer ID from context primarily, or passed value if nested
    viewer_id: Optional[int] = info.context.get("user_id") if requesting_viewer_id is None else requesting_viewer_id

    try:
        comm_id_int = int(id)
        conn = get_db_connection()
        cursor = conn.cursor()
        db_community = crud.get_community_details_db(cursor, comm_id_int) # Fetches combined data
        gql_community = map_db_community_to_gql_community(db_community)
        if not gql_community: return None

        if viewer_id:
            cypher_q = f"RETURN EXISTS((:User {{id:{viewer_id}}})-[:MEMBER_OF]->(:Community {{id:{comm_id_int}}})) as member"
            member_res = execute_cypher(cursor, cypher_q, fetch_one=True)
            member_map = member_res if isinstance(member_res, dict) else {}
            gql_community.is_member_by_viewer = bool(member_map.get('member', False))
        else:
            gql_community.is_member_by_viewer = False

        return gql_community
    except ValueError: return None
    except Exception as e: print(f"Error in get_community resolver: {e}"); import traceback; traceback.print_exc(); return None
    finally:
        if conn: conn.close()

async def get_communities(info: strawberry.Info) -> List[CommunityType]:
    """Resolver for fetching list of all communities."""
    print("GraphQL Resolver: get_communities")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        db_communities = crud.get_communities_db(cursor) # Gets relational list
        gql_communities: List[CommunityType] = []
        # N+1 for counts and viewer status - optimize later
        for db_comm in db_communities:
            comm_id_int = db_comm['id']
            counts = crud.get_community_counts(cursor, comm_id_int)
            db_comm_with_counts = dict(db_comm); db_comm_with_counts.update(counts)
            gql_comm = map_db_community_to_gql_community(db_comm_with_counts)
            if gql_comm:
                if viewer_id:
                    cypher_q = f"RETURN EXISTS((:User {{id:{viewer_id}}})-[:MEMBER_OF]->(:Community {{id:{comm_id_int}}})) as member"
                    member_res = execute_cypher(cursor, cypher_q, fetch_one=True)
                    member_map = member_res if isinstance(member_res, dict) else {}
                    gql_comm.is_member_by_viewer = bool(member_map.get('member', False))
                else:
                    gql_comm.is_member_by_viewer = False
                gql_communities.append(gql_comm)
        return gql_communities
    except Exception as e: print(f"Error in get_communities resolver: {e}"); return []
    finally:
        if conn: conn.close()

async def get_trending_communities_resolver(info: strawberry.Info) -> List[CommunityType]:
    """Resolver for fetching trending communities."""
    print("GraphQL Resolver: get_trending_communities")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Uses relational trending logic for now
        db_communities = crud.get_trending_communities_db(cursor)
        gql_communities: List[CommunityType] = []
        # N+1 for counts and viewer status - optimize later
        for db_comm in db_communities:
            comm_id_int = db_comm['id']
            # Fetch graph counts to potentially override/add online count
            graph_counts = crud.get_community_counts(cursor, comm_id_int)
            db_comm_with_counts = dict(db_comm); db_comm_with_counts.update(graph_counts)
            gql_comm = map_db_community_to_gql_community(db_comm_with_counts)
            if gql_comm:
                if viewer_id:
                    cypher_q = f"RETURN EXISTS((:User {{id:{viewer_id}}})-[:MEMBER_OF]->(:Community {{id:{comm_id_int}}})) as member"
                    member_res = execute_cypher(cursor, cypher_q, fetch_one=True)
                    member_map = member_res if isinstance(member_res, dict) else {}
                    gql_comm.is_member_by_viewer = bool(member_map.get('member', False))
                else:
                    gql_comm.is_member_by_viewer = False
                gql_communities.append(gql_comm)
        return gql_communities
    except Exception as e: print(f"Error in get_trending_communities resolver: {e}"); return []
    finally:
        if conn: conn.close()


# --- Event Resolvers ---
async def get_event_resolver(info: strawberry.Info, id: strawberry.ID, requesting_viewer_id: Optional[int] = None) -> Optional[EventType]:
    """Resolver for fetching a single event, handling viewer context."""
    print(f"GraphQL Resolver: get_event(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id") if requesting_viewer_id is None else requesting_viewer_id
    try:
        event_id_int = int(id)
        conn = get_db_connection()
        cursor = conn.cursor()
        db_event = crud.get_event_details_db(cursor, event_id_int) # Fetches combined data
        gql_event = map_db_event_to_gql_event(db_event, viewer_id)
        if not gql_event: return None

        if viewer_id:
            cypher_q = f"RETURN EXISTS((:User {{id:{viewer_id}}})-[:PARTICIPATED_IN]->(:Event {{id:{event_id_int}}})) as participating"
            part_res = execute_cypher(cursor, cypher_q, fetch_one=True)
            part_map = part_res if isinstance(part_res, dict) else {}
            gql_event.is_participating_by_viewer = bool(part_map.get('participating', False))
        else:
            gql_event.is_participating_by_viewer = False

        return gql_event
    except ValueError: return None
    except Exception as e: print(f"Error in get_event resolver: {e}"); return None
    finally:
        if conn: conn.close()

# --- Reply Resolvers ---
async def get_reply_resolver(info: strawberry.Info, id: strawberry.ID, viewer_id_if_different: Optional[int] = None) -> Optional[ReplyType]:
    """Resolver for fetching a single reply, handling viewer context."""
    print(f"GraphQL Resolver: get_reply(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id") if viewer_id_if_different is None else viewer_id_if_different
    try:
        reply_id_int = int(id)
        conn = get_db_connection()
        cursor = conn.cursor()
        db_reply = crud.get_reply_by_id(cursor, reply_id_int) # Fetch relational base
        if not db_reply: return None
        counts = crud.get_reply_counts(cursor, reply_id_int) # Fetch graph counts
        db_reply_with_counts = dict(db_reply); db_reply_with_counts.update(counts)

        gql_reply = map_db_reply_to_gql_reply(db_reply_with_counts, viewer_id)
        if not gql_reply: return None

        # Fetch Author
        db_author = crud.get_user_by_id(cursor, db_reply['user_id'])
        gql_reply.author = map_db_user_to_gql_user(db_author)

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

# --- Field Resolvers (Implement logic for nested fields defined in gql_types.py) ---

async def get_community_members_resolver(info: strawberry.Info, community_id_int: int, limit: int, offset: int, requesting_viewer_id: Optional[int]) -> List[UserType]:
    """Resolver for CommunityType.members field."""
    print(f"Resolver: get_community_members(comm_id={community_id_int}, limit={limit}, offset={offset})")
    conn = None
    # Use requesting_viewer_id passed from the parent resolver context
    viewer_id: Optional[int] = requesting_viewer_id
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Assumes crud.get_community_members_graph exists and works
        db_members = crud.get_community_members_graph(cursor, community_id_int, limit, offset)

        gql_members: List[UserType] = []
        for db_member in db_members:
            gql_user = map_db_user_to_gql_user(db_member) # Basic map
            if gql_user:
                # Check viewer follow status (N+1)
                if viewer_id is not None and viewer_id != db_member['id']:
                    cypher_q = f"RETURN EXISTS((:User {{id: {viewer_id}}})-[:FOLLOWS]->(:User {{id: {db_member['id']}}})) as following"
                    follow_res = execute_cypher(cursor, cypher_q, fetch_one=True)
                    follow_map = follow_res if isinstance(follow_res, dict) else {}
                    gql_user.is_followed_by_viewer = bool(follow_map.get('following', False))
                else:
                    gql_user.is_followed_by_viewer = False
                gql_members.append(gql_user)
        return gql_members
    except Exception as e: print(f"Error get_community_members_resolver: {e}"); return []
    finally:
        if conn: conn.close()

async def get_community_events_resolver(info: strawberry.Info, community_id_int: int, limit: int, offset: int, requesting_viewer_id: Optional[int]) -> List[EventType]:
    """Resolver for CommunityType.events field."""
    print(f"Resolver: get_community_events(comm_id={community_id_int}, limit={limit}, offset={offset})")
    conn = None
    viewer_id: Optional[int] = requesting_viewer_id
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Assumes crud.get_events_for_community_db fetches combined data
        # Need to add limit/offset support to it or slice here
        db_events = crud.get_events_for_community_db(cursor, community_id_int)
        # Basic slicing (inefficient for large offsets)
        db_events_paginated = db_events[offset : offset + limit]

        gql_events: List[EventType] = []
        for db_event in db_events_paginated:
            gql_event = map_db_event_to_gql_event(db_event, viewer_id)
            if gql_event:
                # Check viewer participation status (N+1)
                if viewer_id:
                    event_id_int = int(gql_event.id)
                    cypher_q = f"RETURN EXISTS((:User {{id:{viewer_id}}})-[:PARTICIPATED_IN]->(:Event {{id:{event_id_int}}})) as participating"
                    part_res = execute_cypher(cursor, cypher_q, fetch_one=True)
                    part_map = part_res if isinstance(part_res, dict) else {}
                    gql_event.is_participating_by_viewer = bool(part_map.get('participating', False))
                else:
                    gql_event.is_participating_by_viewer = False
                gql_events.append(gql_event)
        return gql_events
    except Exception as e: print(f"Error get_community_events_resolver: {e}"); return []
    finally:
        if conn: conn.close()

async def get_event_participants_resolver(info: strawberry.Info, event_id_int: int, limit: int, offset: int, requesting_viewer_id: Optional[int]) -> List[UserType]:
    """Resolver for EventType.participants field."""
    print(f"Resolver: get_event_participants(event_id={event_id_int}, limit={limit}, offset={offset})")
    conn = None
    viewer_id: Optional[int] = requesting_viewer_id
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Assumes crud.get_event_participants_graph exists/works
        db_participants = crud.get_event_participants_graph(cursor, event_id_int, limit, offset) # Add offset here

        gql_participants: List[UserType] = []
        for db_participant in db_participants:
            gql_user = map_db_user_to_gql_user(db_participant)
            if gql_user:
                # Check viewer follow status (N+1)
                if viewer_id is not None and viewer_id != db_participant['id']:
                    cypher_q = f"RETURN EXISTS((:User {{id: {viewer_id}}})-[:FOLLOWS]->(:User {{id: {db_participant['id']}}})) as following"
                    follow_res = execute_cypher(cursor, cypher_q, fetch_one=True)
                    follow_map = follow_res if isinstance(follow_res, dict) else {}
                    gql_user.is_followed_by_viewer = bool(follow_map.get('following', False))
                else:
                    gql_user.is_followed_by_viewer = False
                gql_participants.append(gql_user)
        return gql_participants
    except Exception as e: print(f"Error get_event_participants_resolver: {e}"); return []
    finally:
        if conn: conn.close()


async def get_replies_resolver(info: strawberry.Info, post_id_int: int, limit: int, offset: int, viewer_id_if_different: Optional[int]) -> List[ReplyType]:
    """Resolver for PostType.replies field."""
    print(f"Resolver: get_replies(post_id={post_id_int}, limit={limit}, offset={offset})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id") if viewer_id_if_different is None else viewer_id_if_different
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Assumes get_replies_for_post_db returns combined data (relational + counts)
        # Need to add limit/offset support or slice here
        db_replies = crud.get_replies_for_post_db(cursor, post_id_int)
        # Basic slicing
        db_replies_paginated = db_replies[offset : offset + limit]

        gql_replies: List[ReplyType] = []
        # N+1 fetching for author and viewer status
        for db_reply in db_replies_paginated:
            gql_reply = map_db_reply_to_gql_reply(db_reply, viewer_id)
            if gql_reply:
                reply_id_int = int(gql_reply.id)
                # Fetch Author
                db_author = crud.get_user_by_id(cursor, db_reply['user_id'])
                gql_reply.author = map_db_user_to_gql_user(db_author)

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

# --- Add resolvers for UserType.communities, UserType.events, ReplyType.parent_reply etc. ---
# These will follow similar patterns, calling appropriate CRUD functions and mapping results.