# # backend/src/gql_schema.py
# import strawberry
# from typing import Optional, List
#
# # Import GQL Types defined in gql_types.py
# from .gql_types import UserType, CommunityType, PostType, ReplyType, EventType,LocationType, PostType
#
# # Import Resolvers defined in gql_resolvers.py
# from . import gql_resolvers # Import the resolvers module
#
# # --- Ensure Query fields map to existing resolvers ---
# @strawberry.type
# class Query:
#     user: Optional[UserType] = strawberry.field(
#         resolver=gql_resolvers.get_user_resolver, # Renamed resolver
#         description="Fetch a specific user by their ID."
#     )
#     viewer: Optional[UserType] = strawberry.field(
#         resolver=gql_resolvers.get_viewer, # Uses new resolver
#         description="Fetch the profile of the currently authenticated user."
#     )
#     post: Optional[PostType] = strawberry.field( # Add the singular post field
#         resolver=gql_resolvers.get_post_resolver,
#         description="Fetch a specific post by its ID."
#     )
#     posts: List[PostType] = strawberry.field(
#         resolver=gql_resolvers.get_post_resolver, # Renamed resolver
#         description="Fetch a list of posts, optionally filtered by community or user."
#     )
#     community: Optional[CommunityType] = strawberry.field(
#         resolver=gql_resolvers.get_community_resolver, # Renamed resolver
#         description="Fetch a specific community by its ID."
#     )
#     communities: List[CommunityType] = strawberry.field(
#         resolver=gql_resolvers.get_communities, # Uses new resolver
#         description="Fetch a list of all communities."
#     )
#     trending_communities: List[CommunityType] = strawberry.field(
#         resolver=gql_resolvers.get_trending_communities_resolver, # Uses new resolver
#         description="Fetch trending communities."
#     )
#     event: Optional[EventType] = strawberry.field(
#         resolver=gql_resolvers.get_event_resolver, # Renamed resolver
#         description="Fetch a specific event by its ID."
#     )
#     # Add other top-level queries if needed
#
# # --- Mutations (Keep commented out or implement later) ---
# # @strawberry.type
# # class Mutation:
# #     # ... mutation fields ...
#
# # --- Create the final executable schema ---
# schema = strawberry.Schema(
#     query=Query,
#     # mutation=Mutation,
# )