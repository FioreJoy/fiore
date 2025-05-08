# backend/src/schemas.py

from fastapi import Query
from pydantic import BaseModel, Field, validator, EmailStr
from typing import List, Optional, Dict, Any, Literal
from datetime import datetime
from enum import Enum as PyEnum

# --- Location Schemas (Ensure these are defined as before) ---
class LocationPointInput(BaseModel):
    longitude: float = Field(..., ge=-180, le=180)
    latitude: float = Field(..., ge=-90, le=90)

class LocationDataOutput(LocationPointInput): # For responses
    address: Optional[str] = None
    last_updated: Optional[datetime] = None # Specifically for user location

class NearbyQueryParams(BaseModel): # Ensure this is correctly defined for router
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    radius_km: float = Field(..., gt=0, le=100, description="Search radius in kilometers")
    limit: int = Query(20, ge=1, le=100) # Query is FastAPI specific, not for pure Pydantic model
    offset: int = Query(0, ge=0)         # So, for schema use Field or default
# --- Auth Schemas ---
class LoginRequest(BaseModel):
    email: EmailStr
    password: str

# For internal use or if structured signup data is needed beyond Forms
class SignupData(BaseModel):
    name: str
    username: str
    email: EmailStr
    password: str
    gender: str
    current_location: str = "(0,0)"
    college: str
    interests: List[str] = []
    image_path: Optional[str] = None

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel): # For decoding token payload & login response
    token: str
    user_id: int
    image_url: Optional[str] = None # Include image URL on login/signup

class MediaItemDisplay(BaseModel):
    id: int
    url: Optional[str] # Pre-signed URL from MinIO
    mime_type: str
    file_size_bytes: Optional[int] = None
    original_filename: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    duration_seconds: Optional[float] = None
    created_at: datetime

    class Config: from_attributes = True

# --- User Schemas ---
class UserBase(BaseModel):
    id: int
    name: str
    username: str
    email: EmailStr
    gender: str
    college: Optional[str] = None
    interest: Optional[str] = None # For the single text interest
    image_url: Optional[str] = None
    # Use LocationDataOutput for displaying location
    current_location: Optional[LocationDataOutput] = Field(None, alias="location") # Alias if DB returns 'location' as the object

    class Config:
        from_attributes = True
        populate_by_name = True # Allow Pydantic to use alias

# --- Search Schemas ---
class SearchResultItem(BaseModel):
    id: int
    type: Literal['user', 'community', 'post']
    name: str
    snippet: Optional[str] = None
    image_url: Optional[str] = None
    author_name: Optional[str] = None
    community_name: Optional[str] = None
    created_at: Optional[datetime] = None
    # Add location if search results should include it
    location_display: Optional[str] = None # e.g., "City, State" or coordinates string
    distance_km: Optional[float] = None # For nearby search results

    class Config:
        from_attributes = True

class SearchResponse(BaseModel):
    query: str
    results: List[SearchResultItem]
    offset: int
    limit: int
    total_estimated: Optional[int] = None
class UserDisplay(UserBase):
    created_at: datetime
    last_seen: Optional[datetime] = None
    interests: List[str] = [] # For the JSONB interests, populated from 'interests' db field
    followers_count: int = 0
    following_count: int = 0
    is_following: bool = False
    # current_location is inherited

class UserUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1)
    username: Optional[str] = Field(None, min_length=3)
    gender: Optional[str] = None
    college: Optional[str] = None
    interest: Optional[str] = None # For single text interest
    interests: Optional[List[str]] = None # For JSONB interests list
    # Location fields for update (used by router Form fields):
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    location_address: Optional[str] = Field(None, max_length=500) # Text address

# Schema for password change
class PasswordChange(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=6)


# --- Post Schemas ---
class PostBase(BaseModel):
    title: str = Field(..., min_length=1)
    content: str = Field(..., min_length=1)

class PostCreate(PostBase): # Used for internal logic if needed
    community_id: Optional[int] = None
    image_path: Optional[str] = None # Path from MinIO upload

class PostDisplay(PostBase):
    id: int
    user_id: int
    created_at: datetime
    author_name: Optional[str] = None
    author_avatar_url: Optional[str] = None # Full URL for author's avatar
    image_url: Optional[str] = None # Full URL for the post's image
    upvotes: int = 0
    downvotes: int = 0
    reply_count: int = 0
    community_id: Optional[int] = None
    community_name: Optional[str] = None
    media: Optional[List[MediaItemDisplay]] = [] # Default to empty list

    class Config:
        from_attributes = True


