# backend/src/graphql/resolvers/mutations/community.py
import strawberry
from typing import Optional
import psycopg2
from strawberry.types import Info

from .... import crud
from ....database import get_db_connection
from ...types import CommunityType, CommunityCreateInput # CommunityUpdateInput
from ...mappings import map_db_community_to_gql_community
from .common import _get_authenticated_user_id, _commit_and_fetch_community_gql

async def create_community_resolver(info: Info, community_input: CommunityCreateInput) -> CommunityType:
    user_id = _get_authenticated_user_id(info)
    conn = None; community_id_int = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        # Adapt location input if GQL input schema differs from REST Form.
        # For example, if GQL input takes lat/lon directly:
        # location_coords_wkt = f"POINT({community_input.longitude} {community_input.latitude})" if community_input.longitude and community_input.latitude else None
        # For now, assume CommunityCreateInput provides similar fields or default as necessary
        location_coords_wkt = None # TODO: Map from community_input if GQL type has location
        location_address = None # TODO: Map from community_input if GQL type has location

        community_id_int = crud.create_community_db(
            cursor, name=community_input.name, description=community_input.description,
            created_by=user_id, interest=community_input.interest,
            location_address=location_address,
            location_coords_wkt=location_coords_wkt
        )
        if not community_id_int: raise Exception("Failed to create community in DB.")

        created_community_gql = await _commit_and_fetch_community_gql(conn, info, community_id_int)
        return created_community_gql
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not create community via GQL: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

async def join_community_resolver(info: Info, community_id: strawberry.ID) -> bool:
    user_id = _get_authenticated_user_id(info)
    conn = None
    try:
        community_id_int = int(community_id)
        conn = get_db_connection(); cursor = conn.cursor()
        if not crud.get_community_by_id(cursor, community_id_int): raise ValueError("Community not found.")
        success = crud.join_community_db(cursor, user_id, community_id_int)
        conn.commit(); return success
    except (ValueError, Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not join community: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

async def leave_community_resolver(info: Info, community_id: strawberry.ID) -> bool:
    user_id = _get_authenticated_user_id(info)
    conn = None
    try:
        community_id_int = int(community_id)
        conn = get_db_connection(); cursor = conn.cursor()
        success = crud.leave_community_db(cursor, user_id, community_id_int)
        conn.commit(); return success
    except (Exception, psycopg2.Error) as e:
        if conn: conn.rollback(); raise Exception(f"Could not leave community: {str(e)[:200]}") from e
    finally:
        if conn: conn.close()

# async def update_community_resolver(info: Info, community_id: strawberry.ID, input: CommunityUpdateInput) -> Optional[CommunityType]: ...