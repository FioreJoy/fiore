# src/graphql/resolvers/mutations/common.py
from typing import Optional, TYPE_CHECKING
from strawberry.types import Info
import psycopg2

# Import GQL Types needed for return hints
if TYPE_CHECKING:
    from ...types import PostType, ReplyType # Add others as needed

# Import Query resolvers to fetch updated data
from ..query import get_post_resolver, get_reply_resolver # Add others as needed


def _get_authenticated_user_id(info: Info) -> int:
    """Gets user ID from context or raises a ValueError."""
    # TODO: Implement proper auth check using info or dependencies
    user_id: Optional[int] = info.context.get("user_id")
    if user_id is None:
        # This should ideally be handled by a Strawberry Permission class
        raise ValueError("Authentication required for this mutation.")
    return user_id

# Helper to commit and fetch the updated Post object
async def _commit_and_fetch_post(conn: psycopg2.extensions.connection, cursor: psycopg2.extensions.cursor, info: Info, post_id: int) -> "PostType":
    """Commits transaction and fetches the full PostType."""
    if not post_id: raise ValueError("Invalid post_id provided to _commit_and_fetch.")
    try:
        conn.commit()
        print(f"Transaction committed for Post {post_id}")
        # Use the query resolver to fetch the full object with context
        fetched_post = await get_post_resolver(info, strawberry.ID(str(post_id))) # type: ignore
        if not fetched_post:
            raise Exception(f"Failed to fetch post details after operation for ID {post_id}.")
        return fetched_post
    except Exception as e:
        # Rollback might have already happened, but try again just in case
        try: conn.rollback()
        except Exception: pass
        print(f"Error during commit/fetch for Post {post_id}: {e}")
        raise # Re-raise the exception


# Helper to commit and fetch the updated Reply object
async def _commit_and_fetch_reply(conn: psycopg2.extensions.connection, cursor: psycopg2.extensions.cursor, info: Info, reply_id: int) -> "ReplyType":
    """Commits transaction and fetches the full ReplyType."""
    if not reply_id: raise ValueError("Invalid reply_id provided to _commit_and_fetch.")
    try:
        conn.commit()
        print(f"Transaction committed for Reply {reply_id}")
        fetched_reply = await get_reply_resolver(info, strawberry.ID(str(reply_id))) # type: ignore
        if not fetched_reply:
            raise Exception(f"Failed to fetch reply details after operation for ID {reply_id}.")
        return fetched_reply
    except Exception as e:
        try: conn.rollback()
        except Exception: pass
        print(f"Error during commit/fetch for Reply {reply_id}: {e}")
        raise

# Add similar helpers for Community, Event etc. if needed
