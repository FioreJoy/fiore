# src/graphql/mappings.py
import strawberry
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone

# Import utils for parsing, URL generation etc.
from .. import utils
# Import GQL Types (use forward references/strings if needed, but direct import is fine here if definitions exist)
from .types import UserType, CommunityType, PostType, ReplyType, EventType, LocationType, MediaItemDisplay, UserStats, VoteTypeEnum

# --- Mapping Helper Functions ---

def map_db_user_to_gql_user(
        db_user: Optional[Dict[str, Any]],
        counts: Optional[Dict[str, int]] = None,
        profile_pic_media: Optional[Dict[str, Any]] = None,
        is_followed_by_viewer: Optional[bool] = None
) -> Optional[UserType]:
    if not db_user: return None
    user_data = dict(db_user)
    if counts: user_data.update(counts)

    location_obj: Optional[LocationType] = None # Initialize to None
    location_dict: Optional[Dict[str, float]] = None # Initialize to None

    # Check if longitude and latitude are present from the DB query (e.g., from get_user_by_id)
    db_longitude = user_data.get('longitude')
    db_latitude = user_data.get('latitude')

    if db_longitude is not None and db_latitude is not None:
        location_dict = {'longitude': float(db_longitude), 'latitude': float(db_latitude)}
        # location_obj = LocationType(**location_dict) # This is fine
        # For LocationDataOutput (which UserBase.current_location expects):
        location_obj = LocationDataOutput(
            longitude=float(db_longitude),
            latitude=float(db_latitude),
            address=user_data.get('location_address'), # Assuming 'location_address' is fetched
            last_updated=user_data.get('location_last_updated') # Assuming 'location_last_updated' is fetched
        )
    else:
        # Fallback: Try parsing 'current_location' if it's a string like "(lon,lat)"
        # This part is legacy and might be removed if DB consistently provides lon/lat columns
        location_point_str = user_data.get('current_location_legacy_point_str') # Assuming a different key for this old format
        if location_point_str:
            parsed_dict = utils.parse_point_string(str(location_point_str))
            if parsed_dict:
                location_dict = parsed_dict # Keep for LocationType if used directly
                location_obj = LocationDataOutput( # For UserBase.current_location
                    longitude=parsed_dict['longitude'],
                    latitude=parsed_dict['latitude'],
                    address=user_data.get('location_address')
                    # last_updated not typically available from just a point string
                )

    # The 'interests' field in UserType is aliased to 'interests_list' in Python code
    # The database provides 'interests' (jsonb) and 'interest' (text).
    # CRUD get_user_by_id should ideally return 'interests' as a Python list.
    interests_list_from_db = user_data.get('interests') # Expect this to be a list from jsonb
    if not isinstance(interests_list_from_db, list):
        # Fallback to text 'interest' column if jsonb 'interests' is not a list
        text_interest = user_data.get('interest')
        interests_list_from_db = text_interest.split(',') if text_interest and text_interest.strip() else []

    image_url = None
    if profile_pic_media: image_url = utils.get_minio_url(profile_pic_media.get('minio_object_name'))

    return UserType(
        id=strawberry.ID(str(user_data['id'])),
        name=user_data.get('name', ''),
        username=user_data.get('username', ''),
        email=user_data.get('email'),
        gender=user_data.get('gender', ''),
        college=user_data.get('college'),
        interest=user_data.get('interest'), # The raw text field
        interests_list=interests_list_from_db, # The list for GQL 'interests' field
        image_url=image_url,
        current_location=location_obj, # This should be LocationDataOutput
        # current_location_address is now part of location_obj
        created_at=user_data.get('created_at', datetime.now(timezone.utc)),
        last_seen=user_data.get('last_seen'),
        followers_count=int(user_data.get('followers_count', 0)),
        following_count=int(user_data.get('following_count', 0)),
        is_followed_by_viewer=is_followed_by_viewer
    )

