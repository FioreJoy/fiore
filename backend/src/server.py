# backend/server.py
import os
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv # Make sure dotenv is loaded early

# Load environment variables *before* importing modules that might use them
load_dotenv()

# --- Import modules from the 'src' package ---
from .routers import auth as auth_router
from .routers import posts as posts_router
from .routers import communities as communities_router
from .routers import replies as replies_router
from .routers import votes as votes_router
from .routers import events as events_router
from .routers import chat as chat_router
from .routers import websocket as websocket_router
from .routers import users as users_router # <-- IMPORT NEW ROUTER

from . import security # <-- Import your security module
from . import auth # <--- ADD THIS IMPORT

from src import utils # To access IMAGE_DIR from src/utils.py
# --- End src imports ---

app = FastAPI(
    title="Connections API"
)

# CORS Middleware
origins = [
    "http://localhost",
    "http://localhost:9339", # Default Flutter web port from README
    "http://127.0.0.1",
    "http://127.0.0.1:9339",
    "http://localhost:5001", # Default port for the Flask test app
    "http://100.97.215.85:5001", # Also include 127.0.0.1 version
    "http://100.94.150.11:6219",
    "http://100.94.150.11:6192"
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
    """Root endpoint for health check."""
    return {"message": "Connections API is running!"}

# Note: The uvicorn command in run.sh should still target 'server:app'
# as 'server' now refers to backend/server.py
