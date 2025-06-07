# backend/src/graphql/context.py
from typing import Optional, Dict, Any, List
from aiodataloader import DataLoader
from fastapi import Request
import jwt

from .resolvers.dataloaders import (
    batch_load_users_fn, batch_load_communities_fn, batch_load_posts_fn,
    batch_load_replies_fn, batch_load_events_fn, batch_load_media_items_fn,
    batch_load_post_media_fn, batch_load_reply_media_fn,
)
# from ..connection_manager import manager as ws_manager # REMOVED
from ..auth import SECRET_KEY, ALGORITHM # Ensure auth is imported for SECRET_KEY etc.

async def get_graphql_context(request: Request) -> Dict[str, Any]:
    user_id: Optional[int] = None
    auth_header = request.headers.get("Authorization")
    token = None

    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split("Bearer ")[1]
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM]) # Use SECRET_KEY from auth module
            user_id_from_payload = payload.get("user_id")
            if user_id_from_payload:
                user_id = int(user_id_from_payload)
        except (jwt.PyJWTError, ValueError):
            pass # Token invalid or expired, user_id remains None

    context_data = {
        "user_loader": DataLoader(batch_load_users_fn),
        "community_loader": DataLoader(batch_load_communities_fn),
        "post_loader": DataLoader(batch_load_posts_fn),
        "reply_loader": DataLoader(batch_load_replies_fn),
        "event_loader": DataLoader(batch_load_events_fn),
        "media_loader": DataLoader(batch_load_media_items_fn),
        "post_media_loader": DataLoader(batch_load_post_media_fn),
        "reply_media_loader": DataLoader(batch_load_reply_media_fn),
        # "ws_manager": ws_manager, # REMOVED
        "user_id": user_id,
        "request": request # Pass the request object if needed by resolvers
    }
    return context_data