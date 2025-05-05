# src/graphql/types.py
from __future__ import annotations

import enum
from datetime import datetime
from typing import List, Optional, Literal

import strawberry
from aiodataloader import DataLoader
from strawberry.types import Info

from .. import crud, utils
from ..database import get_db_connection

# --- Common Types ---

@strawberry.type
class LocationType:
    longitude: float
    latitude: float

@strawberry.type
class MediaItemDisplay:
    id: strawberry.ID
    url: Optional[str] = strawberry.field(description="Pre-signed URL")
    mime_type: str
    file_size_bytes: Optional[int] = None
    original_filename: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    duration_seconds: Optional[float] = None
    created_at: datetime

@strawberry.enum
class VoteTypeEnum(enum.Enum):
    UP = "UP"
    DOWN = "DOWN"

# --- Input Types ---

@strawberry.input
class PostCreateInput:
    title: str
    content: str
    community_id: Optional[int] = None

@strawberry.input
class PostUpdateInput:
    title: Optional[str] = strawberry.UNSET
    content: Optional[str] = strawberry.UNSET

@strawberry.input
class ReplyCreateInput:
    post_id: int
    content: str
    parent_reply_id: Optional[int] = None

@strawberry.input
class ReplyUpdateInput:
    content: Optional[str] = strawberry.UNSET

@strawberry.input
class CommunityCreateInput:
    name: str
    description: Optional[str] = None
    primary_location: str = "(0,0)"
    interest: Optional[str] = None

@strawberry.input
class CommunityUpdateInput:
    name: Optional[str] = strawberry.UNSET
    description: Optional[str] = strawberry.UNSET
    primary_location: Optional[str] = strawberry.UNSET
    interest: Optional[str] = strawberry.UNSET

@strawberry.input
class EventCreateInput:
    community_id: int
    title: str
    description: Optional[str] = None
    location: str
    event_timestamp: datetime
    max_participants: Optional[int] = 100

@strawberry.input
class EventUpdateInput:
    title: Optional[str] = strawberry.UNSET
    description: Optional[str] = strawberry.UNSET
    location: Optional[str] = strawberry.UNSET
    event_timestamp: Optional[datetime] = strawberry.UNSET
    max_participants: Optional[int] = strawberry.UNSET

@strawberry.input
class VoteInput:
    post_id: Optional[int] = None
    reply_id: Optional[int] = None
    vote_type: bool

# --- Output Types ---

@strawberry.type
class UserStats:
    communities_joined: int
    events_attended: int
    posts_created: int

@strawberry.type
class UserType:
    id: strawberry.ID
    name: str
    username: str
    email: Optional[str]
    gender: str
    college: Optional[str] = None
    interest: Optional[str]
    interests_list: List[str] = strawberry.field(name="interests")
    image_url: Optional[str] = None
    current_location: Optional[LocationType] = None
    current_location_address: Optional[str] = None
    created_at: datetime
    last_seen: Optional[datetime] = None
    followers_count: int = 0
    following_count: int = 0
    is_followed_by_viewer: Optional[bool] = None

    @strawberry.field
    async def posts(self, info: Info, limit: int = 10, offset: int = 0) -> List[PostType]:
        loader = info.context.get("post_loader")
        if not loader:
            raise Exception("Post DataLoader not found.")
        conn = get_db_connection()
        try:
            ids = crud.get_post_ids_by_user(conn.cursor(), int(self.id), limit, offset)
        finally:
            conn.close()
        return [p for p in await loader.load_many(ids) if p]

    @strawberry.field
    async def communities(self, info: Info, limit: int = 10, offset: int = 0) -> List[CommunityType]:
        loader = info.context.get("community_loader")
        if not loader:
            raise Exception("Community DataLoader not found.")
        conn = get_db_connection()
        try:
            ids = crud.get_community_ids_joined_by_user(conn.cursor(), int(self.id), limit, offset)
        finally:
            conn.close()
        return [c for c in await loader.load_many(ids) if c]

    @strawberry.field
    async def events(self, info: Info, limit: int = 10, offset: int = 0) -> List[EventType]:
        loader = info.context.get("event_loader")
        if not loader:
            raise Exception("Event DataLoader not found.")
        conn = get_db_connection()
        try:
            ids = crud.get_event_ids_participated_by_user(conn.cursor(), int(self.id), limit, offset)
        finally:
            conn.close()
        return [e for e in await loader.load_many(ids) if e]

