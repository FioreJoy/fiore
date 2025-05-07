# src/graphql/resolvers/mutation.py
import strawberry
from typing import Optional, List, Dict, Any
import psycopg2
import traceback
import json
from strawberry.types import Info

# --- Imports ---
from ... import crud, utils, schemas, auth
from ...database import get_db_connection
from ..types import ( # Import GQL Types and Inputs
    UserType, CommunityType, PostType, ReplyType, EventType, LocationType, MediaItemDisplay,
    PostCreateInput, ReplyCreateInput, CommunityCreateInput, EventCreateInput, VoteInput
)
from ..mappings import ( # Import Mapping functions
    map_db_user_to_gql_user, map_db_community_to_gql_community,
    map_db_post_to_gql_post, map_db_reply_to_gql_reply,
    map_db_event_to_gql_event, map_db_media_to_gql_media
)
# Import Query resolvers if needed to fetch full object after mutation
from .query import get_post_resolver, get_reply_resolver, get_community_resolver, get_event_resolver
from ...connection_manager import manager as ws_manager

# --- Helper Function for Auth Check ---
def _get_authenticated_user_id(info: Info) -> int:
    """Gets user ID from context or raises an error."""
    user_id: Optional[int] = info.context.get("user_id")
    if user_id is None: raise ValueError("Authentication required for this mutation.")
    return user_id

# --- Standalone Mutation Resolver Functions ---
# (Keep all the async def functions like create_post_resolver, delete_post_resolver, etc. here)

async def create_post_resolver(info: Info, post_input: PostCreateInput) -> PostType:
    # ... implementation ...
    print(f"GraphQL Mutation: create_post")
    user_id = _get_authenticated_user_id(info)
    conn = None; post_id = None; comm_exists = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        if post_input.community_id:
            comm_exists = crud.get_community_by_id(cursor, post_input.community_id)
            if not comm_exists: raise ValueError(f"Community {post_input.community_id} not found.")
        post_id = crud.create_post_db(cursor, user_id=user_id, title=post_input.title, content=post_input.content)
        if not post_id: raise Exception("Failed to create post record.")
        if post_input.community_id: crud.add_post_to_community_db(cursor, post_input.community_id, post_id)
        conn.commit()
        created_post_gql = await get_post_resolver(info, strawberry.ID(str(post_id)))
        if not created_post_gql: raise Exception("Failed to fetch created post details via resolver.")
        ws_manager_instance = info.context.get("ws_manager")
        if ws_manager_instance and post_input.community_id:
            room_key = f"community_{post_input.community_id}"; broadcast_payload = {"type": "new_post", "data": { "post_id": post_id, "community_id": post_input.community_id, "user_id": user_id, "title": post_input.title }}
            try: await ws_manager_instance.broadcast(json.dumps(broadcast_payload), room_key)
            except Exception as ws_err: print(f"GQL WARN: Failed WS broadcast for new post {post_id}: {ws_err}")
        return created_post_gql
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in create_post_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not create post: {e}") from e
    finally:
        if conn: conn.close()

async def delete_post_resolver(info: Info, post_id: strawberry.ID) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: delete_post(id={post_id})")
    user_id = _get_authenticated_user_id(info)
    conn = None; media_to_delete = []
    try:
        post_id_int = int(post_id); conn = get_db_connection(); cursor = conn.cursor()
        post = crud.get_post_by_id(cursor, post_id_int);
        if not post: raise ValueError("Post not found.")
        if post["user_id"] != user_id: raise ValueError("Not authorized.")
        media_to_delete = crud.get_media_items_for_post(cursor, post_id_int)
        deleted = crud.delete_post_db(cursor, post_id_int)
        if not deleted: raise Exception("Post deletion failed.")
        conn.commit()
        for item in media_to_delete: utils.delete_media_item_db_and_file(item.get("id"), item.get("minio_object_name"))
        return True
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in delete_post_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not delete post: {e}") from e
    finally:
        if conn: conn.close()

