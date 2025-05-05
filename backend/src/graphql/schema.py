# src/graphql/schema.py
import strawberry
from typing import List, Optional

# Import Query and Mutation types from their respective resolver modules
# The types themselves (UserType, PostType etc.) are implicitly known
# by Strawberry through the return type annotations of the resolvers.
from .resolvers import Query # Import the Query class itself
from .resolvers import Mutation # Import the Mutation class itself

# --- Create the final executable schema ---
# Strawberry automatically discovers the fields defined within the
# Query and Mutation classes imported above.
schema = strawberry.Schema(
    query=Query,
    mutation=Mutation,
    # subscription=Subscription, # Add later if implementing subscriptions
)

print("✅ GraphQL Schema Assembled.")