# --- Reply Schemas ---
class ReplyBase(BaseModel):
    content: str = Field(..., min_length=1)

class ReplyCreate(ReplyBase): # Input for creating a reply
    post_id: int
    parent_reply_id: Optional[int] = None

class ReplyDisplay(ReplyBase):
    id: int
    post_id: int
    user_id: int
    parent_reply_id: Optional[int] = None
    created_at: datetime
    author_name: Optional[str] = None
    author_avatar_url: Optional[str] = None # Full URL for author's avatar
    upvotes: int = 0
    downvotes: int = 0
    media: Optional[List[MediaItemDisplay]] = [] # Default to empty list


class Config:
        from_attributes = True


# --- Community Schemas ---
class CommunityBase(BaseModel):
    name: str = Field(..., min_length=3)
    description: Optional[str] = None
    interest: Optional[str] = None
    # Output for display:
    location: Optional[LocationDataOutput] = None # This will hold lon, lat, and address
    # The input for create/update will use separate fields (location_address, latitude, longitude) handled by the router

    class Config:
        from_attributes = True

class CommunityCreateInputApi(BaseModel): # Schema for API input if using JSON body
    name: str = Field(..., min_length=3)
    description: Optional[str] = None
    interest: Optional[str] = None
    location_address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # Logo handled as separate UploadFile in router

class CommunityUpdateInputApi(BaseModel): # Schema for API input if using JSON body
    name: Optional[str] = Field(None, min_length=3)
    description: Optional[str] = None
    interest: Optional[str] = None
    location_address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # Logo handled by separate endpoint

class CommunityDisplay(CommunityBase):
    id: int
    created_by: int
    created_at: datetime
    member_count: int = 0
    online_count: int = 0
    logo_url: Optional[str] = None
    is_member_by_viewer: Optional[bool] = None # If you add this logic
    # location is inherited from CommunityBase


# --- Vote Schemas ---
class VoteCreate(BaseModel):
    post_id: Optional[int] = None
    reply_id: Optional[int] = None
    vote_type: bool

    # @validator('post_id', 'reply_id', always=True) # <-- COMMENT OUT or DELETE
    # def check_one_target(cls, v: Any, values: Dict[str, Any]) -> Any:
    #     post_id = values.get('post_id')
    #     reply_id = values.get('reply_id')
    #     if (post_id is not None and reply_id is not None) or \
    #             (post_id is None and reply_id is None):
    #         raise ValueError('Must vote on exactly one of post_id or reply_id')
    #     return v


class VoteDisplay(BaseModel):
    id: int
    user_id: int
    post_id: Optional[int]
    reply_id: Optional[int]
    vote_type: bool
    created_at: datetime

    class Config:
        from_attributes = True


# --- Event Schemas ---
class EventBase(BaseModel):
    title: str = Field(..., min_length=3, max_length=255)
    description: Optional[str] = None
    location_address: str = Field(..., min_length=3, alias="location") # Text address, alias from DB 'location'
    event_timestamp: datetime
    max_participants: int = Field(gt=0, default=100)
    image_url: Optional[str] = None
    # Output for display:
    location_coords: Optional[LocationPointInput] = None # This will hold lon, lat from DB's location_coords

    class Config:
        from_attributes = True
        populate_by_name = True

class EventCreateInputApi(BaseModel): # If using JSON body for event creation
    community_id: int
    title: str
    description: Optional[str] = None
    location_address: str # Text address
    event_timestamp: datetime
    max_participants: Optional[int] = 100
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # Image handled as UploadFile in router

class EventUpdateInputApi(BaseModel): # If using JSON body for event update
    title: Optional[str] = None
    description: Optional[str] = None
    location_address: Optional[str] = None # Text address
    event_timestamp: Optional[datetime] = None
    max_participants: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # Image handled as UploadFile

class EventDisplay(EventBase):
    id: int
    community_id: int
    creator_id: int
    created_at: datetime
    participant_count: int = 0
    is_participating_by_viewer: Optional[bool] = None # If you add this logic
    # location_address and location_coords are inherited