# Similar robustness for location_dict in map_db_community_to_gql_community
def map_db_community_to_gql_community(
        db_community: Optional[Dict[str, Any]],
        counts: Optional[Dict[str, int]] = None, logo_media: Optional[Dict[str, Any]] = None,
        is_member_by_viewer: Optional[bool] = None
) -> Optional[CommunityType]:
    if not db_community: return None
    comm_data = dict(db_community)
    if counts: comm_data.update(counts)

    location_obj: Optional[LocationDataOutput] = None # For CommunityDisplay.location
    db_longitude = comm_data.get('longitude')
    db_latitude = comm_data.get('latitude')

    if db_longitude is not None and db_latitude is not None:
        location_obj = LocationDataOutput(
            longitude=float(db_longitude),
            latitude=float(db_latitude),
            address=comm_data.get('location_address')
        )
    # Legacy point string parsing (if 'primary_location' still exists and might contain it)
    # else:
    #    location_point_str = comm_data.get('primary_location_legacy_point_str')
    #    if location_point_str: parsed_dict = utils.parse_point_string(str(location_point_str))
    #    if parsed_dict: location_obj = LocationDataOutput(longitude=parsed_dict['longitude'], latitude=parsed_dict['latitude'], address=comm_data.get('location_address'))

    logo_url = None
    if logo_media: logo_url = utils.get_minio_url(logo_media.get('minio_object_name'))

    return CommunityType(
        id=strawberry.ID(str(comm_data['id'])),
        name=comm_data.get('name', ''),
        description=comm_data.get('description'),
        created_by_id=int(comm_data['created_by']),
        created_at=comm_data.get('created_at', datetime.now(timezone.utc)),
        location=location_obj, # This is LocationDataOutput now
        interest=comm_data.get('interest'),
        logo_url=logo_url,
        member_count=int(comm_data.get('member_count', 0)),
        online_count=int(comm_data.get('online_count', 0)),
        is_member_by_viewer=is_member_by_viewer
    )

# And in map_db_event_to_gql_event for EventType.location_coords
def map_db_event_to_gql_event(
        db_event: Optional[Dict[str, Any]],
        viewer_participation_status: Optional[bool] = False,
) -> Optional[EventType]:
    if not db_event: return None
    event_data = dict(db_event)

    location_coords_obj: Optional[LocationPointInput] = None
    db_longitude = event_data.get('longitude')
    db_latitude = event_data.get('latitude')
    if db_longitude is not None and db_latitude is not None:
        location_coords_obj = LocationPointInput(
            longitude=float(db_longitude),
            latitude=float(db_latitude)
        )

    image_object_name = event_data.get('image_url')
    image_url_for_gql = utils.get_minio_url(image_object_name) if image_object_name else None

    creator_id = event_data.get('creator_id'); community_id = event_data.get('community_id')
    if creator_id is None or community_id is None: print(f"WARN Mapping Event {event_data.get('id')}: Missing creator_id or community_id."); return None

    return EventType(
        id=strawberry.ID(str(event_data['id'])),
        title=event_data.get('title', ''),
        description=event_data.get('description'),
        location_address=event_data.get('location', ''), # Text address from DB 'location' column
        event_timestamp=event_data.get('event_timestamp', datetime.now(timezone.utc)),
        max_participants=int(event_data.get('max_participants', 0)),
        image_url=image_url_for_gql, # Use the generated presigned URL
        created_at=event_data.get('created_at', datetime.now(timezone.utc)),
        creator_id=int(creator_id),
        community_id=int(community_id),
        participant_count=int(event_data.get('participant_count', 0)),
        is_participating_by_viewer=viewer_participation_status,
        location_coords=location_coords_obj # This is LocationPointInput
    )
