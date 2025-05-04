# backend/src/gql_types.py
import strawberry
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone # Ensure timezone is imported

# --- Location Type ---
@strawberry.type
class LocationType:
    """Represents a geographical location with longitude and latitude."""
    longitude: float
    latitude: float

@strawberry.type
class MediaItemDisplay:
    id: strawberry.ID
    url: Optional[str] = None
    mime_type: str
    # Add other optional fields from schemas.MediaItemDisplay if needed
# --- User Type ---
@strawberry.type
class UserType:
    """Represents a user account."""
    id: strawberry.ID
    name: str
    username: str
    # Email might be sensitive, consider making Optional or omitting based on requirements
    email: Optional[str] = strawberry.field(description="User's email (null if not viewer or private)")
    gender: str
    college: Optional[str] = None
    interest: Optional[str] = strawberry.field(description="Raw comma-separated interest string from DB (if stored).")
    interests_list: List[str] = strawberry.field(name="interests", description="List of user interests.")
    image_url: Optional[str] = strawberry.field(description="URL to the user's profile image (may expire).")
    current_location: Optional[LocationType] = strawberry.field(description="User's geographical coordinates.")
    current_location_address: Optional[str] = strawberry.field(description="User's location as a formatted address string.")
    created_at: datetime
    last_seen: Optional[datetime] = None
    followers_count: int = strawberry.field(description="Number of users following this user.")
    following_count: int = strawberry.field(description="Number of users this user is following.")
    # Field indicating if the *requesting* user follows *this* user
    is_followed_by_viewer: Optional[bool] = strawberry.field(description="Does the current viewer follow this user? (null if not logged in)")

    # --- Field resolvers for related data ---
    # Using forward references as PostType/CommunityType defined below
    @strawberry.field
    async def posts(self, info: strawberry.Info, limit: int = 10, offset: int = 0) -> List["PostType"]:
        """Fetches posts written by this user."""
        from . import gql_resolvers # Delayed import
        user_id_int = int(self.id)
        # Pass viewer_id from context for potential nested checks
        viewer_id = info.context.get("user_id")
        return await gql_resolvers.get_posts_resolver(info, user_id=user_id_int, limit=limit, offset=offset, viewer_id_if_different=viewer_id)

    @strawberry.field
    async def communities(self, info: strawberry.Info, limit: int = 10, offset: int = 0) -> List["CommunityType"]:
        """Fetches communities this user is a member of."""
        from . import gql_resolvers # Delayed import
        user_id_int = int(self.id)
        viewer_id = info.context.get("user_id")
        return await gql_resolvers.get_user_communities_resolver(info, user_id_int, limit, offset, requesting_viewer_id=viewer_id)

    @strawberry.field
    async def events(self, info: strawberry.Info, limit: int = 10, offset: int = 0) -> List["EventType"]:
        """Fetches events this user is participating in."""
        from . import gql_resolvers # Delayed import
        user_id_int = int(self.id)
        viewer_id = info.context.get("user_id")
        return await gql_resolvers.get_user_events_resolver(info, user_id_int, limit, offset, requesting_viewer_id=viewer_id)


