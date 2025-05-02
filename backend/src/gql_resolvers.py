# backend/src/gql_resolvers.py
import strawberry
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone

# --- CORRECTED IMPORTS ---
# Use '.' to import from the same package level (src)
from . import crud  # Access the __init__.py within the crud directory inside src
from . import utils
from . import schemas
from .database import get_db_connection # Import directly if needed
# Import graph helpers from the crud package
from .crud._graph import execute_cypher # Assuming execute_cypher is needed here
# Import GQL Types from the same level
from .gql_types import UserType, CommunityType, PostType, ReplyType, EventType, LocationType
# --- END CORRECTED IMPORTS ---

# === Mapping Helper Functions (Keep as previously defined) ===

def map_db_user_to_gql_user(db_user: Optional[Dict[str, Any]], counts: Optional[Dict[str, int]] = None) -> Optional[UserType]:
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
        is_followed_by_viewer=None # Set by resolver
    )

def map_db_community_to_gql_community(db_community: Optional[Dict[str, Any]]) -> Optional[CommunityType]:
    if not db_community: return None
    comm_data = dict(db_community)
    location_obj = None; location_point_str = comm_data.get('primary_location')
    if location_point_str: location_dict = utils.parse_point_string(str(location_point_str)); location_obj = LocationType(**location_dict) if location_dict else None
    return CommunityType(
        id=strawberry.ID(str(comm_data.get('id'))), name=comm_data.get('name', ''), description=comm_data.get('description'),
        created_by_id=int(comm_data.get('created_by', 0)), created_at=comm_data.get('created_at', datetime.now(timezone.utc)),
        primary_location=location_obj, interest=comm_data.get('interest'), logo_url=utils.get_minio_url(comm_data.get('logo_path')),
        member_count=int(comm_data.get('member_count', 0)), online_count=int(comm_data.get('online_count', 0)),
        is_member_by_viewer=None # Set by resolver
    )

def map_db_post_to_gql_post(db_post: Optional[Dict[str, Any]], viewer_id: Optional[int] = None) -> Optional[PostType]:
    if not db_post: return None
    post_data = dict(db_post)
    gql_post = PostType(
        id=strawberry.ID(str(post_data.get('id'))), title=post_data.get('title', ''), content=post_data.get('content', ''),
        created_at=post_data.get('created_at', datetime.now(timezone.utc)), image_url=utils.get_minio_url(post_data.get('image_path')),
        reply_count=int(post_data.get('reply_count', 0)), upvotes=int(post_data.get('upvotes', 0)),
        downvotes=int(post_data.get('downvotes', 0)), favorite_count=int(post_data.get('favorite_count', 0)),
        author=None, community=None, viewer_vote_type=None, viewer_has_favorited=None # Set by resolver
    )
    return gql_post

def map_db_reply_to_gql_reply(db_reply: Optional[Dict[str, Any]], viewer_id: Optional[int] = None) -> Optional[ReplyType]:
    if not db_reply: return None
    reply_data = dict(db_reply)
    gql_reply = ReplyType(
        id=strawberry.ID(str(reply_data.get('id'))), content=reply_data.get('content', ''),
        created_at=reply_data.get('created_at', datetime.now(timezone.utc)), post_id=int(reply_data.get('post_id', 0)),
        parent_reply_id=reply_data.get('parent_reply_id'), upvotes=int(reply_data.get('upvotes', 0)),
        downvotes=int(reply_data.get('downvotes', 0)), favorite_count=int(reply_data.get('favorite_count', 0)),
        author=None, viewer_vote_type=None, viewer_has_favorited=None # Set by resolver
    )
    return gql_reply

def map_db_event_to_gql_event(db_event: Optional[Dict[str, Any]], viewer_id: Optional[int] = None) -> Optional[EventType]:
    if not db_event: return None
    event_data = dict(db_event)
    gql_event = EventType(
        id=strawberry.ID(str(event_data.get('id'))), title=event_data.get('title', ''), description=event_data.get('description'),
        location=event_data.get('location', ''), event_timestamp=event_data.get('event_timestamp', datetime.now(timezone.utc)),
        max_participants=int(event_data.get('max_participants', 0)), image_url=event_data.get('image_url'), # Assumes full URL
        created_at=event_data.get('created_at', datetime.now(timezone.utc)), creator_id=int(event_data.get('creator_id', 0)),
        community_id=int(event_data.get('community_id', 0)), participant_count=int(event_data.get('participant_count', 0)),
        is_participating_by_viewer=None # Set by resolver
    )
    return gql_event