# --- Chat Schemas ---
class ChatMessageCreate(BaseModel): # Input via WS or HTTP Post body
    content: str = Field(..., min_length=1)

class ChatMessageData(BaseModel): # Structure for WS broadcast & HTTP GET response
    message_id: int
    community_id: Optional[int] = None
    event_id: Optional[int] = None
    user_id: int
    username: str # Include username for display convenience
    content: str
    timestamp: datetime
    media: Optional[List[MediaItemDisplay]] = [] # Default to empty list

    class Config:
        from_attributes = True


# --- Settings & Privacy Schemas (Placeholders/Examples) ---

# Example: Notification Settings (adapt fields as needed)
class NotificationSettings(BaseModel):
    new_post_in_community: bool = True
    new_reply_to_post: bool = True
    new_event_in_community: bool = True
    event_reminder: bool = True
    direct_message: bool = False # Example if DMs are added

    class Config:
        from_attributes = True

# Example: Blocked User Info (adapt fields as needed)
class BlockedUserDisplay(BaseModel):
    block_id: int # ID of the block relationship itself
    blocked_user_id: int
    blocked_username: str
    blocked_at: datetime
    # Could include blocked user's avatar URL
    blocked_user_avatar_url: Optional[str] = None

    class Config:
        from_attributes = True


class UserStats(BaseModel):
    communities_joined: int
    events_attended: int
    posts_created: int

class UserDisplay(UserBase):
    id: int
    created_at: datetime
    last_seen: Optional[datetime] = None
    interests: List[str] = []
    followers_count: int = 0
    following_count: int = 0
    is_following: bool = False # Add this field

class BlockedUserDisplay(BaseModel):
    blocked_id: int
    blocked_at: datetime
    blocked_username: str
    blocked_name: Optional[str] = None # Make optional if name can be null
    blocked_user_avatar_url: Optional[str] = None

    class Config:
        from_attributes = True # Pydantic v2
        # orm_mode = True # Pydantic v1

class BlockedUserDisplay(BaseModel):
    blocked_id: int
    blocked_at: datetime
    blocked_username: str
    blocked_name: Optional[str] = None
    blocked_user_avatar_url: Optional[str] = None # Ensure it's Optional

    class Config: from_attributes = True

class NotificationTypeEnum(str, PyEnum):
    new_follower = "new_follower"
    post_reply = "post_reply"
    reply_reply = "reply_reply"
    post_vote = "post_vote"
    reply_vote = "reply_vote"
    post_favorite = "post_favorite"
    reply_favorite = "reply_favorite"
    event_invite = "event_invite"
    event_reminder = "event_reminder"
    event_update = "event_update"
    community_invite = "community_invite"
    community_post = "community_post"
    # community_event = "new_event_in_community" # Old name
    new_community_event = "new_community_event" # <-- ADDED/RENAMED
    user_mention = "user_mention"

class NotificationEntityTypeEnum(str, PyEnum):
    user = "user"
    post = "post"
    reply = "reply"
    community = "community"
    event = "event"

class NotificationActorInfo(BaseModel):
    id: int
    username: str
    name: Optional[str] = None
    avatar_url: Optional[str] = None # Full URL

class NotificationRelatedEntityInfo(BaseModel):
    type: Optional[NotificationEntityTypeEnum] = None
    id: Optional[int] = None
    title: Optional[str] = None # e.g., post title, event title, community name
    # url_slug: Optional[str] = None # For frontend navigation if needed

class NotificationDisplay(BaseModel):
    id: int
    type: NotificationTypeEnum
    is_read: bool
    created_at: datetime
    content_preview: Optional[str] = None
    actor: Optional[NotificationActorInfo] = None
    related_entity: Optional[NotificationRelatedEntityInfo] = None

    class Config:
        from_attributes = True

class UnreadNotificationCount(BaseModel):
    count: int

class NotificationReadUpdate(BaseModel):
    notification_ids: List[int]
    is_read: bool = True # Default to marking as read

# --- Device Token Schema ---
class DevicePlatformEnum(str, PyEnum):
    ios = "ios"
    android = "android"
    web = "web"

class UserDeviceTokenCreate(BaseModel):
    device_token: str
    platform: DevicePlatformEnum

class UserDeviceTokenDisplay(UserDeviceTokenCreate):
    id: int
    user_id: int
    last_used_at: datetime
    created_at: datetime

    class Config:
        from_attributes = True
