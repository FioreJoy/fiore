# backend/src/server.py
import os
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import strawberry
from strawberry.fastapi import GraphQLRouter
import socketio
import traceback
from pathlib import Path # For .env loading from project root in socketio_manager

from .routers import (
    auth as auth_router, posts as posts_router, communities as communities_router,
    replies as replies_router, votes as votes_router, events as events_router,
    chat as chat_router, users as users_router,
    settings as settings_router, block as block_router, search as search_router,
    feed as feed_router, notifications as notifications_router
)
from .graphql.schema import schema as gql_schema
from .graphql.context import get_graphql_context
from . import security
from . import auth as base_auth_module

# CORRECTED Import: Import the correctly named init_socketio_app
from .socketio_manager import init_socketio_app

load_dotenv()

fastapi_main_app = FastAPI(title="Fiore API - REST/GraphQL")

# CORS Configuration
# Construct path to .env relative to this file (src/server.py) -> backend/.env
# This is if individual modules also need to load_dotenv themselves.
# Central loading in server.py usually suffices if other modules use os.getenv directly.
project_root_for_env = Path(__file__).resolve().parent.parent
dotenv_path_server = project_root_for_env / '.env'
if dotenv_path_server.exists():
    print(f"Server.py: Loading .env from {dotenv_path_server}")
    load_dotenv(dotenv_path=dotenv_path_server)
else:
    print(f"Server.py WARN: .env file not found at {dotenv_path_server}. Relying on existing env.")


# Using SIO_CORS_ALLOWED_ORIGINS now for consistency with socketio_manager.py
# Defaulting to '*' if not set, but specific list is better.
SIO_CORS_ALLOWED_ORIGINS_STR = os.getenv("SIO_CORS_ALLOWED_ORIGINS",
                                         "http://localhost:9339,http://127.0.0.1:9339,https://fiorejoy.github.io" # Sensible defaults
                                         )
origins_list = [origin.strip() for origin in SIO_CORS_ALLOWED_ORIGINS_STR.split(',') if origin.strip()]
if not origins_list: origins_list = ["*"] # Fallback to allow all if empty after split

# Add Codespaces/Gitpod dynamic origins if applicable (more robustly)
codespaces_host = os.getenv("CODESPACE_NAME")
gitpod_url = os.getenv("GITPOD_WORKSPACE_URL")

if codespaces_host:
    for port in ["9339", "1163", "80", "443"]: # Add common dev ports
        origin = f"https://{codespaces_host}-{port}.app.github.dev"
        if origin not in origins_list: origins_list.append(origin)
elif gitpod_url:
    #GITPOD_WORKSPACE_URL is like https://myorg-myrepo-gibberish.ws-region.gitpod.io
    #Extract host and add relevant ports
    try:
        from urllib.parse import urlparse # Standard library
        parsed_gitpod_uri = urlparse(gitpod_url)
        gitpod_hostname = parsed_gitpod_uri.hostname
        if gitpod_hostname:
            # For the main app (served by Gitpod)
            if f"https://{gitpod_hostname}" not in origins_list: origins_list.append(f"https://{gitpod_hostname}")
            # For services running on specific ports forwarded by Gitpod
            for port in ["9339", "1163"]:
                origin = f"https://{port}-{gitpod_hostname}"
                if origin not in origins_list: origins_list.append(origin)
    except ImportError: # urllib.parse is standard, should not fail
        print("Server.py WARN: urllib.parse not available for Gitpod URL processing.")
    except Exception as e:
        print(f"Server.py WARN: Error processing GITPOD_WORKSPACE_URL for CORS: {e}")

print(f"Server: Final Allowed CORS origins for FastAPI & Socket.IO (via SIO_CORS_ALLOWED_ORIGINS): {origins_list}")

fastapi_main_app.add_middleware(
    CORSMiddleware, allow_origins=origins_list, allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

# Initialize Socket.IO by calling the correctly named function from socketio_manager
# This call will:
# 1. Create and assign the global 'sio' instance within socketio_manager.py
# 2. Register event handlers from socketio_handlers.py onto that 'sio' instance.
# 3. Return the combined ASGI app (FastAPI wrapped by Socket.IO).
app = init_socketio_app(fastapi_main_app)


# Check if the global SIO instance in socketio_manager was indeed set
from .socketio_manager import sio as sio_check_instance # Changed name to sio_check_instance
if sio_check_instance is None:
    print("SERVER.PY CRITICAL ERROR: socketio_manager.sio is still None after init_socketio_app call!")
else:
    print(f"SERVER.PY INFO: socketio_manager.sio (instance: {id(sio_check_instance)}) appears initialized.")


# Mount REST Routers onto fastapi_main_app
api_key_dependency = Depends(security.get_api_key)
auth_dependency = Depends(base_auth_module.get_current_user)
common_auth_dependencies = [api_key_dependency, auth_dependency]

# Assuming prefixes are defined within the router files. If not, add prefix="X" here.
fastapi_main_app.include_router(auth_router.router, tags=["Authentication"])
fastapi_main_app.include_router(users_router.router, dependencies=[api_key_dependency])
fastapi_main_app.include_router(communities_router.router, dependencies=[api_key_dependency])
fastapi_main_app.include_router(events_router.router, dependencies=[api_key_dependency])
fastapi_main_app.include_router(posts_router.router, dependencies=[api_key_dependency])
fastapi_main_app.include_router(replies_router.router, dependencies=[api_key_dependency])
fastapi_main_app.include_router(votes_router.router, dependencies=common_auth_dependencies)
fastapi_main_app.include_router(search_router.router, dependencies=[api_key_dependency])
fastapi_main_app.include_router(feed_router.router, dependencies=[api_key_dependency])
fastapi_main_app.include_router(settings_router.router, dependencies=common_auth_dependencies)
fastapi_main_app.include_router(block_router.router, dependencies=common_auth_dependencies)
fastapi_main_app.include_router(chat_router.router, dependencies=[api_key_dependency])
fastapi_main_app.include_router(notifications_router.router, dependencies=common_auth_dependencies)

graphql_app_instance = GraphQLRouter(schema=gql_schema, graphiql=True, context_getter=get_graphql_context)
fastapi_main_app.include_router(graphql_app_instance, prefix="/graphql", tags=["GraphQL"], dependencies=[api_key_dependency])

@fastapi_main_app.get("/", tags=["Root"])
async def read_root_fastapi():
    return { "message": "Fiore API (REST/GraphQL). Socket.IO handles /socket.io/" }

print("✅ FastAPI app setup complete. Wrapped by Socket.IO. Uvicorn target: 'src.server:app'.")