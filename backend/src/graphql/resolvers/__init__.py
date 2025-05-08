# src/graphql/resolvers/__init__.py

# Export the Query class from query.py
from .query import Query

# Export the Mutation class from mutation.py
from .mutation import Mutation

# Export Dataloader batch functions if needed elsewhere (usually not)
# from .dataloaders import *

# Define public interface for 'from .resolvers import *'
__all__ = [
    "Query",
    "Mutation",
]