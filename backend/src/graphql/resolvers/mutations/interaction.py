# backend/src/graphql/resolvers/mutations/interaction.py
import strawberry
from typing import Optional
import psycopg2
from strawberry.types import Info

from .... import crud
from ....database import get_db_connection
from ...types import VoteInput # For GraphQL input type
from .common import _get_authenticated_user_id
# from ....socketio_manager import sio # If real-time count updates are pushed

async def cast_vote_resolver(info: Info, vote_input: VoteInput) -> bool:
    user_id = _get_authenticated_user_id(info)
    conn = None
    try:
        if not ((vote_input.post_id is not None and vote_input.reply_id is None) or \
                (vote_input.post_id is None and vote_input.reply_id is not None)):
            raise ValueError("Must vote on exactly one of post_id or reply_id")
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.cast_vote_db(cursor, user_id, vote_input.post_id, vote_input.reply_id, vote_input.vote_type)
        # crud.cast_vote_db is expected to update counts internally in graph now
        conn.commit()
        # Optional: emit specific item_counts_updated event
        # target_id = vote_input.post_id or vote_input.reply_id
        # item_type = 'post' if vote_input.post_id else 'reply'
        # counts = crud.get_post_counts(cursor,target_id) if item_type == 'post' else crud.get_reply_counts(cursor, target_id)
        # await sio.emit('counts_updated', {'type': item_type, 'id': target_id, 'counts': counts}, room=f'{item_type}_{target_id}_room') # Or relevant broader room
        return success
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not cast vote via GQL: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

async def remove_vote_resolver(info: Info, post_id: Optional[strawberry.ID] = None, reply_id: Optional[strawberry.ID] = None) -> bool:
    user_id = _get_authenticated_user_id(info)
    conn = None
    try:
        post_id_int = int(post_id) if post_id else None
        reply_id_int = int(reply_id) if reply_id else None
        if not ((post_id_int is not None and reply_id_int is None) or \
                (post_id_int is None and reply_id_int is not None)):
            raise ValueError("Must provide exactly one of post_id or reply_id to remove vote")
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.remove_vote_db(cursor, user_id, post_id_int, reply_id_int)
        conn.commit()
        # Optional: emit counts_updated event similar to cast_vote
        return success
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not remove vote via GQL: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

async def add_favorite_resolver(info: Info, post_id: Optional[strawberry.ID] = None, reply_id: Optional[strawberry.ID] = None) -> bool:
    user_id = _get_authenticated_user_id(info)
    conn = None
    try:
        post_id_int = int(post_id) if post_id else None
        reply_id_int = int(reply_id) if reply_id else None
        if not ((post_id_int is not None and reply_id_int is None) or \
                (post_id_int is None and reply_id_int is not None)):
            raise ValueError("Must favorite exactly one of post_id or reply_id")
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.add_favorite_db(cursor, user_id, post_id_int, reply_id_int)
        conn.commit()
        # Optional: emit counts_updated (favorite_count)
        return success
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not add favorite via GQL: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

async def remove_favorite_resolver(info: Info, post_id: Optional[strawberry.ID] = None, reply_id: Optional[strawberry.ID] = None) -> bool:
    user_id = _get_authenticated_user_id(info)
    conn = None
    try:
        post_id_int = int(post_id) if post_id else None
        reply_id_int = int(reply_id) if reply_id else None
        if not ((post_id_int is not None and reply_id_int is None) or \
                (post_id_int is None and reply_id_int is not None)):
            raise ValueError("Must unfavorite exactly one of post_id or reply_id")
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.remove_favorite_db(cursor, user_id, post_id_int, reply_id_int)
        conn.commit()
        # Optional: emit counts_updated (favorite_count)
        return success
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not remove favorite via GQL: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()