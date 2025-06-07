# backend/src/graphql/resolvers/mutations/common.py
from typing import Optional, TYPE_CHECKING, Any, Dict
from strawberry.types import Info
import psycopg2
import strawberry # For strawberry.ID in helper fetches

if TYPE_CHECKING:
    from ....graphql.types import PostType, ReplyType, CommunityType, EventType

# Import Query resolvers to fetch updated data if helpers use them.
# Path assuming this file is in src/graphql/resolvers/mutations/
from ..query import get_post_resolver, get_reply_resolver, get_community_resolver, get_event_resolver

def _get_authenticated_user_id(info: Info) -> int:
    """Gets user ID from context or raises a ValueError."""
    user_id: Optional[int] = info.context.get("user_id")
    if user_id is None:
        raise ValueError("Authentication required for this mutation.")
    return user_id

async def _commit_and_fetch_post_gql(conn: psycopg2.extensions.connection, info: Info, post_id: int) -> "PostType":
    if not post_id: raise ValueError("Invalid post_id")
    try:
        conn.commit()
        fetched_post = await get_post_resolver(info, strawberry.ID(str(post_id)))
        if not fetched_post: raise Exception(f"Failed to fetch post details post-op for ID {post_id}.")
        return fetched_post
    except Exception as e:
        try: conn.rollback()
        except Exception: pass
        raise Exception(f"Error during commit/fetch for Post {post_id}: {e}") from e

async def _commit_and_fetch_reply_gql(conn: psycopg2.extensions.connection, info: Info, reply_id: int) -> "ReplyType":
    if not reply_id: raise ValueError("Invalid reply_id")
    try:
        conn.commit()
        fetched_reply = await get_reply_resolver(info, strawberry.ID(str(reply_id)))
        if not fetched_reply: raise Exception(f"Failed to fetch reply details post-op for ID {reply_id}.")
        return fetched_reply
    except Exception as e:
        try: conn.rollback()
        except Exception: pass
        raise Exception(f"Error during commit/fetch for Reply {reply_id}: {e}") from e

async def _commit_and_fetch_community_gql(conn: psycopg2.extensions.connection, info: Info, community_id: int) -> "CommunityType":
    if not community_id: raise ValueError("Invalid community_id")
    try:
        conn.commit()
        fetched_community = await get_community_resolver(info, strawberry.ID(str(community_id)))
        if not fetched_community: raise Exception(f"Failed to fetch community details post-op for ID {community_id}.")
        return fetched_community
    except Exception as e:
        try: conn.rollback()
        except Exception: pass
        raise Exception(f"Error during commit/fetch for Community {community_id}: {e}") from e

async def _commit_and_fetch_event_gql(conn: psycopg2.extensions.connection, info: Info, event_id: int) -> "EventType":
    if not event_id: raise ValueError("Invalid event_id")
    try:
        conn.commit()
        fetched_event = await get_event_resolver(info, strawberry.ID(str(event_id)))
        if not fetched_event: raise Exception(f"Failed to fetch event details post-op for ID {event_id}.")
        return fetched_event
    except Exception as e:
        try: conn.rollback()
        except Exception: pass
        raise Exception(f"Error during commit/fetch for Event {event_id}: {e}") from e