# --- (Implement ALL OTHER resolver functions here...) ---
async def create_reply_resolver(info: Info, reply_input: ReplyCreateInput) -> ReplyType:
    print(f"GraphQL Mutation: create_reply")
    user_id = _get_authenticated_user_id(info) # This is the actor
    conn = None; reply_id = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()

        # Validation
        parent_post = crud.get_post_by_id(cursor, reply_input.post_id)
        if not parent_post: raise ValueError(f"Parent post {reply_input.post_id} not found.")
        parent_post_author_id = parent_post['user_id'] # Get author ID

        parent_reply_author_id = None
        if reply_input.parent_reply_id:
            parent_reply = crud.get_reply_by_id(cursor, reply_input.parent_reply_id)
            if not parent_reply: raise ValueError(f"Parent reply {reply_input.parent_reply_id} not found.")
            if parent_reply.get('post_id') != reply_input.post_id: raise ValueError("Parent reply belongs to a different post.")
            parent_reply_author_id = parent_reply['user_id'] # Get parent reply author

        # Create reply base
        reply_id = crud.create_reply_db(
            cursor, post_id=reply_input.post_id, user_id=user_id,
            content=reply_input.content, parent_reply_id=reply_input.parent_reply_id
        )
        if not reply_id: raise Exception("Failed to create reply record.")

        # --- Create Notifications (BEFORE commit) ---
        content_preview = reply_input.content[:100] + ('...' if len(reply_input.content) > 100 else '')

        # 1. Notify Original Post Author (if not the replier and not replying to own post)
        if parent_post_author_id != user_id:
            notif_id_post = crud.create_notification(
                cursor=cursor,
                recipient_user_id=parent_post_author_id,
                actor_user_id=user_id,
                type='post_reply', # Specific type for direct reply to post
                related_entity_type='post',
                related_entity_id=reply_input.post_id,
                # Optionally link secondary entity (the reply itself)? Or just use preview.
                # related_entity_2_type='reply',
                # related_entity_2_id=reply_id,
                content_preview=content_preview
            )
            if notif_id_post: print(f"Notification created (ID: {notif_id_post}) for post author {parent_post_author_id}.")
            else: print(f"WARN: Failed to create notification for post author.")
            # TODO: Trigger Push/WS for notif_id_post

        # 2. Notify Parent Reply Author (if applicable and different from replier and OP)
        if parent_reply_author_id is not None and \
                parent_reply_author_id != user_id and \
                parent_reply_author_id != parent_post_author_id: # Avoid double-notifying OP
            notif_id_reply = crud.create_notification(
                cursor=cursor,
                recipient_user_id=parent_reply_author_id,
                actor_user_id=user_id,
                type='reply_reply', # Specific type for reply to reply
                related_entity_type='reply', # Link to the parent reply
                related_entity_id=reply_input.parent_reply_id,
                # Optionally link secondary entity (the new reply)?
                # related_entity_2_type='reply',
                # related_entity_2_id=reply_id,
                content_preview=content_preview
            )
            if notif_id_reply: print(f"Notification created (ID: {notif_id_reply}) for parent reply author {parent_reply_author_id}.")
            else: print(f"WARN: Failed to create notification for parent reply author.")
            # TODO: Trigger Push/WS for notif_id_reply

        # TODO: Handle User Mentions (@username) by parsing content, finding user IDs,
        # and creating 'user_mention' notifications.

        # --- End Notifications ---

        conn.commit() # Commit reply creation AND notification inserts

        # Fetch created reply details
        created_reply_gql = await get_reply_resolver(info, strawberry.ID(str(reply_id)))
        if not created_reply_gql: raise Exception("Failed to fetch created reply details.")

        # Broadcast WebSocket event for the new reply itself (separate from notification system)
        # ... (Keep existing WS broadcast logic for the reply content) ...
        ws_manager_instance = info.context.get("ws_manager")
        room_key = None; community_id_for_broadcast = None
        try:
            cypher_q_comm = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {reply_input.post_id}}}) RETURN c.id as id LIMIT 1"; expected_comm = [('id', 'agtype')]
            comm_res = crud.execute_cypher(cursor, cypher_q_comm, fetch_one=True, expected_columns=expected_comm)
            if comm_res and comm_res.get('id'): community_id_for_broadcast = comm_res['id']; room_key = f"community_{community_id_for_broadcast}"
        except Exception as e: print(f"WARN: Failed to get room key for reply broadcast: {e}")
        if ws_manager_instance and room_key:
            broadcast_payload = {"type": "new_reply", "data": { "post_id": reply_input.post_id, "reply_id": reply_id, "parent_reply_id": reply_input.parent_reply_id, "user_id": user_id, "community_id": community_id_for_broadcast, "content_snippet": reply_input.content[:50] + ('...' if len(reply_input.content)>50 else '')}}
            try: await ws_manager_instance.broadcast(json.dumps(broadcast_payload), room_key)
            except Exception as ws_err: print(f"GQL WARN: Failed WS broadcast for new reply {reply_id}: {ws_err}")
        return created_reply_gql

    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback()
        print(f"Error in create_reply_resolver: {e}"); traceback.print_exc()
        raise Exception(f"Could not create reply: {e}") from e
    finally:
        if conn: conn.close()

