# src/graphql/resolvers/query.py
import strawberry
from typing import Optional, List, Dict, Any
import psycopg2
import traceback
from strawberry.types import Info

# --- Local Imports ---
from ... import crud, utils, schemas
from ...database import get_db_connection
# Import GQL Types needed for return types (from the new structure)
from ..types import UserType, CommunityType, PostType, ReplyType, EventType
# Import Mapping functions
from ..mappings import (
    map_db_user_to_gql_user, map_db_community_to_gql_community,
    map_db_post_to_gql_post, map_db_reply_to_gql_reply, map_db_event_to_gql_event
)

# --- Helper Function for Viewer Status ---
# Keep this helper or move it to a shared utility if used elsewhere
def _get_viewer_status_for_item(cursor, viewer_id: Optional[int], post_id: Optional[int] = None, reply_id: Optional[int] = None) -> Dict[str, Any]:
    """ Fetches viewer's vote and favorite status for a Post or Reply. """
    status = {'vote_type': None, 'is_favorited': False}
    if not viewer_id: return status
    item_id = post_id or reply_id
    if not item_id: return status
    item_label = "Post" if post_id else "Reply"
    try:
        status['vote_type'] = crud.get_viewer_vote_status(cursor, viewer_id, post_id=post_id, reply_id=reply_id)
        status['is_favorited'] = crud.get_viewer_favorite_status(cursor, viewer_id, post_id=post_id, reply_id=reply_id)
    except Exception as e: print(f"WARN: Failed getting viewer status for {item_label} {item_id}: {e}")
    return status

# --- Resolver Functions (Defined before the Query class) ---

# Note: These functions are now standalone async functions.
# Strawberry will automatically map them to fields in the Query class below.

async def get_user_resolver(info: Info, id: strawberry.ID) -> Optional[UserType]:
    """ Fetches a specific user by their ID, including counts and viewer follow status. """
    print(f"GraphQL Resolver: get_user(id={id})")
    conn = None
    # Get viewer from context if needed for follow status
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        user_id_int = int(id)
        conn = get_db_connection(); cursor = conn.cursor()
        db_user = crud.get_user_by_id(cursor, user_id_int)
        if not db_user: return None
        counts = crud.get_user_graph_counts(cursor, user_id_int)
        pic_media = crud.get_user_profile_picture_media(cursor, user_id_int)
        is_followed = None
        if viewer_id is not None and viewer_id != user_id_int:
            try: is_followed = crud.check_is_following(cursor, viewer_id, user_id_int)
            except Exception as e: print(f"WARN: check follow failed V:{viewer_id} -> T:{user_id_int}: {e}")
        gql_user = map_db_user_to_gql_user(db_user, counts=counts, profile_pic_media=pic_media, is_followed_by_viewer=is_followed)
        return gql_user
    except ValueError: print(f"ERROR: Invalid user ID format '{id}'"); return None
    except (Exception, psycopg2.Error) as e: print(f"Error in get_user_resolver: {e}"); traceback.print_exc(); return None
    finally:
        if conn: conn.close()

async def get_viewer(info: Info) -> Optional[UserType]:
    """ Fetches the profile of the currently authenticated user. """
    print(f"GraphQL Resolver: get_viewer")
    # Auth should ideally populate user_id in context via dependency/middleware
    viewer_id: Optional[int] = info.context.get("user_id")
    if viewer_id is None:
        print("WARN: get_viewer called but no user_id in context.")
        return None
    # Reuse the user resolver logic
    return await get_user_resolver(info, strawberry.ID(str(viewer_id)))

