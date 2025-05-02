# backend/src/gql_schema.py
import strawberry
from typing import Optional, List

# Import GQL Types defined in gql_types.py
# --- CORRECTED IMPORTS ---
# Use '.' to import from the same package level (src)
from .gql_types import UserType, CommunityType, PostType, ReplyType, EventType
from . import gql_resolvers
# --- END CORRECTED IMPORTS ---
@strawberry.type
class Query:
    # --- User Queries ---
    user: Optional[UserType] = strawberry.field(
        resolver=gql_resolvers.get_user,
        description="Fetch a specific user by their ID."
    )
    # Add viewer query (fetches the currently authenticated user)
    viewer: Optional[UserType] = strawberry.field(
        resolver=gql_resolvers.get_viewer, # NEW resolver needed
        description="Fetch the profile of the currently authenticated user."
    )

    # --- Post Queries ---
    posts: List[PostType] = strawberry.field(
        resolver=gql_resolvers.get_posts,
        description="Fetch a list of posts, optionally filtered by community or user."
    )
    # Optional: Query for a single post by ID
    # post: Optional[PostType] = strawberry.field(resolver=gql_resolvers.get_post_by_id)

    # --- Community Queries ---
    community: Optional[CommunityType] = strawberry.field(
        resolver=gql_resolvers.get_community,
        description="Fetch a specific community by its ID."
    )
    communities: List[CommunityType] = strawberry.field(
        resolver=gql_resolvers.get_communities, # NEW resolver needed
        description="Fetch a list of all communities."
    )
    trending_communities: List[CommunityType] = strawberry.field(
        resolver=gql_resolvers.get_trending_communities_resolver, # NEW resolver needed
        description="Fetch trending communities."
    )

    # --- Event Queries ---
    event: Optional[EventType] = strawberry.field(
        resolver=gql_resolvers.get_event, # NEW resolver needed
        description="Fetch a specific event by its ID."
    )
    # Optional: Query for events within a community (can also be a field on CommunityType)
    # community_events: List[EventType] = strawberry.field(resolver=gql_resolvers.get_community_events)

    # --- Reply Queries ---
    # Replies are often fetched as a nested field under PostType, but a direct query might be useful
    # replies_for_post: List[ReplyType] = strawberry.field(resolver=gql_resolvers.get_replies_for_post)


# --- Define Mutations (Example Structure) ---
# @strawberry.type
# class Mutation:
#     @strawberry.mutation
#     async def follow_user(self, info: strawberry.Info, user_id_to_follow: strawberry.ID) -> Optional[UserType]:
#         # Requires auth context from info
#         # Call crud.follow_user
#         # Fetch and return the *followed* user's updated profile
#         pass # Implement actual logic

#     @strawberry.mutation
#     async def unfollow_user(self, info: strawberry.Info, user_id_to_unfollow: strawberry.ID) -> Optional[UserType]:
#         # Requires auth context from info
#         # Call crud.unfollow_user
#         # Fetch and return the *unfollowed* user's updated profile
#         pass # Implement actual logic

#     @strawberry.mutation
#     async def create_post(self, info: strawberry.Info, title: str, content: str, community_id: Optional[strawberry.ID] = None) -> Optional[PostType]:
#         # Requires auth context from info
#         # Handle potential image upload (more complex with GraphQL)
#         # Call crud.create_post_db
#         # Fetch and return the created PostType
#         pass # Implement actual logic

# Add mutations for join/leave community, vote, favorite, create reply, etc.


# --- Create the final executable schema ---
schema = strawberry.Schema(
    query=Query,
    # mutation=Mutation, # Uncomment when mutations are added
    # Add extensions if needed (e.g., for performance monitoring, auth)
    # extensions=[]
)