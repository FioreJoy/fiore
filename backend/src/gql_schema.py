# backend/src/gql_schema.py
import strawberry
from typing import Optional, List # Add List
from .gql_types import UserType # Import types
# Import other types (PostType, etc.)
from . import gql_resolvers # Import resolvers

@strawberry.type
class Query:
    # Field mapping: GQL field name -> Resolver function
    # The type hint (UserType | None) defines the return type in the GQL schema
    user: Optional[UserType] = strawberry.field(resolver=gql_resolvers.get_user)

    # Add other queries here
    # Example:
    # posts: List[PostType] = strawberry.field(resolver=gql_resolvers.get_posts)

# Define Mutation schema if needed later
# @strawberry.type
# class Mutation:
#     @strawberry.mutation
#     async def add_user(self, name: str) -> UserType:
#         # mutation logic
#         pass

# Create the final executable schema
schema = strawberry.Schema(
    query=Query,
    # mutation=Mutation # Uncomment if you add mutations
)
