# backend/src/server.py
import os
from fastapi import FastAPI, Depends, Header, Request, Response # Added Request, Response, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
import jwt # Import JWT for token decoding
from typing import Optional, Dict, Any # Added Dict, Any

# --- Strawberry Imports ---
import strawberry
from strawberry.fastapi import GraphQLRouter
# --- END Strawberry Imports ---

load_dotenv()

# --- Import routers and schemas ---
from .routers import auth as auth_router
from .routers import posts as posts_router
from .routers import communities as communities_router
from .routers import replies as replies_router
from .routers import votes as votes_router
from .routers import events as events_router
from .routers import chat as chat_router
from .routers import websocket as websocket_router
from .routers import users as users_router

# --- GraphQL Schema Import ---
from .gql_schema import schema as gql_schema

from . import security
# --- Import base auth module for SECRET_KEY etc. ---
from . import auth as base_auth_module
# --- END base auth import ---
from src import utils

app = FastAPI(title="Connections API")

# --- CORS Middleware (Keep as is) ---
origins = [
    "http://localhost", "http://localhost:9339", "http://127.0.0.1", "http://127.0.0.1:9339",
    "http://localhost:5001", "http://100.97.215.85:5001",
    "http://100.94.150.11:6219", "http://100.94.150.11:6192",
    "https://fiorejoy.github.io",
    "http://100.97.215.85:3000"
    # Add production/codespace URLs if needed
]
app.add_middleware(
    CORSMiddleware, allow_origins=origins, allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

# === NEW: GraphQL Context Getter ===
async def get_graphql_context(
        # Use Header dependency to extract Authorization directly if needed
        authorization: Optional[str] = Header(None),
        # You can also inject other dependencies if needed by resolvers
        # Example: db_conn = Depends(get_db_connection) # Not recommended, get conn inside resolver
) -> Dict[str, Any]:
    """
    Creates the context dictionary available to GraphQL resolvers via `info.context`.
    Extracts and validates the user ID from the Authorization header.
    """
    user_id: Optional[int] = None
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split("Bearer ")[1]
        try:
            payload = jwt.decode(
                token,
                base_auth_module.SECRET_KEY, # Use key from auth module
                algorithms=[base_auth_module.ALGORITHM] # Use algorithm from auth module
            )
            user_id_from_payload = payload.get("user_id")
            if user_id_from_payload:
                user_id = int(user_id_from_payload)
                print(f"GraphQL Context: Authenticated User ID = {user_id}")
                # Optionally update last_seen here (requires DB connection management)
        except jwt.ExpiredSignatureError:
            print("GraphQL Context Warning: Auth token expired.") # Don't raise, let resolver handle lack of user_id
        except (jwt.PyJWTError, ValueError):
            print("GraphQL Context Warning: Invalid auth token.") # Don't raise
        except Exception as e:
            print(f"GraphQL Context Error during token decode: {e}") # Log unexpected errors

    # Return context dict - resolvers access via info.context['user_id'] etc.
    return {
        "user_id": user_id,
        # Add other context items if needed, e.g., dependency instances
        # "db_conn": db_conn # Example if injecting DB conn (again, not recommended)
    }
# === END Context Getter ===


# --- GraphQL Router (Updated with Context Getter) ---
graphql_app = GraphQLRouter(
    gql_schema,
    graphiql=True,
    context_getter=get_graphql_context # Pass the context getter function
)
app.include_router(graphql_app, prefix="/graphql")


# --- Mount Existing REST Routers (Keep as is) ---
common_api_dependencies = [Depends(security.get_api_key), Depends(base_auth_module.get_current_user)]

app.include_router(auth_router.router)
app.include_router(users_router.router, dependencies=common_api_dependencies)
app.include_router(posts_router.router, dependencies=common_api_dependencies)
app.include_router(communities_router.router, dependencies=common_api_dependencies)
app.include_router(replies_router.router, dependencies=common_api_dependencies)
app.include_router(votes_router.router, dependencies=common_api_dependencies)
app.include_router(events_router.router, dependencies=common_api_dependencies)
app.include_router(chat_router.router, dependencies=common_api_dependencies)
app.include_router(websocket_router.router) # No dependencies needed here

# --- Mount Static Files (Keep as is) ---
IMAGE_DIR_RELATIVE = utils.IMAGE_DIR
os.makedirs(IMAGE_DIR_RELATIVE, exist_ok=True)
app.mount(f"/{utils.IMAGE_DIR}", StaticFiles(directory=IMAGE_DIR_RELATIVE), name="user_images")
print(f"Serving static files from '{IMAGE_DIR_RELATIVE}' at '/{utils.IMAGE_DIR}'")

# --- Root Endpoint (Keep as is) ---
@app.get("/")
async def read_root():
    return {"message": "Fiore API is running! REST at /docs, GraphQL at /graphql"}