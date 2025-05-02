# backend/src/server.py
import os
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv

# --- ADD Strawberry Imports ---
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

# --- ADD GraphQL Schema Import ---
from .gql_schema import schema as gql_schema # Import the built schema
# --- END GQL Schema Import ---

from . import security
from . import auth
from src import utils

app = FastAPI(title="FioreJoy API")

# CORS Middleware
origins = [
    "http://localhost",
    "http://localhost:9339", # Default Flutter web port from README
    "http://127.0.0.1",
    "http://127.0.0.1:9339",
    "http://localhost:5001", # Default port for the Flask test app
    "http://100.97.215.85:5001", # Also include 127.0.0.1 version
    "http://100.94.150.11:6219",
    "http://100.94.150.11:6192",
    "https://fiorejoy.github.io",
    "http://100.97.215.85:3000",
    "http://100.94.150.11:3333",
    "https://fiorejoy.com"
    # Add your Codespace URL / Production URL if needed
    # Example: "https://*.app.github.dev" # Check specific codespace URL format
    # Example: "https://your-flutter-app.com"

]
# Allow all origins for development simplicity if needed (less secure)
# origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins, # Use the list defined above
    allow_credentials=True,
    allow_methods=["*"], # Allows all standard methods
    allow_headers=["*"], # Allows all headers
)

# --- ADD GraphQL Router ---
# Note: Authentication for GraphQL is often handled differently,
# e.g., inside resolvers checking context or using Strawberry extensions.
# Applying the JWT dependency directly here might work for basic cases
# but can interfere with tools like GraphiQL.
# Consider adding auth checks within your resolvers (`get_user`, etc.)
# or using a Strawberry permission extension.
# For now, let's add it without the JWT dependency for easier testing with GraphiQL.

# Define a context getter if your resolvers need access to request info/auth
# async def get_context(request: Request, response: Response):
#     # Example: check auth header and pass user ID
#     token = request.headers.get("Authorization")
#     user_id = None
#     if token and token.startswith("Bearer "):
#         # Decode token logic here (simplified)
#         # user_id = decode_jwt_token(token.split(" ")[1])
#         pass
#     return {"request": request, "response": response, "user_id": user_id}

graphql_app = GraphQLRouter(
    gql_schema,
    graphiql=True, # Enable GraphiQL interface at /graphql
    # context_getter=get_context # Uncomment if using context
)
app.include_router(graphql_app, prefix="/graphql")
# --- Mount Routers ---
# Prefixes are defined within each router file
# --- Include Routers ---
# Add API key dependencies selectively HERE, but NOT on the WS router!

# Auth router likely public (no API key needed for login/signup)
app.include_router(auth_router.router)

# Apply API Key + JWT Auth to routers that need it
# NOTE: If a router needs ONLY API Key and NOT JWT, adjust accordingly
common_api_dependencies = [Depends(security.get_api_key), Depends(auth.get_current_user)]

app.include_router(users_router.router, dependencies=common_api_dependencies)
app.include_router(posts_router.router, dependencies=common_api_dependencies) # Or adjust per-route
app.include_router(communities_router.router, dependencies=common_api_dependencies) # Or adjust per-route
app.include_router(replies_router.router, dependencies=common_api_dependencies) # Or adjust per-route
app.include_router(votes_router.router, dependencies=common_api_dependencies) # Or adjust per-route
app.include_router(events_router.router, dependencies=common_api_dependencies) # Or adjust per-route
app.include_router(chat_router.router, dependencies=common_api_dependencies) # Or adjust per-route

# WebSocket Router - INCLUDE WITH **NO** DEPENDENCIES HERE
app.include_router(websocket_router.router)

# --- Mount Static Files for User Images ---
# Construct the absolute path to the image directory relative to this file's location
# BASE_DIR = os.path.dirname(os.path.abspath(__file__)) # Directory containing server.py
# IMAGE_DIR_ABSOLUTE = os.path.join(BASE_DIR, utils.IMAGE_DIR) # Now points to backend/user_images
IMAGE_DIR_RELATIVE = utils.IMAGE_DIR # Path relative to where server is run (backend dir)

# Ensure the IMAGE_DIR exists relative to the backend directory
os.makedirs(IMAGE_DIR_RELATIVE, exist_ok=True)

# Serve files from the 'user_images' directory (relative to backend)
# at the '/user_images' URL path.
# Example: If an image is saved as "user_images/user_uuid.jpg",
# it will be accessible at http://<server>/user_images/user_uuid.jpg
app.mount(f"/{utils.IMAGE_DIR}", StaticFiles(directory=IMAGE_DIR_RELATIVE), name="user_images")
print(f"Serving static files from '{IMAGE_DIR_RELATIVE}' at '/{utils.IMAGE_DIR}'")

# --- Root Endpoint ---
@app.get("/")
async def read_root():
    return {"message": "FioreJoy API is running! REST at /docs, GraphQL at /graphql"}

# Note: The uvicorn command in run.sh should still target 'server:app'
# as 'server' now refers to backend/server.py