# --- Helper to get viewer vote/fav status ---
# This demonstrates the N+1 issue - call this inside loops carefully or optimize later
def get_viewer_status_for_item(cursor, viewer_id: int, item_id: int, item_label: str) -> Dict[str, Any]:
    status = {'vote_type': None, 'is_favorited': False}
    if not viewer_id: return status

    # Check vote
    cypher_vote = f"MATCH (:User {{id:{viewer_id}}})-[r:VOTED]->(:{item_label} {{id:{item_id}}}) RETURN r.vote_type as vt"
    vote_res = execute_cypher(cursor, cypher_vote, fetch_one=True)
    if isinstance(vote_res, dict) and 'vt' in vote_res:
        status['vote_type'] = 'UP' if vote_res['vt'] is True else ('DOWN' if vote_res['vt'] is False else None)

    # Check favorite
    cypher_fav = f"RETURN EXISTS((:User {{id:{viewer_id}}})-[:FAVORITED]->(:{item_label} {{id:{item_id}}})) as fav"
    fav_res = execute_cypher(cursor, cypher_fav, fetch_one=True)
    if isinstance(fav_res, dict) and 'fav' in fav_res:
        status['is_favorited'] = bool(fav_res['fav'])

    return status


# === Resolver Functions ===

# --- User Resolvers ---
async def get_user(info: strawberry.Info, id: strawberry.ID) -> Optional[UserType]:
    print(f"GraphQL Resolver: get_user(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
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
            gql_user.is_followed_by_viewer = False # Can't follow self or no viewer
        return gql_user
    except ValueError: return None # Invalid ID format
    except Exception as e: print(f"Error in get_user resolver: {e}"); return None
    finally:
        if conn: conn.close()

async def get_viewer(info: strawberry.Info) -> Optional[UserType]:
    print(f"GraphQL Resolver: get_viewer")
    viewer_id: Optional[int] = info.context.get("user_id")
    if viewer_id is None:
        print("GraphQL Resolver: No viewer ID found in context for get_viewer")
        return None # Not authenticated
    # Call get_user resolver with the viewer's own ID
    return await get_user(info, strawberry.ID(str(viewer_id)))


# --- Post Resolvers ---
async def get_posts(
        info: strawberry.Info,
        community_id: Optional[int] = None,
        user_id: Optional[int] = None,
        limit: int = 20,
        offset: int = 0
) -> List[PostType]:
    print(f"GraphQL Resolver: get_posts (Comm: {community_id}, User: {user_id}, Limit: {limit}, Offset: {offset})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        db_posts = crud.get_posts_db(
            cursor, community_id=community_id, user_id=user_id, limit=limit, offset=offset
        )

        gql_posts: List[PostType] = []
        # TODO: Optimize fetching nested data and viewer status (Dataloaders)
        for db_post in db_posts:
            gql_post = map_db_post_to_gql_post(db_post, viewer_id)
            if gql_post:
                post_id_int = int(gql_post.id)
                # Fetch Author
                author_data = crud.get_user_by_id(cursor, db_post['user_id'])
                if author_data:
                    gql_post.author = map_db_user_to_gql_user(author_data) # Simplified mapping

                # Fetch Community
                if db_post.get('community_id'):
                    comm_data = crud.get_community_details_db(cursor, db_post['community_id'])
                    if comm_data:
                        gql_post.community = map_db_community_to_gql_community(comm_data)

                # Fetch Viewer Status (N+1 Query - Needs Optimization)
                if viewer_id:
                    status = get_viewer_status_for_item(cursor, viewer_id, post_id_int, 'Post')
                    gql_post.viewer_vote_type = status['vote_type']
                    gql_post.viewer_has_favorited = status['is_favorited']

                gql_posts.append(gql_post)
        return gql_posts
    except Exception as e:
        print(f"GraphQL Resolver Error fetching posts: {e}")
        import traceback; traceback.print_exc(); return []
    finally:
        if conn: conn.close()

# --- Community Resolvers ---
async def get_community(info: strawberry.Info, id: strawberry.ID) -> Optional[CommunityType]:
    print(f"GraphQL Resolver: get_community(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
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
    except Exception as e: print(f"Error in get_community resolver: {e}"); return None
    finally:
        if conn: conn.close()

async def get_communities(info: strawberry.Info) -> List[CommunityType]:
    print("GraphQL Resolver: get_communities")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        db_communities = crud.get_communities_db(cursor) # Gets relational list
        gql_communities: List[CommunityType] = []
        # N+1 queries for counts and viewer status - Needs optimization
        for db_comm in db_communities:
            comm_id_int = db_comm['id']
            counts = crud.get_community_counts(cursor, comm_id_int)
            db_comm_with_counts = dict(db_comm); db_comm_with_counts.update(counts)
            gql_comm = map_db_community_to_gql_community(db_comm_with_counts)
            if gql_comm:



                if viewer_id:
                    try:
                        # Simpler test query: Can we find the community node?
                        test_cypher = f"MATCH (c:Community {{id: {comm_id_int}}}) RETURN count(c) as ct"
                        test_res = execute_cypher(cursor, test_cypher, fetch_one=True)
                        print(f"DEBUG: Test MATCH Community {comm_id_int} result: {test_res}")
                        if test_res is None: raise Exception("Community node not found in graph for check")

                        # Now try the EXISTS check again
                        cypher_q = f"RETURN EXISTS((:User {{id:{viewer_id}}})-[:MEMBER_OF]->(:Community {{id:{comm_id_int}}})) as member"
                        member_res = execute_cypher(cursor, cypher_q, fetch_one=True)
                        member_map = member_res if isinstance(member_res, dict) else {}
                        gql_community.is_member_by_viewer = bool(member_map.get('member', False))
                        print(f"DEBUG: Membership check result for viewer {viewer_id} in comm {comm_id_int}: {gql_community.is_member_by_viewer}")

                    except Exception as check_err:
                        print(f"ERROR during viewer status check for community {comm_id_int}: {check_err}")
                        gql_community.is_member_by_viewer = False # Default on error

                else:
                    gql_comm.is_member_by_viewer = False
                gql_communities.append(gql_comm)
        return gql_communities
    except Exception as e: print(f"Error in get_communities resolver: {e}"); return []
    finally:
        if conn: conn.close()

async def get_trending_communities_resolver(info: strawberry.Info) -> List[CommunityType]:
    print("GraphQL Resolver: get_trending_communities")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        # Uses relational trending logic for now
        db_communities = crud.get_trending_communities_db(cursor)
        gql_communities: List[CommunityType] = []
        # N+1 queries for counts and viewer status - Needs optimization
        for db_comm in db_communities:
            comm_id_int = db_comm['id']
            # Fetch graph counts (online count specifically, member count from SQL is likely fine)
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

from .crud._community import get_community_members_graph # NEW CRUD function needed

async def get_community_members_resolver(info: strawberry.Info, community_id_str: strawberry.ID, limit: int, offset: int) -> List[UserType]:
    print(f"Resolver: get_community_members(comm_id={community_id_str}, limit={limit}, offset={offset})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
    try:
        comm_id_int = int(community_id_str) # Convert GQL ID back to int
        conn = get_db_connection()
        cursor = conn.cursor()

        # NEW CRUD function needed: get_community_members_graph
        # This function should query AGE:
        # MATCH (u:User)-[:MEMBER_OF]->(:Community {id: comm_id_int})
        # RETURN u.id, u.username, u.name, u.image_path ORDER BY u.username LIMIT limit OFFSET offset
        db_members = await crud.get_community_members_graph(cursor, comm_id_int, limit, offset) # Assumes async crud or wrap sync

        gql_members: List[UserType] = []
        for db_member in db_members:
            # Map basic data (counts not needed here usually)
            gql_user = map_db_user_to_gql_user(db_member)
            if gql_user:
                # Check follow status if needed (N+1 again!)
                if viewer_id is not None and viewer_id != db_member['id']:
                    cypher_q = f"RETURN EXISTS((:User {{id: {viewer_id}}})-[:FOLLOWS]->(:User {{id: {db_member['id']}}})) as following"
                    follow_res = execute_cypher(cursor, cypher_q, fetch_one=True)
                    follow_map = follow_res if isinstance(follow_res, dict) else {}
                    gql_user.is_followed_by_viewer = bool(follow_map.get('following', False))
                else:
                    gql_user.is_followed_by_viewer = False
                gql_members.append(gql_user)
        return gql_members
    except ValueError: return [] # Invalid ID
    except Exception as e: print(f"Error get_community_members: {e}"); return []
    finally:
        if conn: conn.close()

# --- Event Resolvers ---
async def get_event(info: strawberry.Info, id: strawberry.ID) -> Optional[EventType]:
    print(f"GraphQL Resolver: get_event(id={id})")
    conn = None
    viewer_id: Optional[int] = info.context.get("user_id")
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

# --- Reply Resolvers (Example - if needed directly) ---
# async def get_replies_for_post(info: strawberry.Info, post_id: strawberry.ID) -> List[ReplyType]:
#     # Similar logic to get_posts:
#     # Call crud.get_replies_for_post_db
#     # Loop, map using map_db_reply_to_gql_reply
#     # Fetch nested author
#     # Fetch viewer vote/fav status (N+1)
#     pass