@strawberry.type
class CommunityType:
    id: strawberry.ID
    name: str
    description: Optional[str]
    created_by_id: int
    created_at: datetime
    primary_location: Optional[LocationType]
    interest: Optional[str]
    logo_url: Optional[str]
    member_count: int = 0
    online_count: int = 0
    is_member_by_viewer: Optional[bool] = None

    @strawberry.field
    async def creator(self, info: Info) -> Optional[UserType]:
        loader = info.context.get("user_loader")
        return await loader.load(self.created_by_id) if loader else None

    @strawberry.field
    async def posts(self, info: Info, limit: int = 10, offset: int = 0) -> List[PostType]:
        loader = info.context.get("post_loader")
        conn = get_db_connection()
        try:
            ids = crud.get_post_ids_for_community(conn.cursor(), int(self.id), limit, offset)
        finally:
            conn.close()
        return [p for p in await loader.load_many(ids) if p]

    @strawberry.field
    async def members(self, info: Info, limit: int = 10, offset: int = 0) -> List[UserType]:
        loader = info.context.get("user_loader")
        conn = get_db_connection()
        try:
            ids = crud.get_community_member_ids(conn.cursor(), int(self.id), limit, offset)
        finally:
            conn.close()
        return [u for u in await loader.load_many(ids) if u]

    @strawberry.field
    async def events(self, info: Info, limit: int = 10, offset: int = 0) -> List[EventType]:
        loader = info.context.get("event_loader")
        conn = get_db_connection()
        try:
            ids = crud.get_community_event_ids(conn.cursor(), int(self.id), limit, offset)
        finally:
            conn.close()
        return [e for e in await loader.load_many(ids) if e]

@strawberry.type
class EventType:
    id: strawberry.ID
    title: str
    description: Optional[str]
    location: str
    event_timestamp: datetime
    max_participants: int
    image_url: Optional[str]
    created_at: datetime
    creator_id: int
    community_id: int
    participant_count: int = 0
    is_participating_by_viewer: Optional[bool] = None

    @strawberry.field
    async def creator(self, info: Info) -> Optional[UserType]:
        loader = info.context.get("user_loader")
        return await loader.load(self.creator_id) if loader else None

    @strawberry.field
    async def community(self, info: Info) -> Optional[CommunityType]:
        loader = info.context.get("community_loader")
        return await loader.load(self.community_id) if loader else None

    @strawberry.field
    async def participants(self, info: Info, limit: int = 10, offset: int = 0) -> List[UserType]:
        loader = info.context.get("user_loader")
        conn = get_db_connection()
        try:
            ids = crud.get_event_participant_ids(conn.cursor(), int(self.id), limit, offset)
        finally:
            conn.close()
        return [u for u in await loader.load_many(ids) if u]

@strawberry.type
class PostType:
    id: strawberry.ID
    title: str
    content: str
    created_at: datetime
    author_id: int
    community_id: Optional[int]
    reply_count: int = 0
    upvotes: int = 0
    downvotes: int = 0
    favorite_count: int = 0
    viewer_vote_type: Optional[VoteTypeEnum] = None
    viewer_has_favorited: Optional[bool] = None

    @strawberry.field
    async def author(self, info: Info) -> Optional[UserType]:
        loader = info.context.get("user_loader")
        return await loader.load(self.author_id) if loader else None

    @strawberry.field
    async def community(self, info: Info) -> Optional[CommunityType]:
        if self.community_id is None:
            return None
        loader = info.context.get("community_loader")
        return await loader.load(self.community_id) if loader else None

    @strawberry.field
    async def replies(self, info: Info, limit: int = 10, offset: int = 0) -> List[ReplyType]:
        loader = info.context.get("reply_loader")
        conn = get_db_connection()
        try:
            ids = crud.get_reply_ids_for_post(conn.cursor(), int(self.id), limit, offset)
        finally:
            conn.close()
        return [r for r in await loader.load_many(ids) if r]

    @strawberry.field
    async def media(self, info: Info) -> List[MediaItemDisplay]:
        loader = info.context.get("post_media_loader")
        return await loader.load(int(self.id)) if loader else []

@strawberry.type
class ReplyType:
    id: strawberry.ID
    content: str
    created_at: datetime
    author_id: int
    post_id: int
    parent_reply_id: Optional[int] = None
    upvotes: int = 0
    downvotes: int = 0
    favorite_count: int = 0
    viewer_vote_type: Optional[VoteTypeEnum] = None
    viewer_has_favorited: Optional[bool] = None

    @strawberry.field
    async def author(self, info: Info) -> Optional[UserType]:
        loader = info.context.get("user_loader")
        return await loader.load(self.author_id) if loader else None

    @strawberry.field
    async def parent_reply(self, info: Info) -> Optional[ReplyType]:
        if self.parent_reply_id is None:
            return None
        loader = info.context.get("reply_loader")
        return await loader.load(self.parent_reply_id) if loader else None

    @strawberry.field
    async def media(self, info: Info) -> List[MediaItemDisplay]:
        loader = info.context.get("reply_media_loader")
        return await loader.load(int(self.id)) if loader else []