async def delete_reply_resolver(info: Info, reply_id: strawberry.ID) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: delete_reply(id={reply_id})")
    user_id = _get_authenticated_user_id(info); conn = None; media_to_delete = []
    try:
        reply_id_int = int(reply_id); conn = get_db_connection(); cursor = conn.cursor()
        reply = crud.get_reply_by_id(cursor, reply_id_int)
        if not reply: raise ValueError("Reply not found.")
        if reply["user_id"] != user_id: raise ValueError("Not authorized.")
        media_to_delete = crud.get_media_items_for_reply(cursor, reply_id_int)
        deleted = crud.delete_reply_db(cursor, reply_id_int)
        if not deleted: raise Exception("Reply deletion failed.")
        conn.commit()
        for item in media_to_delete: utils.delete_media_item_db_and_file(item.get("id"), item.get("minio_object_name"))
        return True
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in delete_reply_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not delete reply: {e}") from e
    finally:
        if conn: conn.close()

async def create_community_resolver(info: Info, community_input: CommunityCreateInput) -> CommunityType:
    # ... implementation ...
    print(f"GraphQL Mutation: create_community")
    user_id = _get_authenticated_user_id(info); conn = None; community_id = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        db_location = utils.format_location_for_db(community_input.primary_location)
        community_id = crud.create_community_db(cursor, name=community_input.name, description=community_input.description, created_by=user_id, primary_location_str=db_location, interest=community_input.interest)
        if not community_id: raise Exception("Failed to create community.")
        conn.commit()
        created_community_gql = await get_community_resolver(info, strawberry.ID(str(community_id)))
        if not created_community_gql: raise Exception("Failed to fetch created community.")
        return created_community_gql
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in create_community_resolver: {e}"); traceback.print_exc(); detail = f"Could not create community: {e}";
        if hasattr(e, 'pgcode') and e.pgcode == '23505': detail = "Community name already exists."
        raise Exception(detail) from e
    finally:
        if conn: conn.close()

async def join_community_resolver(info: Info, community_id: strawberry.ID) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: join_community(id={community_id})")
    user_id = _get_authenticated_user_id(info); conn = None
    try:
        community_id_int = int(community_id); conn = get_db_connection(); cursor = conn.cursor()
        comm = crud.get_community_by_id(cursor, community_id_int)
        if not comm: raise ValueError("Community not found.")
        success = crud.join_community_db(cursor, user_id, community_id_int)
        conn.commit(); return success
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in join_community_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not join community: {e}") from e
    finally:
        if conn: conn.close()

