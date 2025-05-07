# src/graphql/context.py
from typing import Optional, Dict, Any, List
from aiodataloader import DataLoader
from fastapi import Request
import jwt
# from strawberry.types import Info

# Import batch functions directly
from .resolvers.dataloaders import (
    batch_load_users_fn, batch_load_communities_fn, batch_load_posts_fn,
    batch_load_replies_fn, batch_load_events_fn, batch_load_media_items_fn,
    batch_load_post_media_fn, batch_load_reply_media_fn,
)
from ..connection_manager import manager as ws_manager
from ..auth import SECRET_KEY, ALGORITHM
# --- GraphQL Context Getter ---
async def get_graphql_context(request: Request) -> Dict[str, Any]: # Add request: Request
    """ Creates the context dictionary, attempting to get user_id from header. """
    user_id: Optional[int] = None
    auth_header = request.headers.get("Authorization") # Get header from request
    token = None

    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split("Bearer ")[1]
        try:
            # Use imported constants
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            user_id_from_payload = payload.get("user_id")
            if user_id_from_payload:
                user_id = int(user_id_from_payload)
                print(f"GraphQL Context: Auth successful, User ID: {user_id}")
        except jwt.ExpiredSignatureError: print("GraphQL Context WARN: Token expired.")
        except (jwt.PyJWTError, ValueError): print("GraphQL Context WARN: Invalid token.")
        except Exception as e: print(f"GraphQL Context ERROR decoding token: {e}")
    else:
        print("GraphQL Context: No Authorization Bearer token found.")


    # ... (rest of context_data with DataLoader initializations) ...
    context_data = {
        "user_loader": DataLoader(batch_load_users_fn),
        "community_loader": DataLoader(batch_load_communities_fn),
        "post_loader": DataLoader(batch_load_posts_fn),
        "reply_loader": DataLoader(batch_load_replies_fn),
        "event_loader": DataLoader(batch_load_events_fn),
        "media_loader": DataLoader(batch_load_media_items_fn),
        "post_media_loader": DataLoader(batch_load_post_media_fn),
        "reply_media_loader": DataLoader(batch_load_reply_media_fn),
        "ws_manager": ws_manager,
        "user_id": user_id, # Pass the extracted user_id
    }
    print(f"GraphQL Context Created. User ID: {user_id}")
    return context_data