# --- Community Type ---
@strawberry.type
class CommunityType:
    """Represents a community."""
    id: strawberry.ID
    name: str
    description: Optional[str] = None
    created_by_id: int = strawberry.field(name="creatorId", description="ID of the user who created the community.")
    created_at: datetime
    primary_location: Optional[LocationType] = None
    interest: Optional[str] = None
    logo_url: Optional[str] = strawberry.field(description="URL to the community logo (may expire).")
    member_count: int = 0
    online_count: int = 0 # Needs implementation if desired
    is_member_by_viewer: Optional[bool] = strawberry.field(description="Does the current viewer belong to this community? (null if not logged in)")

    @strawberry.field
    async def creator(self, info: strawberry.Info) -> Optional["UserType"]:
        """Fetches the user who created this community."""
        from . import gql_resolvers # Delayed import
        viewer_id = info.context.get("user_id") # Pass viewer for follow status check
        return await gql_resolvers.get_user_resolver(info, strawberry.ID(str(self.created_by_id)), viewer_id_if_different=viewer_id)

    @strawberry.field
    async def posts(self, info: strawberry.Info, limit: int = 10, offset: int = 0) -> List["PostType"]:
        """Fetches posts belonging to this community."""
        from . import gql_resolvers # Delayed import
        community_id_int = int(self.id)
        viewer_id = info.context.get("user_id")
        return await gql_resolvers.get_posts_resolver(info, community_id=community_id_int, limit=limit, offset=offset, viewer_id_if_different=viewer_id)

    @strawberry.field
    async def members(self, info: strawberry.Info, limit: int = 10, offset: int = 0) -> List["UserType"]:
        """Fetches members of this community."""
        from . import gql_resolvers # Delayed import
        community_id_int = int(self.id)
        viewer_id = info.context.get("user_id")
        return await gql_resolvers.get_community_members_resolver(info, community_id_int, limit, offset, requesting_viewer_id=viewer_id)

    @strawberry.field
    async def events(self, info: strawberry.Info, limit: int = 10, offset: int = 0) -> List["EventType"]:
        """Fetches events belonging to this community."""
        from . import gql_resolvers # Delayed import
        community_id_int = int(self.id)
        viewer_id = info.context.get("user_id")
        return await gql_resolvers.get_community_events_resolver(info, community_id_int, limit, offset, requesting_viewer_id=viewer_id)

# --- Post Type ---
@strawberry.type
class PostType:
    """Represents a post."""
    id: strawberry.ID
    title: str
    content: str
    created_at: datetime
    image_url: Optional[str] = None
    author: Optional["UserType"] = strawberry.field(description="The user who created the post.")
    community: Optional["CommunityType"] = strawberry.field(description="The community this post belongs to, if any.")
    reply_count: int = 0
    upvotes: int = 0
    downvotes: int = 0
    favorite_count: int = 0
    viewer_vote_type: Optional[str] = strawberry.field(description="Viewer's vote ('UP', 'DOWN', or null).")
    viewer_has_favorited: Optional[bool] = strawberry.field(description="Has the viewer favorited this post?")
    media: Optional[List["MediaItemDisplay"]] = strawberry.field(default_factory=list)

    @strawberry.field
    async def replies(self, info: strawberry.Info, limit: int = 10, offset: int = 0) -> List["ReplyType"]:
        """Fetches replies to this post."""
        from . import gql_resolvers # Delayed import
        post_id_int = int(self.id)
        viewer_id = info.context.get("user_id")
        # Note: get_replies_resolver needs limit/offset support
        return await gql_resolvers.get_replies_resolver(info, post_id_int, limit=limit, offset=offset, viewer_id_if_different=viewer_id)

# --- Reply Type ---
@strawberry.type
class ReplyType:
    """Represents a reply to a post or another reply."""
    id: strawberry.ID
    content: str
    created_at: datetime
    author: Optional["UserType"] = strawberry.field(description="The user who created the reply.")
    post_id: int = strawberry.field(description="ID of the top-level post this reply belongs to.")
    parent_reply_id: Optional[int] = strawberry.field(description="ID of the parent reply, if this is a nested reply.")
    upvotes: int = 0
    downvotes: int = 0
    favorite_count: int = 0
    viewer_vote_type: Optional[str] = strawberry.field(description="Viewer's vote ('UP', 'DOWN', or null).")
    viewer_has_favorited: Optional[bool] = strawberry.field(description="Has the viewer favorited this reply?")

    @strawberry.field
    async def parent_reply(self, info: strawberry.Info) -> Optional["ReplyType"]:
        """Fetches the parent reply, if one exists."""
        from . import gql_resolvers # Delayed import
        if self.parent_reply_id is None: return None
        viewer_id = info.context.get("user_id")
        return await gql_resolvers.get_reply_resolver(info, strawberry.ID(str(self.parent_reply_id)), viewer_id_if_different=viewer_id)

    # Optional: Fetch direct children replies
    # @strawberry.field
    # async def replies(self, info: strawberry.Info, limit: int = 5, offset: int = 0) -> List["ReplyType"]:
    #    """Fetches direct replies to THIS reply."""
    #    # Need a resolver that filters replies by parent_reply_id = self.id
    #    pass

