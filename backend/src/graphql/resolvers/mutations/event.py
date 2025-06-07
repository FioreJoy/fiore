# backend/src/graphql/resolvers/mutations/event.py
import strawberry
from typing import Optional
import psycopg2
from strawberry.types import Info
from datetime import datetime # For datetime type

from .... import crud
from ....database import get_db_connection
from ...types import EventType, EventCreateInput # EventUpdateInput
from ...mappings import map_db_event_to_gql_event
from .common import _get_authenticated_user_id, _commit_and_fetch_event_gql

async def create_event_resolver(info: Info, event_input: EventCreateInput) -> EventType:
    user_id = _get_authenticated_user_id(info)
    conn = None; event_id_int = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        if not crud.get_community_by_id(cursor, event_input.community_id):
            raise ValueError(f"Community {event_input.community_id} not found.")

        location_coords_wkt = None # Map from EventCreateInput if it contains lat/lon
        # if event_input.latitude and event_input.longitude:
        #     location_coords_wkt = f"POINT({event_input.longitude} {event_input.latitude})"

        event_info_dict = crud.create_event_db(
            cursor, community_id=event_input.community_id, creator_id=user_id, title=event_input.title,
            description=event_input.description, location_address=event_input.location,
            event_timestamp=event_input.event_timestamp,
            max_participants=event_input.max_participants or 100, image_url=None, # GQL create no image for now
            location_coords_wkt=location_coords_wkt
        )
        if not event_info_dict or 'id' not in event_info_dict: raise Exception("Failed to create event in DB.")
        event_id_int = event_info_dict['id']

        created_event_gql = await _commit_and_fetch_event_gql(conn, info, event_id_int)
        # TODO: Broadcast 'new_event_in_community' via SIO if needed.
        return created_event_gql
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not create event via GQL: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

async def join_event_resolver(info: Info, event_id: strawberry.ID) -> bool:
    user_id = _get_authenticated_user_id(info)
    conn = None
    try:
        event_id_int = int(event_id)
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.join_event_db(cursor, event_id=event_id_int, user_id=user_id)
        conn.commit(); return success
    except ValueError as ve: # Handles "Event full" or "not found"
        if conn: conn.rollback(); raise Exception(str(ve)) from ve
    except (Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not join event: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

async def leave_event_resolver(info: Info, event_id: strawberry.ID) -> bool:
    user_id = _get_authenticated_user_id(info)
    conn = None
    try:
        event_id_int = int(event_id)
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.leave_event_db(cursor, event_id=event_id_int, user_id=user_id)
        conn.commit(); return success
    except (Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not leave event: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

# async def update_event_resolver(info: Info, event_id: strawberry.ID, input: EventUpdateInput) -> Optional[EventType]: ...