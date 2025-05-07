# src/server.py
import os
from fastapi import FastAPI, Depends, Header, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
import jwt
from typing import Optional, Dict, Any
import strawberry
from strawberry.fastapi import GraphQLRouter
import traceback # Ensure imported

# --- Router Imports ---
from .routers import (
    auth as auth_router, posts as posts_router, communities as communities_router,
    replies as replies_router, votes as votes_router, events as events_router,
    chat as chat_router, websocket as websocket_router, users as users_router,
    settings as settings_router, block as block_router, search as search_router,
    feed as feed_router
)
# --- GraphQL Imports ---
from .graphql.schema import schema as gql_schema
from .graphql.context import get_graphql_context
# --- Other Imports ---
from . import security, utils
from . import auth as base_auth_module
from .connection_manager import manager as ws_manager

load_dotenv()
app = FastAPI(title="Fiore API")

# --- CORS ---
# ... (keep existing CORS setup) ...
origins = [
    "http://localhost", "http://localhost:3000", "http://localhost:8080",
    "http://localhost:9339", "http://127.0.0.1", "http://127.0.0.1:9339",
    "http://localhost:5001", "http://100.97.215.85:5001",
    "http://100.94.150.11:6219", "http://100.94.150.11:6192",
    "https://fiorejoy.github.io",
]
app.add_middleware(
    CORSMiddleware, allow_origins=origins, allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

# --- Mount REST Routers (REMOVED prefixes where routers define their own) ---
api_key_dependency = Depends(security.get_api_key)
auth_dependency = Depends(base_auth_module.get_current_user)
optional_auth_dependency = Depends(base_auth_module.get_current_user_optional)
common_auth_dependencies = [api_key_dependency, auth_dependency]

# --- GraphQL ---
graphql_app = GraphQLRouter(schema=gql_schema, graphiql=True, context_getter=get_graphql_context)
app.include_router(graphql_app, prefix="/graphql", tags=["GraphQL"], dependencies=[api_key_dependency]) # Keep prefix for GraphQL

app.include_router(auth_router.router, tags=["Authentication"]) # No prefix here or in router file
app.include_router(users_router.router, tags=["Users"], dependencies=[api_key_dependency]) # Prefix is defined in users_router
app.include_router(communities_router.router, tags=["Communities"], dependencies=[api_key_dependency]) # Prefix defined in router
app.include_router(events_router.router, tags=["Events"], dependencies=[api_key_dependency]) # Prefix defined in router
app.include_router(posts_router.router, tags=["Posts"], dependencies=[api_key_dependency]) # Prefix defined in router
app.include_router(replies_router.router, tags=["Replies"], dependencies=[api_key_dependency]) # Prefix defined in router
app.include_router(votes_router.router, tags=["Votes"], dependencies=common_auth_dependencies) # Prefix defined in router
app.include_router(search_router.router, tags=["Search"], dependencies=[api_key_dependency]) # Prefix defined in router
app.include_router(feed_router.router, tags=["Feeds"], dependencies=[api_key_dependency]) # Prefix defined in router
app.include_router(settings_router.router, tags=["Settings"], dependencies=common_auth_dependencies) # Prefix defined in router
app.include_router(block_router.router, tags=["Blocking"], dependencies=common_auth_dependencies) # Prefix defined in router
app.include_router(chat_router.router, tags=["Chat"], dependencies=[api_key_dependency]) # Prefix defined in router
app.include_router(websocket_router.router, tags=["WebSocket"]) # No prefix needed

# --- Root Endpoint ---
@app.get("/", tags=["Root"])
async def read_root():
    """Root endpoint providing basic API status and documentation links."""
    return { "message": "Fiore API is running!", "docs": "/docs", "redoc": "/redoc", "graphql": "/graphql"}

print("✅ FastAPI application configured.")