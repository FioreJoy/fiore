# src/graphql/context.py
from typing import Optional, Dict, Any, List
from aiodataloader import DataLoader
# REMOVE Info import if no longer needed
# from strawberry.types import Info

# Import batch functions directly
from .resolvers.dataloaders import (
    batch_load_users_fn, batch_load_communities_fn, batch_load_posts_fn,
    batch_load_replies_fn, batch_load_events_fn, batch_load_media_items_fn,
    batch_load_post_media_fn, batch_load_reply_media_fn,
)
from ..connection_manager import manager as ws_manager

# --- GraphQL Context Getter ---
async def get_graphql_context() -> Dict[str, Any]:
    """ Creates the context dictionary for each GraphQL request. """
    context_data = {
        # Core Entity Loaders (Pass batch functions directly)
        "user_loader": DataLoader(batch_load_users_fn),
        "community_loader": DataLoader(batch_load_communities_fn),
        "post_loader": DataLoader(batch_load_posts_fn),
        "reply_loader": DataLoader(batch_load_replies_fn),
        "event_loader": DataLoader(batch_load_events_fn),
        # Media Loaders
        "media_loader": DataLoader(batch_load_media_items_fn),
        "post_media_loader": DataLoader(batch_load_post_media_fn),
        "reply_media_loader": DataLoader(batch_load_reply_media_fn),
        # Other Resources
        "ws_manager": ws_manager,
        "user_id": None, # Populated by auth mechanism later
    }
    print("GraphQL Context Created with DataLoaders & WS Manager")
    return context_data