async def leave_community_resolver(info: Info, community_id: strawberry.ID) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: leave_community(id={community_id})")
    user_id = _get_authenticated_user_id(info); conn = None
    try:
        community_id_int = int(community_id); conn = get_db_connection(); cursor = conn.cursor()
        success = crud.leave_community_db(cursor, user_id, community_id_int)
        conn.commit(); return success
    except (Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in leave_community_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not leave community: {e}") from e
    finally:
        if conn: conn.close()

async def create_event_resolver(info: Info, event_input: EventCreateInput) -> EventType:
    # ... implementation ...
    print(f"GraphQL Mutation: create_event")
    user_id = _get_authenticated_user_id(info); conn = None; event_id = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        comm = crud.get_community_by_id(cursor, event_input.community_id)
        if not comm: raise ValueError(f"Community {event_input.community_id} not found.")
        event_info = crud.create_event_db(cursor, community_id=event_input.community_id, creator_id=user_id, title=event_input.title, description=event_input.description, location=event_input.location, event_timestamp=event_input.event_timestamp, max_participants=event_input.max_participants or 100, image_url=None)
        if not event_info or 'id' not in event_info: raise Exception("Failed to create event.")
        event_id = event_info['id']
        conn.commit()
        created_event_gql = await get_event_resolver(info, strawberry.ID(str(event_id)))
        if not created_event_gql: raise Exception("Failed to fetch created event.")
        return created_event_gql
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in create_event_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not create event: {e}") from e
    finally:
        if conn: conn.close()

async def join_event_resolver(info: Info, event_id: strawberry.ID) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: join_event(id={event_id})")
    user_id = _get_authenticated_user_id(info); conn = None
    try:
        event_id_int = int(event_id); conn = get_db_connection(); cursor = conn.cursor()
        success = crud.join_event_db(cursor, event_id=event_id_int, user_id=user_id)
        conn.commit(); return success
    except ValueError as ve:
        if conn: conn.rollback(); raise Exception(str(ve))
    except (Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in join_event_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not join event: {e}") from e
    finally:
        if conn: conn.close()

async def leave_event_resolver(info: Info, event_id: strawberry.ID) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: leave_event(id={event_id})")
    user_id = _get_authenticated_user_id(info); conn = None
    try:
        event_id_int = int(event_id); conn = get_db_connection(); cursor = conn.cursor()
        success = crud.leave_event_db(cursor, event_id=event_id_int, user_id=user_id)
        conn.commit(); return success
    except (Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in leave_event_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not leave event: {e}") from e
    finally:
        if conn: conn.close()

async def follow_user_resolver(info: Info, user_id: strawberry.ID) -> bool:
    print(f"GraphQL Mutation: follow_user(id={user_id})")
    follower_id = _get_authenticated_user_id(info) # This is the actor
    conn = None
    try:
        following_id = int(user_id) # This is the recipient
        if follower_id == following_id: raise ValueError("Cannot follow yourself.")

        conn = get_db_connection(); cursor = conn.cursor()
        target = crud.get_user_by_id(cursor, following_id)
        if not target: raise ValueError("User to follow not found.")

        # --- Perform the follow action ---
        success = crud.follow_user(cursor, follower_id, following_id)
        if not success:
            # crud.follow_user might raise an exception on failure,
            # or return False if MERGE didn't error but didn't create.
            # Adjust based on crud.follow_user's actual behavior.
            raise Exception("Follow operation failed.")

        # --- Create Notification (BEFORE commit, part of same transaction) ---
        notification_id = crud.create_notification(
            cursor=cursor,
            recipient_user_id=following_id, # The user being followed receives it
            actor_user_id=follower_id,      # The user who clicked follow
            type='new_follower',
            related_entity_type='user',
            related_entity_id=follower_id   # Link to the follower's profile
        )
        if notification_id:
            print(f"Notification created (ID: {notification_id}) for new follower.")
            # TODO: Enqueue push notification task (Phase 2.3)
            # TODO: Broadcast real-time indicator (Phase 2.4 - Optional WS)
            # Example: await info.context['ws_manager'].broadcast(...) to user_{following_id} room
        else:
            print(f"WARN: Failed to create notification record for follow action.")
            # Don't fail the whole request, just log the warning.
        # --- End Notification ---

        conn.commit() # Commit follow and notification insert together
        return True # Return overall success of the follow action

    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback()
        print(f"Error in follow_user_resolver: {e}"); traceback.print_exc()
        raise Exception(f"Could not follow user: {e}") from e
    finally:
        if conn: conn.close()

async def unfollow_user_resolver(info: Info, user_id: strawberry.ID) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: unfollow_user(id={user_id})")
    follower_id = _get_authenticated_user_id(info); conn = None
    try:
        following_id = int(user_id); conn = get_db_connection(); cursor = conn.cursor()
        success = crud.unfollow_user(cursor, follower_id, following_id)
        conn.commit(); return success
    except (Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in unfollow_user_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not unfollow user: {e}") from e
    finally:
        if conn: conn.close()

async def cast_vote_resolver(info: Info, vote_input: VoteInput) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: cast_vote")
    user_id = _get_authenticated_user_id(info); conn = None
    try:
        if not ((vote_input.post_id is not None and vote_input.reply_id is None) or \
                (vote_input.post_id is None and vote_input.reply_id is not None)):
            raise ValueError("Must vote on exactly one of post_id or reply_id")
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.cast_vote_db(cursor, user_id, vote_input.post_id, vote_input.reply_id, vote_input.vote_type)
        conn.commit(); return success
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in cast_vote_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not cast vote: {e}") from e
    finally:
        if conn: conn.close()

async def remove_vote_resolver(info: Info, post_id: Optional[strawberry.ID] = None, reply_id: Optional[strawberry.ID] = None) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: remove_vote")
    user_id = _get_authenticated_user_id(info); conn = None
    try:
        post_id_int = int(post_id) if post_id else None; reply_id_int = int(reply_id) if reply_id else None
        if not ((post_id_int is not None and reply_id_int is None) or \
                (post_id_int is None and reply_id_int is not None)):
            raise ValueError("Must provide exactly one of post_id or reply_id")
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.remove_vote_db(cursor, user_id, post_id_int, reply_id_int)
        conn.commit(); return success
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in remove_vote_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not remove vote: {e}") from e
    finally:
        if conn: conn.close()

async def add_favorite_resolver(info: Info, post_id: Optional[strawberry.ID] = None, reply_id: Optional[strawberry.ID] = None) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: add_favorite")
    user_id = _get_authenticated_user_id(info); conn = None
    try:
        post_id_int = int(post_id) if post_id else None; reply_id_int = int(reply_id) if reply_id else None
        if not ((post_id_int is not None and reply_id_int is None) or \
                (post_id_int is None and reply_id_int is not None)):
            raise ValueError("Must favorite exactly one of post_id or reply_id")
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.add_favorite_db(cursor, user_id, post_id_int, reply_id_int)
        conn.commit(); return success
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in add_favorite_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not add favorite: {e}") from e
    finally:
        if conn: conn.close()

async def remove_favorite_resolver(info: Info, post_id: Optional[strawberry.ID] = None, reply_id: Optional[strawberry.ID] = None) -> bool:
    # ... implementation ...
    print(f"GraphQL Mutation: remove_favorite")
    user_id = _get_authenticated_user_id(info); conn = None
    try:
        post_id_int = int(post_id) if post_id else None; reply_id_int = int(reply_id) if reply_id else None
        if not ((post_id_int is not None and reply_id_int is None) or \
                (post_id_int is None and reply_id_int is not None)):
            raise ValueError("Must unfavorite exactly one of post_id or reply_id")
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.remove_favorite_db(cursor, user_id, post_id_int, reply_id_int)
        conn.commit(); return success
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); print(f"Error in remove_favorite_resolver: {e}"); traceback.print_exc(); raise Exception(f"Could not remove favorite: {e}") from e
    finally:
        if conn: conn.close()


# --- DEFINE THE MUTATION CLASS ---
@strawberry.type
class Mutation:
    # --- Post Mutations ---
    create_post: PostType = strawberry.mutation(resolver=create_post_resolver)
    delete_post: bool = strawberry.mutation(resolver=delete_post_resolver)
    # TODO: add_post_favorite: bool = strawberry.mutation(...)
    # TODO: remove_post_favorite: bool = strawberry.mutation(...)
    # TODO: update_post: PostType = strawberry.mutation(...)

    # --- Reply Mutations ---
    create_reply: ReplyType = strawberry.mutation(resolver=create_reply_resolver)
    delete_reply: bool = strawberry.mutation(resolver=delete_reply_resolver)
    # TODO: add_reply_favorite: bool = strawberry.mutation(...)
    # TODO: remove_reply_favorite: bool = strawberry.mutation(...)

    # --- Community Mutations ---
    create_community: CommunityType = strawberry.mutation(resolver=create_community_resolver)
    join_community: bool = strawberry.mutation(resolver=join_community_resolver)
    leave_community: bool = strawberry.mutation(resolver=leave_community_resolver)
    # TODO: update_community: CommunityType = strawberry.mutation(...)
    # TODO: delete_community: bool = strawberry.mutation(...) # Requires ownership check

    # --- Event Mutations ---
    create_event: EventType = strawberry.mutation(resolver=create_event_resolver)
    join_event: bool = strawberry.mutation(resolver=join_event_resolver)
    leave_event: bool = strawberry.mutation(resolver=leave_event_resolver)
    # TODO: update_event: EventType = strawberry.mutation(...)
    # TODO: delete_event: bool = strawberry.mutation(...) # Requires ownership check

    # --- Follow Mutations ---
    follow_user: bool = strawberry.mutation(resolver=follow_user_resolver)
    unfollow_user: bool = strawberry.mutation(resolver=unfollow_user_resolver)

    # --- Vote/Favorite Mutations ---
    cast_vote: bool = strawberry.mutation(resolver=cast_vote_resolver)
    remove_vote: bool = strawberry.mutation(resolver=remove_vote_resolver)
    add_favorite: bool = strawberry.mutation(resolver=add_favorite_resolver)
    remove_favorite: bool = strawberry.mutation(resolver=remove_favorite_resolver)

    # TODO: User profile update mutation (handle image via REST or GraphQL Upload)
    # TODO: Block/Unblock user mutations