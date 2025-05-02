# backend/src/gql_types.py
import strawberry
from typing import List, Optional, Dict, Any
from datetime import datetime

# --- Location Type (No changes needed) ---
@strawberry.type
class LocationType:
    longitude: float
    latitude: float

# --- User Type (Updated with counts, follow status) ---
@strawberry.type
class UserType:
    id: strawberry.ID # Use strawberry.ID for IDs
    name: str
    username: str
    email: Optional[str] = None # Make optional or remove if not exposing
    gender: str
    college: Optional[str] = None
    interest: Optional[str] = None # Comma-separated from DB
    interests_list: List[str] = strawberry.field(name="interests") # New field for parsed list
    image_url: Optional[str] = None # Expose the generated URL
    current_location: Optional[LocationType] = None # Use the nested LocationType
    current_location_address: Optional[str] = None # Add the address string
    created_at: datetime
    last_seen: Optional[datetime] = None
    followers_count: int = 0 # From graph
    following_count: int = 0 # From graph
    # Field indicating if the *requesting* user follows *this* user
    is_followed_by_viewer: Optional[bool] = None # Needs context in resolver

    # --- Example resolvers for related data ---
    # Define PostType before using it here or use forward reference
    # @strawberry.field
    # async def posts(self, info: strawberry.Info, limit: int = 10) -> List["PostType"]:
    #     # Access self.id (needs conversion back to int)
    #     user_id = int(self.id)
    #     # Use info.context if needed for auth/db connection
    #     # Fetch posts using crud function for this user_id
    #     # Example: db_posts = crud.get_posts_db(..., user_id=user_id, limit=limit)
    #     # Map db_posts to List[PostType]
    #     # return mapped_posts
    #     pass # Replace with actual logic

    # @strawberry.field
    # async def communities(self, info: strawberry.Info) -> List["CommunityType"]:
    #     # Fetch communities this user is a member of using graph query
    #     # Example: db_communities = crud.get_user_joined_communities_graph(...)
    #     # Map db_communities to List[CommunityType]
    #     # return mapped_communities
    #     pass # Replace with actual logic

# --- Community Type (Updated with counts) ---
@strawberry.type
class CommunityType:
    id: strawberry.ID
    name: str
    description: Optional[str] = None
    # created_by: UserType # Can nest creator UserType (requires resolver)
    created_by_id: int = strawberry.field(name="creatorId") # Or just expose ID
    created_at: datetime
    primary_location: Optional[LocationType] = None # Use LocationType
    interest: Optional[str] = None
    logo_url: Optional[str] = None # Expose MinIO URL
    member_count: int = 0 # From graph
    online_count: int = 0 # From graph (if implemented)
    # Field indicating if the *requesting* user is a member of *this* community
    is_member_by_viewer: Optional[bool] = None # Needs context in resolver

    # @strawberry.field
    # async def creator(self, info: strawberry.Info) -> UserType:
    #     # Fetch user details for self.created_by_id
    #     pass

    # @strawberry.field
    # async def posts(self, info: strawberry.Info, limit: int = 10) -> List["PostType"]:
    #     # Fetch posts belonging to this community (self.id)
    #     pass

# --- Post Type (Updated with counts, author, community, vote/fav status) ---
@strawberry.type
class PostType:
    id: strawberry.ID
    title: str
    content: str
    created_at: datetime
    image_url: Optional[str] = None # Expose MinIO URL
    author: Optional["UserType"] = None # Nested author info
    community: Optional["CommunityType"] = None # Nested community info (partial?)
    reply_count: int = 0 # From graph
    upvotes: int = 0 # From graph
    downvotes: int = 0 # From graph
    favorite_count: int = 0 # From graph
    # Status specific to the *requesting* user
    viewer_vote_type: Optional[str] = None # 'UP', 'DOWN', or None
    viewer_has_favorited: Optional[bool] = None # Needs context in resolver

    # @strawberry.field
    # async def replies(self, info: strawberry.Info, limit: int = 5) -> List["ReplyType"]:
    #    # Fetch replies for this post (self.id)
    #    pass

# --- Reply Type (Updated with counts, author, vote/fav status) ---
@strawberry.type
class ReplyType:
    id: strawberry.ID
    content: str
    created_at: datetime
    author: Optional["UserType"] = None # Nested author info
    post_id: int # ID of the post it belongs to
    parent_reply_id: Optional[int] = None # For threading
    upvotes: int = 0 # From graph
    downvotes: int = 0 # From graph
    favorite_count: int = 0 # From graph
    # Status specific to the *requesting* user
    viewer_vote_type: Optional[str] = None # 'UP', 'DOWN', or None
    viewer_has_favorited: Optional[bool] = None # Needs context in resolver

    # @strawberry.field
    # async def parent_reply(self, info: strawberry.Info) -> Optional["ReplyType"]:
    #    # Fetch parent reply if self.parent_reply_id exists
    #    pass

    # @strawberry.field
    # async def replies(self, info: strawberry.Info, limit: int = 3) -> List["ReplyType"]:
    #    # Fetch direct replies to this reply (self.id)
    #    pass

# --- Event Type (Updated with counts) ---
@strawberry.type
class EventType:
    id: strawberry.ID
    title: str
    description: Optional[str] = None
    location: str
    event_timestamp: datetime
    max_participants: int
    image_url: Optional[str] = None # MinIO URL
    created_at: datetime
    # creator: UserType # Nested creator info (requires resolver)
    creator_id: int
    # community: CommunityType # Nested community info (requires resolver)
    community_id: int
    participant_count: int = 0 # From graph
    # Status specific to the *requesting* user
    is_participating_by_viewer: Optional[bool] = None # Needs context


# --- Forward References Setup (if needed, place after all type definitions) ---
# This helps resolve circular dependencies (e.g., User has posts, Post has author)
# UserType.posts = strawberry.field(...) # Assign resolver after PostType defined
# PostType.author = strawberry.field(...)
# PostType.community = strawberry.field(...)
# PostType.replies = strawberry.field(...)
# ReplyType.author = strawberry.field(...)
# ReplyType.parent_reply = strawberry.field(...)
# ReplyType.replies = strawberry.field(...)
# CommunityType.creator = strawberry.field(...)
# CommunityType.posts = strawberry.field(...)
# EventType.creator = strawberry.field(...)
# EventType.community = strawberry.field(...)