# --- Event Type ---
@strawberry.type
class EventType:
    """Represents an event within a community."""
    id: strawberry.ID
    title: str
    description: Optional[str] = None
    location: str
    event_timestamp: datetime
    max_participants: int
    image_url: Optional[str] = None
    created_at: datetime
    creator_id: int
    community_id: int
    participant_count: int = 0
    is_participating_by_viewer: Optional[bool] = strawberry.field(description="Is the current viewer participating in this event?")

    @strawberry.field
    async def creator(self, info: strawberry.Info) -> Optional["UserType"]:
        """Fetches the user who created this event."""
        from . import gql_resolvers
        viewer_id = info.context.get("user_id")
        return await gql_resolvers.get_user_resolver(info, strawberry.ID(str(self.creator_id)), viewer_id_if_different=viewer_id)

    @strawberry.field
    async def community(self, info: strawberry.Info) -> Optional["CommunityType"]:
        """Fetches the community this event belongs to."""
        from . import gql_resolvers
        viewer_id = info.context.get("user_id")
        return await gql_resolvers.get_community_resolver(info, strawberry.ID(str(self.community_id)), requesting_viewer_id=viewer_id)

    @strawberry.field
    async def participants(self, info: strawberry.Info, limit: int = 10, offset: int = 0) -> List["UserType"]:
        """Fetches users participating in this event."""
        from . import gql_resolvers
        event_id_int = int(self.id)
        viewer_id = info.context.get("user_id")
        # Need a resolver: get_event_participants_resolver
        return await gql_resolvers.get_event_participants_resolver(info, event_id_int, limit, offset, requesting_viewer_id=viewer_id)


# --- Define Forward References AFTER all types are defined ---
# This tells Strawberry how to handle types that refer to each other.
# Example for UserType fields referencing other types:
UserType.__strawberry_definition__.get_field("posts").type = List[PostType]
UserType.__strawberry_definition__.get_field("communities").type = List[CommunityType]
UserType.__strawberry_definition__.get_field("events").type = List[EventType]

# Example for CommunityType fields referencing other types:
CommunityType.__strawberry_definition__.get_field("creator").type = Optional[UserType]
CommunityType.__strawberry_definition__.get_field("posts").type = List[PostType]
CommunityType.__strawberry_definition__.get_field("members").type = List[UserType]
CommunityType.__strawberry_definition__.get_field("events").type = List[EventType]

# Example for PostType fields referencing other types:
PostType.__strawberry_definition__.get_field("author").type = Optional[UserType]
PostType.__strawberry_definition__.get_field("community").type = Optional[CommunityType]
PostType.__strawberry_definition__.get_field("replies").type = List[ReplyType]
PostType.__strawberry_definition__.get_field("media").type = Optional[List[MediaItemDisplay]]

# Example for ReplyType fields referencing other types:
ReplyType.__strawberry_definition__.get_field("author").type = Optional[UserType]
ReplyType.__strawberry_definition__.get_field("parent_reply").type = Optional[ReplyType]
# ReplyType.__strawberry_definition__.get_field("replies").type = List[ReplyType] # If you added this field

# Example for EventType fields referencing other types:
EventType.__strawberry_definition__.get_field("creator").type = Optional[UserType]
EventType.__strawberry_definition__.get_field("community").type = Optional[CommunityType]
EventType.__strawberry_definition__.get_field("participants").type = List[UserType]