async def get_posts_resolver(
        info: Info,
        community_id: Optional[int] = None,
        user_id: Optional[int] = None, # Filter by author
        # Removed post_id_single, use get_post_resolver for single fetch
        limit: int = 20,
        offset: int = 0
) -> List[PostType]:
    """ Fetches a list of posts, optionally filtered. Includes counts, media, author, viewer status. """
    print(f"GraphQL Resolver: get_posts (Comm: {community_id}, User: {user_id}, Limit: {limit})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Pass viewer_id to CRUD if needed for filtering (e.g., blocked content)
        posts_db = crud.get_posts_db(cursor, community_id=community_id, user_id=user_id, limit=limit, offset=offset)
        gql_posts: List[PostType] = []
        for db_post_dict in posts_db:
            post_id = db_post_dict['id']
            # Fetch Media
            try:
                db_media = crud.get_media_items_for_post(cursor, post_id)
                gql_media = [map_db_media_to_gql_media(m) for m in db_media]
                media_list = [m for m in gql_media if m is not None]
            except Exception as e: print(f"WARN GQL posts: Failed getting media P:{post_id}: {e}"); media_list = []
            # Fetch Viewer Status
            viewer_status = _get_viewer_status_for_item(cursor, viewer_id, post_id=post_id)
            # Map
            gql_post = map_db_post_to_gql_post(db_post_dict, viewer_vote_status=viewer_status['vote_type'], viewer_favorite_status=viewer_status['is_favorited'])
            if gql_post:
                gql_post.media = media_list # Assign mapped media list
                gql_posts.append(gql_post)
        return gql_posts
    except (Exception, psycopg2.Error) as e: print(f"GraphQL Resolver Error fetching posts: {e}"); traceback.print_exc(); return []
    finally:
        if conn: conn.close()

async def get_post_resolver(info: Info, id: strawberry.ID) -> Optional[PostType]:
    """ Fetches a single post by ID. """
    print(f"GraphQL Resolver: get_post(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        post_id_int = int(id)
        conn = get_db_connection(); cursor = conn.cursor()
        # Fetch base data
        db_post = crud.get_post_by_id(cursor, post_id_int)
        if not db_post: return None
        # Augment
        post_data = dict(db_post)
        try: post_data.update(crud.get_post_counts(cursor, post_id_int))
        except Exception as e: print(f"WARN get_post: counts failed P:{post_id_int}: {e}"); post_data.update({"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0})
        try:
            db_media = crud.get_media_items_for_post(cursor, post_id_int)
            gql_media = [map_db_media_to_gql_media(m) for m in db_media]
            media_list = [m for m in gql_media if m is not None]
        except Exception as e: print(f"WARN get_post: media failed P:{post_id_int}: {e}"); media_list = []
        viewer_status = _get_viewer_status_for_item(cursor, viewer_id, post_id=post_id_int)
        # Map
        gql_post = map_db_post_to_gql_post(post_data, viewer_vote_status=viewer_status['vote_type'], viewer_favorite_status=viewer_status['is_favorited'])
        if gql_post: gql_post.media = media_list
        return gql_post
    except ValueError: print(f"ERROR: Invalid post ID format '{id}'"); return None
    except (Exception, psycopg2.Error) as e: print(f"Error in get_post_resolver: {e}"); traceback.print_exc(); return None
    finally:
        if conn: conn.close()

async def get_community_resolver(info: Info, id: strawberry.ID) -> Optional[CommunityType]:
    """ Fetches a specific community by ID, including counts and viewer status. """
    print(f"GraphQL Resolver: get_community(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        comm_id_int = int(id)
        conn = get_db_connection(); cursor = conn.cursor()
        db_community = crud.get_community_details_db(cursor, comm_id_int) # Gets counts too
        if not db_community: return None
        logo_media_db = crud.get_community_logo_media(cursor, comm_id_int)
        is_member = None
        if viewer_id:
            try: is_member = crud.check_is_member(cursor, viewer_id, comm_id_int)
            except Exception as e: print(f"WARN get_comm: Check member failed C:{comm_id_int} V:{viewer_id}: {e}")
        gql_community = map_db_community_to_gql_community(db_community, counts=db_community, logo_media=logo_media_db, is_member_by_viewer=is_member)
        return gql_community
    except ValueError: print(f"ERROR: Invalid community ID format '{id}'"); return None
    except (Exception, psycopg2.Error) as e: print(f"Error in get_community_resolver: {e}"); traceback.print_exc(); return None
    finally:
        if conn: conn.close()

async def get_communities(info: Info, limit: int = 50, offset: int = 0) -> List[CommunityType]:
    """ Fetches a list of all communities. """
    print(f"GraphQL Resolver: get_communities (Limit: {limit})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        db_communities = crud.get_communities_db(cursor) # Add limit/offset here?
        gql_communities: List[CommunityType] = []
        for db_comm in db_communities[offset:offset+limit]:
            comm_id = db_comm['id']
            # Augment N+1
            counts = crud.get_community_counts(cursor, comm_id)
            logo_media = crud.get_community_logo_media(cursor, comm_id)
            is_member = None
            if viewer_id:
                try: is_member = crud.check_is_member(cursor, viewer_id, comm_id)
                except Exception: pass
            gql_comm = map_db_community_to_gql_community(db_comm, counts=counts, logo_media=logo_media, is_member_by_viewer=is_member)
            if gql_comm: gql_communities.append(gql_comm)
        return gql_communities
    except (Exception, psycopg2.Error) as e: print(f"Error in get_communities resolver: {e}"); traceback.print_exc(); return []
    finally:
        if conn: conn.close()

async def get_trending_communities_resolver(info: Info, limit: int = 15) -> List[CommunityType]:
    """ Fetches trending communities. """
    print(f"GraphQL Resolver: get_trending_communities (Limit: {limit})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        db_communities = crud.get_trending_communities_db(cursor) # Limit applied in CRUD
        gql_communities: List[CommunityType] = []
        for db_comm in db_communities:
            comm_id = db_comm['id']
            # Augment N+1
            counts = crud.get_community_counts(cursor, comm_id)
            logo_media = crud.get_community_logo_media(cursor, comm_id)
            is_member = None
            if viewer_id:
                try: is_member = crud.check_is_member(cursor, viewer_id, comm_id)
                except Exception: pass
            combined_data = dict(db_comm); combined_data.update(counts) # Combine counts
            gql_comm = map_db_community_to_gql_community(combined_data, counts=combined_data, logo_media=logo_media, is_member_by_viewer=is_member)
            if gql_comm: gql_communities.append(gql_comm)
        return gql_communities
    except (Exception, psycopg2.Error) as e: print(f"Error in get_trending_communities resolver: {e}"); traceback.print_exc(); return []
    finally:
        if conn: conn.close()

async def get_event_resolver(info: Info, id: strawberry.ID) -> Optional[EventType]:
    """ Fetches a specific event by ID, including counts and viewer status. """
    print(f"GraphQL Resolver: get_event(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        event_id_int = int(id)
        conn = get_db_connection(); cursor = conn.cursor()
        db_event = crud.get_event_details_db(cursor, event_id_int) # Includes counts
        if not db_event: return None
        is_participating = None
        if viewer_id:
            try: is_participating = crud.check_is_participating(cursor, viewer_id, event_id_int)
            except Exception as e: print(f"WARN get_event: Check participation failed E:{event_id_int} V:{viewer_id}: {e}")
        gql_event = map_db_event_to_gql_event(db_event, viewer_participation_status=is_participating)
        return gql_event
    except ValueError: print(f"ERROR: Invalid event ID format '{id}'"); return None
    except (Exception, psycopg2.Error) as e: print(f"Error in get_event_resolver: {e}"); traceback.print_exc(); return None
    finally:
        if conn: conn.close()

async def get_replies_resolver(
        info: Info, post_id: int, limit: int = 20, offset: int = 0,
        viewer_id_if_different: Optional[int] = None # Not typically needed here
) -> List[ReplyType]:
    """ Fetches replies for a specific post. """
    print(f"GraphQL Resolver: get_replies(post_id={post_id}, limit={limit})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        replies_db = crud.get_replies_for_post_db(cursor, post_id) # Includes counts, basic author
        gql_replies: List[ReplyType] = []
        paginated_replies = replies_db[offset : offset + limit]
        for db_reply_dict in paginated_replies:
            reply_id = db_reply_dict['id']
            viewer_status = _get_viewer_status_for_item(cursor, viewer_id, reply_id=reply_id)
            try: # Fetch media
                db_media = crud.get_media_items_for_reply(cursor, reply_id)
                gql_media = [map_db_media_to_gql_media(m) for m in db_media]
                media_list = [m for m in gql_media if m is not None]
            except Exception as e: print(f"WARN GQL replies: Failed getting media R:{reply_id}: {e}"); media_list = []
            gql_reply = map_db_reply_to_gql_reply(db_reply_dict, viewer_vote_status=viewer_status['vote_type'], viewer_favorite_status=viewer_status['is_favorited'])
            if gql_reply:
                gql_reply.media = media_list # Assign mapped media
                gql_replies.append(gql_reply)
        return gql_replies
    except (Exception, psycopg2.Error) as e: print(f"GraphQL Resolver Error fetching replies: {e}"); traceback.print_exc(); return []
    finally:
        if conn: conn.close()

async def get_reply_resolver(info: Info, id: strawberry.ID) -> Optional[ReplyType]:
    """ Fetches a single reply by ID. """
    print(f"GraphQL Resolver: get_reply(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        reply_id_int = int(id)
        conn = get_db_connection(); cursor = conn.cursor()
        db_reply = crud.get_reply_by_id(cursor, reply_id_int)
        if not db_reply: return None
        # Augment
        reply_data = dict(db_reply)
        try: reply_data.update(crud.get_reply_counts(cursor, reply_id_int))
        except Exception: pass
        try:
            media_items = crud.get_media_items_for_reply(cursor, reply_id_int)
            gql_media = [map_db_media_to_gql_media(m) for m in media_items]
            reply_data['media'] = [m for m in gql_media if m is not None]
        except Exception: reply_data['media'] = []
        viewer_status = _get_viewer_status_for_item(cursor, viewer_id, reply_id=reply_id_int)
        # Map
        gql_reply = map_db_reply_to_gql_reply(reply_data, viewer_vote_status=viewer_status['vote_type'], viewer_favorite_status=viewer_status['is_favorited'])
        if gql_reply: gql_reply.media = reply_data['media']
        return gql_reply
    except ValueError: print(f"ERROR: Invalid reply ID format '{id}'"); return None
    except (Exception, psycopg2.Error) as e: print(f"Error in get_reply_resolver: {e}"); traceback.print_exc(); return None
    finally:
        if conn: conn.close()


# --- DEFINE THE QUERY CLASS ---
# Strawberry uses this class to find the fields/resolvers
@strawberry.type
class Query:
    user: Optional[UserType] = strawberry.field(resolver=get_user_resolver, description="Fetch a specific user by their ID.")
    viewer: Optional[UserType] = strawberry.field(resolver=get_viewer, description="Fetch the profile of the currently authenticated user.")
    posts: List[PostType] = strawberry.field(resolver=get_posts_resolver, description="Fetch posts, filtered by community or user.")
    post: Optional[PostType] = strawberry.field(resolver=get_post_resolver, description="Fetch a specific post by its ID.")
    community: Optional[CommunityType] = strawberry.field(resolver=get_community_resolver, description="Fetch a specific community by its ID.")
    communities: List[CommunityType] = strawberry.field(resolver=get_communities, description="Fetch a list of all communities.")
    trending_communities: List[CommunityType] = strawberry.field(resolver=get_trending_communities_resolver, description="Fetch trending communities.")
    event: Optional[EventType] = strawberry.field(resolver=get_event_resolver, description="Fetch a specific event by its ID.")
    # Note: Replies are typically fetched via the PostType.replies field resolver
    # reply: Optional[ReplyType] = strawberry.field(resolver=get_reply_resolver, description="Fetch a specific reply by ID.")