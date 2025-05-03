# backend/src/schemas.py

from pydantic import BaseModel, Field, validator, EmailStr
from typing import List, Optional, Dict, Any
from datetime import datetime

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

# --- User Schemas ---
class UserBase(BaseModel):
    name: str
    username: str
    email: EmailStr
    gender: str # Consider Enum: 'Male', 'Female', 'Other', 'PreferNotSay'
    college: Optional[str] = None
    interest: Optional[str] = None # Comma-separated string in DB
    image_path: Optional[str] = None # Store path from MinIO
    image_url: Optional[str] = None # Generated full URL for responses
    # Expect frontend to send dict {'latitude': float, 'longitude': float}
    # Or backend parses "(lon,lat)" string from DB into this dict
    current_location: Optional[Dict[str, float]] = None

    class Config:
        from_attributes = True # Pydantic v2 alias for orm_mode

class UserDisplay(UserBase):
    id: int
    created_at: datetime
    last_seen: Optional[datetime] = None
    interests: List[str] = [] # Processed list for frontend

# Schema for updating user profile (PUT /auth/me)
class UserUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1)
    username: Optional[str] = Field(None, min_length=3)
    gender: Optional[str] = None # Validate against allowed values?
    # Expect string "(lon,lat)" for location update via Form
    # college: Optional[str] = None # Already covered by Form params
    interest: Optional[str] = None # Expect comma-separated string via Form?
    # image handled via File upload, path set in route

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

    class Config:
        from_attributes = True


# --- Community Schemas ---
class CommunityBase(BaseModel):
    name: str = Field(..., min_length=3)
    description: Optional[str] = None
    # Expecting "(lon,lat)" string input, or handle dict conversion
    primary_location: str
    interest: Optional[str] = None

class CommunityCreate(CommunityBase): # For internal logic if needed
    logo_path: Optional[str] = None # Path from MinIO upload

class CommunityUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=3)
    description: Optional[str] = None # Allow setting description to null/empty
    primary_location: Optional[str] = None # Allow updating location, expect "(lon,lat)"
    interest: Optional[str] = None # Allow updating interest

    # Note: logo is handled by a separate endpoint/file upload

class CommunityDisplay(CommunityBase):
    id: int
    created_by: int # Consider nesting UserDisplay for creator info?
    created_at: datetime
    member_count: int = 0
    online_count: int = 0 # Calculated field
    logo_url: Optional[str] = None # Full URL for community logo

    class Config:
        from_attributes = True


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
    location: str = Field(..., min_length=3)
    event_timestamp: datetime # Expect ISO 8601 format string from frontend/form
    max_participants: int = Field(gt=0, default=100)
    image_url: Optional[str] = None # Full URL from MinIO (set during creation/update)

class EventCreate(EventBase): # Used for internal processing if needed
    pass

class EventUpdate(BaseModel): # Allow partial updates via Form data
    title: Optional[str] = Field(None, min_length=3, max_length=255)
    description: Optional[str] = None
    location: Optional[str] = Field(None, min_length=3)
    event_timestamp: Optional[datetime] = None
    max_participants: Optional[int] = Field(None, gt=0)
    # image handled via File upload

class EventDisplay(EventBase):
    id: int
    community_id: int
    creator_id: int # Consider nesting UserDisplay?
    created_at: datetime
    participant_count: int = 0 # Calculated field

    class Config:
        from_attributes = True


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