def map_db_post_to_gql_post(
        db_post: Optional[Dict[str, Any]],
        # Pass IDs needed by field resolvers
        author_id: Optional[int] = None, community_id: Optional[int] = None,
        # Pass viewer status explicitly
        viewer_vote_status: Optional[bool] = None, viewer_favorite_status: Optional[bool] = False,
) -> Optional[PostType]:
    if not db_post: return None
    post_data = dict(db_post)
    # --- Map boolean to STRING "UP"/"DOWN" or None ---
    vote_type_str: Optional[str] = None
    if viewer_vote_status is True: vote_type_str = "UP"
    elif viewer_vote_status is False: vote_type_str = "DOWN"
    # --- End Map ---
    effective_author_id = author_id if author_id is not None else post_data.get('user_id')
    effective_community_id = community_id if community_id is not None else post_data.get('community_id')
    if effective_author_id is None: print(f"WARN Mapping Post {post_data.get('id')}: Missing author ID."); return None
    return PostType(
        id=strawberry.ID(str(post_data['id'])), title=post_data.get('title', ''), content=post_data.get('content', ''),
        created_at=post_data.get('created_at', datetime.now(timezone.utc)),
        reply_count=int(post_data.get('reply_count', 0)), upvotes=int(post_data.get('upvotes', 0)),
        downvotes=int(post_data.get('downvotes', 0)), favorite_count=int(post_data.get('favorite_count', 0)),
        # Assign the STRING value or None
        viewer_vote_type=vote_type_str, # type: ignore <-- Ignore type mismatch, Strawberry handles coercion
        viewer_has_favorited=viewer_favorite_status,
        author_id=int(effective_author_id), community_id=effective_community_id )

def map_db_reply_to_gql_reply(
        db_reply: Optional[Dict[str, Any]],
        viewer_vote_status: Optional[bool] = None, viewer_favorite_status: Optional[bool] = False,
) -> Optional[ReplyType]:
    if not db_reply: return None
    reply_data = dict(db_reply)
    # --- Map boolean to STRING "UP"/"DOWN" or None ---
    vote_type_str: Optional[str] = None
    if viewer_vote_status is True: vote_type_str = "UP"
    elif viewer_vote_status is False: vote_type_str = "DOWN"
    # --- End Map ---
    author_id = reply_data.get('user_id');
    if author_id is None: print(f"WARN Mapping Reply {reply_data.get('id')}: Missing author ID."); return None
    return ReplyType(
        id=strawberry.ID(str(reply_data['id'])), content=reply_data.get('content', ''),
        created_at=reply_data.get('created_at', datetime.now(timezone.utc)),
        post_id=int(reply_data['post_id']), parent_reply_id=reply_data.get('parent_reply_id'),
        upvotes=int(reply_data.get('upvotes', 0)), downvotes=int(reply_data.get('downvotes', 0)),
        favorite_count=int(reply_data.get('favorite_count', 0)),
        # Assign the STRING value or None
        viewer_vote_type=vote_type_str, # type: ignore <-- Ignore type mismatch
        viewer_has_favorited=viewer_favorite_status,
        author_id=int(author_id) )
def map_db_media_to_gql_media(db_media: Optional[Dict[str, Any]]) -> Optional[MediaItemDisplay]:
    if not db_media: return None
    media_data = dict(db_media); object_name = media_data.get('minio_object_name')
    url = utils.get_minio_url(object_name) if object_name else None
    media_id = media_data.get('id'); mime_type = media_data.get('mime_type'); created_at = media_data.get('created_at')
    if media_id is None or mime_type is None or created_at is None: print(f"WARN Mapping Media: Missing required field. Data: {media_data}"); return None
    return MediaItemDisplay(
        id=strawberry.ID(str(media_id)), url=url, mime_type=mime_type,
        file_size_bytes=media_data.get('file_size_bytes'), original_filename=media_data.get('original_filename'),
        width=media_data.get('width'), height=media_data.get('height'),
        duration_seconds=media_data.get('duration_seconds'), created_at=created_at )

def map_db_user_stats_to_gql(db_stats: Optional[Dict[str, Any]]) -> Optional[UserStats]:
    if not db_stats: return None
    stats_data = dict(db_stats)
    return UserStats( communities_joined=int(stats_data.get('communities_joined', 0)), events_attended=int(stats_data.get('events_attended', 0)), posts_created=int(stats_data.get('posts_created', 0)),)
