# backend/src/gql_types.py
import strawberry
from typing import List, Optional, Dict, Any # Added Any
from datetime import datetime

# Import your Pydantic schemas if needed for conversion or reference
# from . import schemas

@strawberry.type
class LocationType:
    # Matches the structure returned by utils.parse_point_string
    longitude: float
    latitude: float

@strawberry.type
class UserType:
    id: strawberry.ID # Use strawberry.ID for IDs
    name: str
    username: str
    email: str # Consider if email should be exposed in GraphQL
    gender: str
    college: Optional[str] = None
    interest: Optional[str] = None
    image_url: Optional[str] = None # Directly expose the generated URL
    current_location: Optional[LocationType] = None # Use the nested LocationType
    current_location_address: Optional[str] = None # Add the address string
    created_at: datetime
    last_seen: Optional[datetime] = None
    followers_count: int = 0 # Add follower counts
    following_count: int = 0 # Add following counts

    # Add resolvers for related fields if needed later, e.g.:
    # @strawberry.field
    # async def posts(self, info, limit: int = 10) -> List["PostType"]:
    #     # Resolver logic to fetch user's posts
    #     pass

    # You might need forward references if PostType/etc. are in the same file or defined later
    # PostType = strawberry.forward_ref(lambda: PostType)

# --- Define other types as needed (PostType, CommunityType, ReplyType, etc.) ---
# Example PostType:
# @strawberry.type
# class PostType:
#     id: strawberry.ID
#     title: str
#     content: str
#     created_at: datetime
#     author: UserType # Nested type
#     # ... other fields ...
