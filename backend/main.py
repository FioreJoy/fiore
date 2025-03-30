import os
import json # Add this import
from fastapi import (
    FastAPI, Depends, HTTPException, status, Header,
    File, UploadFile, Form, WebSocket, WebSocketDisconnect
)
from fastapi.middleware.cors import CORSMiddleware
import base64
import shutil
import uuid
from PIL import Image
import io
from pydantic import BaseModel, Base64Str, Field
from typing import List, Optional, Dict
import psycopg2.extras
import psycopg2 # Add this import
import bcrypt
from jwt import encode, decode, ExpiredSignatureError, InvalidTokenError
from datetime import datetime, timedelta, timezone # Added timezone
from database import get_db_connection, update_last_seen # Import update_last_seen
from connection_manager import manager # Import the WebSocket manager


app = FastAPI()
# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SECRET_KEY = os.getenv("JWT_SECRET", "your_default_secret_key_here_please_change") # CHANGE THIS
ALGORITHM = "HS256"
ONLINE_THRESHOLD_MINUTES = 5 # Users seen in last 5 mins are "online"

def create_token(user_id: int):
    # Use UTC for expiration to avoid timezone issues
    expiration = datetime.now(timezone.utc) + timedelta(hours=1)
    return encode({"user_id": user_id, "exp": expiration}, SECRET_KEY, algorithm=ALGORITHM)

# Middleware to extract user from Bearer token
async def get_current_user(authorization: str = Header(...)):
    print(f"🔍 Authorization header received.") # Keep this minimal in production

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token format")

    token = authorization.split("Bearer ")[1]

    try:
        # Decode requires algorithms parameter
        decoded = decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = int(decoded["user_id"]) # Ensure it's an integer
        print(f"✅ Decoded Token for User ID: {user_id}") # Debugging

        # --- Update last_seen asynchronously ---
        # Use asyncio.create_task if running in async context, otherwise thread
        # For simplicity here, calling directly (might block slightly)
        # In a production app, use background tasks: from fastapi import BackgroundTasks
        update_last_seen(user_id) # Update the timestamp

        return user_id
    except ExpiredSignatureError:
        print("⏳ Token expired") # Debugging
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except InvalidTokenError as e:
        print(f"❌ Invalid Token: {e}") # Debugging
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid token: {e}")
    except Exception as e:
        print(f"❌ Unexpected error during token validation: {e}")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Could not validate credentials")


# ------------------
# Models
# ------------------
class LoginRequest(BaseModel):
    email: str
    password: str

class SignupRequest(BaseModel):
    name: str
    username: str
    email: str
    password: str
    gender: str
    current_location: str = "(0,0)" # Consider sending lat/lon separately
    college: str
    interests: List[str] = []
    image: Optional[Base64Str] = None # using Base64 for simplicity

class PostCreate(BaseModel):
    title: str
    content: str
    community_id: Optional[int] = None # Make optional

class CommunityCreate(BaseModel):
    name: str
    description: Optional[str] = None
    primary_location: str # Representing POINT as a string "(lat,lon)" -> Needs parsing
    interest: Optional[str] = None # Added interest

class CommunityDetails(BaseModel): # New model for community details
    id: int
    name: str
    description: Optional[str] = None
    created_by: int
    created_at: datetime
    primary_location: str # Keep as string for now, parsing needed if used
    interest: Optional[str] = None
    member_count: int
    online_count: int # Added online count

class VoteCreate(BaseModel):
    post_id: Optional[int] = None
    reply_id: Optional[int] = None
    vote_type: bool # True for upvote, False for downvote

    # Add validation: Ensure only one of post_id or reply_id is set
    # Pydantic validators can be used here if needed

class ReplyCreate(BaseModel):
    post_id: int
    content: str
    parent_reply_id: Optional[int] = None # Already optional

# Model for sending chat messages via HTTP (can be used for initial load or backup)
class ChatMessageCreate(BaseModel):
    content: str

# Model for chat message data (used in WebSocket broadcast)
class ChatMessageData(BaseModel):
    message_id: int
    community_id: Optional[int] = None
    event_id: Optional[int] = None
    user_id: int
    username: str # Include username for display
    content: str
    timestamp: datetime

class EventBase(BaseModel):
    title: str = Field(..., min_length=3, max_length=255)
    description: Optional[str] = None
    location: str = Field(..., min_length=3)
    event_timestamp: datetime # Expect ISO 8601 format string from frontend
    max_participants: int = Field(gt=0, default=100) # Must be > 0
    image_url: Optional[str] = None

class EventCreate(EventBase):
    pass # Inherits all fields from EventBase

class EventUpdate(EventBase):
    # All fields optional for partial updates
    title: Optional[str] = Field(None, min_length=3, max_length=255)
    description: Optional[str] = None
    location: Optional[str] = Field(None, min_length=3)
    event_timestamp: Optional[datetime] = None
    max_participants: Optional[int] = Field(None, gt=0)
    image_url: Optional[str] = None

class EventDetails(EventBase):
    id: int
    community_id: int
    creator_id: int
    created_at: datetime
    participant_count: int = 0 # Add participant count
# ------------------
# Auth Endpoints
# ------------------
# --- Helper Functions ---
IMAGE_DIR = "user_images" # Define image directory constant

def save_image_from_base64(base64_string: str, username: str) -> Optional[str]:
    """Decodes a Base64 string, saves it as an image, and returns the file path."""
    if not base64_string:
        return None
    try:
        # Ensure the string is pure Base64 data without prefixes like "data:image/jpeg;base64,"
        if ',' in base64_string:
             base64_string = base64_string.split(',')[1]

        image_data = base64.b64decode(base64_string)
        image = Image.open(io.BytesIO(image_data))

        # Create the directory if it doesn't exist
        os.makedirs(IMAGE_DIR, exist_ok=True)

        file_extension = image.format.lower() if image.format else 'jpeg' # Default extension
        filename = f"{username}_{uuid.uuid4()}.{file_extension}"
        file_path = os.path.join(IMAGE_DIR, filename)
        image.save(file_path)
        print(f"Image saved via base64: {file_path}")
        return file_path
    except Exception as e:
        print(f"Error saving base64 image: {e}")
        # Don't raise HTTPException here, allow signup to proceed without image if saving fails
        return None


async def save_image_multipart(image: UploadFile, username: str) -> Optional[str]:
    """Saves an uploaded image and returns the file path."""
    if not image or not image.filename:
        return None
    try:
        # Create the directory if it doesn't exist
        os.makedirs(IMAGE_DIR, exist_ok=True)

        # Sanitize filename and create unique name
        file_extension = image.filename.split(".")[-1].lower()
        if not file_extension: file_extension = 'jpeg' # Default
        filename = f"{username}_{uuid.uuid4()}.{file_extension}"
        file_path = os.path.join(IMAGE_DIR, filename)

        # Use shutil for efficient saving
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(image.file, buffer)
        print(f"Image saved via multipart: {file_path}")
        return file_path
    except Exception as e:
        print(f"Error saving multipart image: {e}")
        return None
    finally:
        await image.close() # Ensure file is closed

# Base64 approach - Kept for potential alternative use, but recommend multipart
@app.post("/signup_base64")
async def signup_base64(request: SignupRequest):
    print(f"🔹 Signup Request (Base64): {request.username}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    hashed_password = bcrypt.hashpw(request.password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    image_path = None
    try:
        # --- Handle Image (Base64) ---
        if request.image:
            image_path = save_image_from_base64(request.image, request.username)

        # Adjust location parsing if needed, currently expects string like 'POINT(lon lat)'
        # Convert interests list to string or use JSONB/Array type in DB
        interests_str = ",".join(request.interests) if request.interests else None

        cursor.execute(
            """
            INSERT INTO users (name, username, email, password_hash, gender, current_location, college, interest, image_path)
            VALUES (%s, %s, %s, %s, %s, %s::point, %s, %s, %s) RETURNING id;
            """,
            (request.name, request.username, request.email, hashed_password, request.gender,
             request.current_location, request.college, interests_str, image_path)
        )
        user_result = cursor.fetchone()
        if not user_result:
             raise HTTPException(status_code=500, detail="User creation failed")
        user_id = user_result["id"]
        conn.commit()
        print(f"✅ User created with ID: {user_id} and image path: {image_path}")

    except psycopg2.IntegrityError as e:
         conn.rollback()
         print(f"❌ Signup Error (Integrity): {e}")
         detail = "Username or email already exists."
         # You could parse e.pgerror for more specific details if needed
         raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except Exception as e:
        conn.rollback()
        print(f"❌ Signup Error: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

    token = create_token(user_id)
    return {
      "message": "User signed up successfully",
      "user_id": user_id,
      "image_path": image_path, # Include image path in the response
      "token": token # Return token immediately on signup
    }


# Multipart/form-data approach (Recommended)
@app.post("/signup")
async def signup(
    name: str = Form(...),
    username: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    gender: str = Form(...),
    current_location: str = Form("(0,0)"), # Default, frontend should send POINT string '(lon,lat)'
    college: str = Form(...),
    interests: List[str] = Form(...),
    image: Optional[UploadFile] = File(None) # Make image optional
):
    print(f"🔹 Signup Request (Multipart): {username}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    image_path = None
    try:
        # --- Handle Image (Multipart) ---
        if image:
            image_path = await save_image_multipart(image, username)

        # Convert interests list to string for TEXT column (or use Array/JSONB)
        interests_str = ",".join(interests) if interests else None

        cursor.execute(
            """
            INSERT INTO users (name, username, email, password_hash, gender, current_location, college, interest, image_path)
            VALUES (%s, %s, %s, %s, %s, %s::point, %s, %s, %s) RETURNING id;
            """,
            (name, username, email, hashed_password, gender, current_location, college, interests_str, image_path)
        )
        user_result = cursor.fetchone()
        if not user_result:
            raise HTTPException(status_code=500, detail="User creation failed")
        user_id = user_result["id"]
        conn.commit()
        print(f"✅ User created with ID: {user_id} and image path: {image_path}")

    except psycopg2.IntegrityError as e:
        conn.rollback()
        print(f"❌ Signup Error (Integrity): {e}")
        detail = "Username or email already exists."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except Exception as e:
        conn.rollback()
        print(f"❌ Signup Error: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

    token = create_token(user_id)
    return {
      "message": "User signed up successfully",
      "user_id": user_id,
      "image_path": image_path, # Include image path in response
      "token": token # Return token immediately
    }

@app.post("/login")
def login(request: LoginRequest):
    print(f"🔹 Login Request: {request.email}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute("SELECT id, password_hash FROM users WHERE email = %s", (request.email,))
    user = cursor.fetchone()
    conn.close()

    if not user:
        print("⚠️ User not found")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if not bcrypt.checkpw(request.password.encode('utf-8'), user["password_hash"].encode('utf-8')):
        print("⚠️ Incorrect password")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    token = create_token(user["id"])
    # Update last_seen on successful login
    update_last_seen(user["id"])
    print(f"✅ Token generated for user {user['id']}")
    return {"token": token, "user_id": user["id"]}

@app.get("/me")
async def get_me(user_id: int = Depends(get_current_user)):
    print(f"🔹 Fetching user data for: {user_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    # Ensure image_path and interest columns are selected
    cursor.execute(
        """SELECT id, name, username, email, gender, image_path,
                  current_location, college, interest, created_at, last_seen
           FROM users WHERE id = %s;""",
        (user_id,)
    )
    user = cursor.fetchone()
    conn.close()
    if user:
        # Convert POINT to a more usable format if needed, e.g., dict or list
        if user.get('current_location'):
            # Assuming POINT format is '(lon,lat)' or similar psycopg2 object
            # This might need adjustment based on actual return type
             try:
                 # If it's a string like '(10.5,20.1)'
                 loc_str = str(user['current_location']).strip('()')
                 lon, lat = map(float, loc_str.split(','))
                 user['current_location'] = {'longitude': lon, 'latitude': lat}
             except Exception:
                 print("Warning: Could not parse current_location format")
                 # Keep original or set to None/default

        # Split interests string back into list
        if user.get('interest'):
            user['interests'] = user['interest'].split(',')
        else:
            user['interests'] = []

        print(f"✅ User found: {user['username']}")
        return user
    else:
        print("❌ User not found")
        raise HTTPException(status_code=404, detail="User not found")

# ------------------------
# Post Endpoints
# ------------------------

@app.post("/posts", status_code=status.HTTP_201_CREATED)
def create_post(post_data: PostCreate, user_id: int = Depends(get_current_user)):
    print(f"🔹 Creating post by user: {user_id}, Data: {post_data}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    try:
        # Insert the post
        cursor.execute(
            "INSERT INTO posts (user_id, content, title) VALUES (%s, %s, %s) RETURNING id;",
            (user_id, post_data.content, post_data.title),
        )
        post_result = cursor.fetchone()
        if not post_result:
            raise HTTPException(status_code=500, detail="Post creation failed: No ID returned")
        post_id = post_result["id"]

        # If community_id is provided, link the post to the community
        if post_data.community_id is not None:
             cursor.execute(
                """
                INSERT INTO community_posts (community_id, post_id)
                VALUES (%s, %s)
                ON CONFLICT (community_id, post_id) DO NOTHING;
                """,
                (post_data.community_id, post_id)
            )

        conn.commit()
        print(f"✅ Post created with ID: {post_id}, linked to community: {post_data.community_id}")
        # Fetch the created post details to return
        cursor.execute("SELECT * FROM posts WHERE id = %s", (post_id,))
        created_post = cursor.fetchone()
        return created_post

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ SQL Error creating post: {e.pgcode} - {e.pgerror}")
        raise HTTPException(status_code=400, detail=f"Database error: {e.pgerror}")
    except Exception as e:
        conn.rollback()
        print(f"❌ Unexpected Error creating post: {repr(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/posts")
def get_posts(community_id: Optional[int] = None, user_id: Optional[int] = None):
    print(f"🔹 Fetching posts. Community filter: {community_id}, User filter: {user_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # Base query
    query = """
        SELECT
            p.id, p.user_id, p.content, p.title, p.created_at,
            u.username AS author_name,
            u.image_path AS author_avatar,
            COALESCE(v_counts.upvotes, 0) AS upvotes,
            COALESCE(v_counts.downvotes, 0) AS downvotes,
            COALESCE(r_counts.reply_count, 0) AS reply_count,
            c.id as community_id,  -- Include community ID
            c.name as community_name -- Include community name
        FROM posts p
        JOIN users u ON p.user_id = u.id
        LEFT JOIN community_posts cp ON p.id = cp.post_id -- Join to get community info
        LEFT JOIN communities c ON cp.community_id = c.id -- Join to get community name
        LEFT JOIN (
            SELECT post_id,
                   COUNT(*) FILTER (WHERE vote_type = TRUE) AS upvotes,
                   COUNT(*) FILTER (WHERE vote_type = FALSE) AS downvotes
            FROM votes
            WHERE post_id IS NOT NULL
            GROUP BY post_id
        ) AS v_counts ON p.id = v_counts.post_id
        LEFT JOIN (
            SELECT post_id, COUNT(*) AS reply_count
            FROM replies
            GROUP BY post_id
        ) AS r_counts ON p.id = r_counts.post_id
    """
    params = []
    filters = []

    if community_id is not None:
        filters.append("cp.community_id = %s")
        params.append(community_id)
    if user_id is not None:
        filters.append("p.user_id = %s")
        params.append(user_id)

    if filters:
        query += " WHERE " + " AND ".join(filters)

    query += " ORDER BY p.created_at DESC;"

    try:
        cursor.execute(query, tuple(params))
        posts = cursor.fetchall()
        print(f"✅ Fetched {len(posts)} posts")
        return {"posts": posts}
    except Exception as e:
        print(f"❌ Error fetching posts: {e}")
        raise HTTPException(status_code=500, detail="Error fetching posts")
    finally:
        cursor.close()
        conn.close()


@app.get("/posts/trending")
def get_trending_posts():
    print("🔹 Fetching trending posts")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # Simple trending: posts with most votes + replies in the last 48 hours
    query = """
        SELECT
            p.id, p.user_id, p.content, p.title, p.created_at,
            u.username AS author_name,
            u.image_path AS author_avatar,
            c.id as community_id,
            c.name as community_name,
            (COALESCE(recent_votes.count, 0) + COALESCE(recent_replies.count, 0)) AS recent_activity_score
        FROM posts p
        JOIN users u ON p.user_id = u.id
        LEFT JOIN community_posts cp ON p.id = cp.post_id
        LEFT JOIN communities c ON cp.community_id = c.id
        LEFT JOIN (
            SELECT post_id, COUNT(*) as count
            FROM votes
            WHERE created_at >= NOW() - INTERVAL '48 hours' AND post_id IS NOT NULL
            GROUP BY post_id
        ) AS recent_votes ON p.id = recent_votes.post_id
        LEFT JOIN (
            SELECT post_id, COUNT(*) as count
            FROM replies
            WHERE created_at >= NOW() - INTERVAL '48 hours'
            GROUP BY post_id
        ) AS recent_replies ON p.id = recent_replies.post_id
        WHERE p.created_at >= NOW() - INTERVAL '7 days' -- Consider posts from last week
        ORDER BY recent_activity_score DESC, p.created_at DESC
        LIMIT 20; -- Limit to top 20 trending
    """
    try:
        cursor.execute(query)
        posts = cursor.fetchall()
         # Add vote counts and reply counts separately if needed for display consistency
        # (This is less efficient but matches the structure of /posts)
        post_ids = [post['id'] for post in posts]
        if post_ids:
             cursor.execute("""
                SELECT post_id,
                    COUNT(*) FILTER (WHERE vote_type = TRUE) AS upvotes,
                    COUNT(*) FILTER (WHERE vote_type = FALSE) AS downvotes
                FROM votes WHERE post_id = ANY(%s) GROUP BY post_id
            """, (post_ids,))
             vote_counts = {row['post_id']: row for row in cursor.fetchall()}

             cursor.execute("""
                SELECT post_id, COUNT(*) AS reply_count
                FROM replies WHERE post_id = ANY(%s) GROUP BY post_id
            """, (post_ids,))
             reply_counts = {row['post_id']: row['reply_count'] for row in cursor.fetchall()}

             for post in posts:
                 post['upvotes'] = vote_counts.get(post['id'], {}).get('upvotes', 0)
                 post['downvotes'] = vote_counts.get(post['id'], {}).get('downvotes', 0)
                 post['reply_count'] = reply_counts.get(post['id'], 0)

        print(f"✅ Fetched {len(posts)} trending posts")
        return {"posts": posts}
    except Exception as e:
        print(f"❌ Error fetching trending posts: {e}")
        raise HTTPException(status_code=500, detail="Error fetching trending posts")
    finally:
        cursor.close()
        conn.close()


@app.delete("/posts/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_post(post_id: int, user_id: int = Depends(get_current_user)):
    print(f"🔹 Deleting post ID: {post_id} by user: {user_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    try:
        # Check if the post exists and belongs to the current user
        cursor.execute("SELECT user_id FROM posts WHERE id = %s;", (post_id,))
        post = cursor.fetchone()

        if not post:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")

        if post["user_id"] != user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Unauthorized: You can only delete your own posts")

        # Delete the post (cascades should handle related replies, votes etc.)
        cursor.execute("DELETE FROM posts WHERE id = %s;", (post_id,))
        conn.commit()
        print(f"✅ Post {post_id} deleted successfully")

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ SQL Error deleting post: {e.pgcode} - {e.pgerror}")
        raise HTTPException(status_code=400, detail=f"Database error: {e.pgerror}")
    except HTTPException as he:
         conn.rollback() # Rollback even for HTTP exceptions if needed
         raise he # Re-raise the HTTP exception
    except Exception as e:
        conn.rollback()
        print(f"❌ Unexpected Error deleting post: {repr(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

    return # Return No Content


# ------------------------
# Community Endpoints
# ------------------------

@app.post("/communities", status_code=status.HTTP_201_CREATED)
def create_community(community_data: CommunityCreate, user_id: int = Depends(get_current_user)):
    print(f"🔹 Creating community by user: {user_id}, Data: {community_data}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    try:
        # Assuming primary_location format "(lon,lat)" - needs conversion to POINT
        # Consider sending lat/lon separately from frontend for easier handling
        # Example parsing (adjust if format differs):
        # loc_str = community_data.primary_location.strip('()')
        # lon, lat = map(float, loc_str.split(','))
        # location_point = f"POINT({lon} {lat})" # Adjust syntax if needed for DB

        cursor.execute(
            """
            INSERT INTO communities (name, description, created_by, primary_location, interest)
            VALUES (%s, %s, %s, %s::point, %s) RETURNING id;
            """,
            (community_data.name, community_data.description, user_id,
             community_data.primary_location, community_data.interest),
        )
        result = cursor.fetchone()
        if not result:
            raise HTTPException(status_code=500, detail="Community creation failed: No ID returned")

        community_id = result["id"]

        # Automatically make the creator a member
        cursor.execute(
            "INSERT INTO community_members (user_id, community_id) VALUES (%s, %s) ON CONFLICT DO NOTHING;",
            (user_id, community_id)
        )

        conn.commit()
        print(f"✅ Community created with ID: {community_id}")

        # Fetch the created community details to return
        cursor.execute("SELECT * FROM communities WHERE id = %s", (community_id,))
        created_community = cursor.fetchone()
        return created_community

    except psycopg2.IntegrityError as e:
        conn.rollback()
        print(f"❌ SQL Error (Integrity) creating community: {e}")
        # Check constraint violation or unique key violation?
        detail = "Community name might already exist or invalid data provided."
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)
    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ SQL Error creating community: {e.pgcode} - {e.pgerror}")
        raise HTTPException(status_code=400, detail=f"Database error: {e.pgerror}")
    except Exception as e:
        conn.rollback()
        print(f"❌ Unexpected Error creating community: {repr(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()


@app.get("/communities")
def get_communities():
    print("🔹 Fetching all communities")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    # Include member count
    query = """
        SELECT c.*, COUNT(cm.user_id) as member_count
        FROM communities c
        LEFT JOIN community_members cm ON c.id = cm.community_id
        GROUP BY c.id
        ORDER BY c.created_at DESC;
    """
    try:
        cursor.execute(query)
        communities = cursor.fetchall()
        # Convert POINT to string/dict if needed before returning
        for comm in communities:
             if comm.get('primary_location'):
                  comm['primary_location'] = str(comm['primary_location']) # Simple string conversion

        print(f"✅ Fetched {len(communities)} communities")
        return {"communities": communities}
    except Exception as e:
         print(f"❌ Error fetching communities: {e}")
         raise HTTPException(status_code=500, detail="Error fetching communities")
    finally:
        cursor.close()
        conn.close()


@app.get("/communities/trending")
def get_trending_communities():
    print("🔹 Fetching trending communities")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # Simple trending: communities with most new members + new posts in last 48 hours
    query = """
        SELECT
            c.id, c.name, c.description, c.interest,
            c.primary_location, -- Add other fields as needed
            (COALESCE(recent_members.count, 0) + COALESCE(recent_posts.count, 0)) AS recent_activity_score,
            total_members.count as member_count -- Also get total members
        FROM communities c
        LEFT JOIN (
            SELECT community_id, COUNT(*) as count
            FROM community_members
            WHERE joined_at >= NOW() - INTERVAL '48 hours'
            GROUP BY community_id
        ) AS recent_members ON c.id = recent_members.community_id
        LEFT JOIN (
            SELECT community_id, COUNT(*) as count
            FROM community_posts cp
            JOIN posts p ON cp.post_id = p.id
            WHERE p.created_at >= NOW() - INTERVAL '48 hours'
            GROUP BY community_id
        ) AS recent_posts ON c.id = recent_posts.community_id
        LEFT JOIN ( -- Join to get total member count
             SELECT community_id, COUNT(*) as count
             FROM community_members
             GROUP BY community_id
        ) AS total_members ON c.id = total_members.community_id
        WHERE c.created_at >= NOW() - INTERVAL '30 days' -- Consider communities created in last month
        ORDER BY recent_activity_score DESC, c.created_at DESC
        LIMIT 15; -- Limit to top 15 trending
    """
    try:
        cursor.execute(query)
        communities = cursor.fetchall()
        # Convert POINT etc. if needed
        for comm in communities:
            if comm.get('primary_location'):
                comm['primary_location'] = str(comm['primary_location'])
            if comm.get('member_count') is None: # Handle case where community has 0 members
                comm['member_count'] = 0

        print(f"✅ Fetched {len(communities)} trending communities")
        return {"communities": communities}
    except Exception as e:
        print(f"❌ Error fetching trending communities: {e}")
        raise HTTPException(status_code=500, detail="Error fetching trending communities")
    finally:
        cursor.close()
        conn.close()


@app.get("/communities/{community_id}/details", response_model=CommunityDetails)
def get_community_details(community_id: int):
    print(f"🔹 Fetching details for community: {community_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # Calculate online count based on last_seen within threshold
    online_threshold = datetime.now(timezone.utc) - timedelta(minutes=ONLINE_THRESHOLD_MINUTES)

    query = """
        SELECT
            c.*,
            COUNT(cm.user_id) AS member_count,
            COUNT(u.id) FILTER (WHERE u.last_seen >= %s) AS online_count
        FROM communities c
        LEFT JOIN community_members cm ON c.id = cm.community_id
        LEFT JOIN users u ON cm.user_id = u.id
        WHERE c.id = %s
        GROUP BY c.id;
    """
    try:
        cursor.execute(query, (online_threshold, community_id))
        community = cursor.fetchone()

        if not community:
             raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")

        # Convert POINT to string/dict if needed before returning
        if community.get('primary_location'):
            community['primary_location'] = str(community['primary_location'])

        print(f"✅ Details fetched for community {community_id}: Members={community['member_count']}, Online={community['online_count']}")
        return community

    except Exception as e:
        print(f"❌ Error fetching community details: {e}")
        raise HTTPException(status_code=500, detail="Error fetching community details")
    finally:
        cursor.close()
        conn.close()


@app.delete("/communities/{community_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_community(community_id: int, user_id: int = Depends(get_current_user)):
    print(f"🔹 Deleting community ID: {community_id} by user: {user_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    try:
        # Check ownership
        cursor.execute("SELECT created_by FROM communities WHERE id = %s;", (community_id,))
        community = cursor.fetchone()

        if not community:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Community not found")

        if community["created_by"] != user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Unauthorized to delete this community")

        # Perform deletion
        cursor.execute("DELETE FROM communities WHERE id = %s;", (community_id,))
        conn.commit()
        print(f"✅ Community {community_id} deleted successfully")

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ SQL Error deleting community: {e.pgcode} - {e.pgerror}")
        raise HTTPException(status_code=400, detail=f"Database error: {e.pgerror}")
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        print(f"❌ Unexpected Error deleting community: {repr(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()
    return # Return No Content


# ------------------------
# Vote Endpoints (Updated Logic)
# ------------------------

@app.post("/votes") # Changed status code default
def create_or_update_vote(vote_data: VoteCreate, user_id: int = Depends(get_current_user)):
    print(f"🔹 Vote received: post={vote_data.post_id} reply={vote_data.reply_id} type={vote_data.vote_type}, User: {user_id}")

    if vote_data.post_id is None and vote_data.reply_id is None:
        raise HTTPException(status_code=400, detail="Either post_id or reply_id must be provided.")
    if vote_data.post_id is not None and vote_data.reply_id is not None:
        raise HTTPException(status_code=400, detail="Cannot vote on both post_id and reply_id simultaneously.")

    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    target_column = "post_id" if vote_data.post_id else "reply_id"
    target_id = vote_data.post_id if vote_data.post_id else vote_data.reply_id

    try:
        # Check for existing vote by this user on this target
        cursor.execute(
            f"SELECT id, vote_type FROM votes WHERE user_id = %s AND {target_column} = %s;",
            (user_id, target_id)
        )
        existing_vote = cursor.fetchone()

        if existing_vote:
            # Vote exists
            existing_vote_id = existing_vote['id']
            existing_vote_type = existing_vote['vote_type']

            if existing_vote_type == vote_data.vote_type:
                # User clicked the same vote button again - Undo (Delete)
                cursor.execute("DELETE FROM votes WHERE id = %s;", (existing_vote_id,))
                conn.commit()
                print(f"✅ Vote undone (deleted) for user {user_id} on {target_column} {target_id}")
                return {"message": "Vote removed"}
            else:
                # User clicked the other vote button - Switch (Update)
                cursor.execute(
                    "UPDATE votes SET vote_type = %s, created_at = NOW() WHERE id = %s RETURNING id;",
                    (vote_data.vote_type, existing_vote_id)
                )
                conn.commit()
                print(f"✅ Vote switched for user {user_id} on {target_column} {target_id} to {vote_data.vote_type}")
                updated_vote = cursor.fetchone()
                return {"message": "Vote updated", "vote_id": updated_vote['id'], "new_vote_type": vote_data.vote_type}
        else:
            # No existing vote - Insert new vote
            cursor.execute(
                """
                INSERT INTO votes (user_id, post_id, reply_id, vote_type)
                VALUES (%s, %s, %s, %s) RETURNING id;
                """,
                (user_id, vote_data.post_id, vote_data.reply_id, vote_data.vote_type)
            )
            conn.commit()
            new_vote = cursor.fetchone()
            if not new_vote:
                 raise HTTPException(status_code=500, detail="Vote insertion failed")
            print(f"✅ New vote recorded for user {user_id} on {target_column} {target_id}, type: {vote_data.vote_type}")
            return {"message": "Vote recorded", "vote_id": new_vote['id'], "vote_type": vote_data.vote_type}

    except psycopg2.IntegrityError as e:
         # This might catch violations of the unique constraints if logic above fails
         conn.rollback()
         print(f"❌ Vote Integrity Error: {e}")
         # Check if it's the CHECK constraint (post_id IS NULL OR reply_id IS NULL)
         # Or unique constraint violation
         raise HTTPException(status_code=400, detail="Invalid vote combination or target does not exist.")
    except Exception as e:
        conn.rollback()
        print(f"❌ Vote error [{e.__class__.__name__}]: {e}")
        raise HTTPException(status_code=500, detail=f"An error occurred: {str(e)}")
    finally:
        cursor.close()
        conn.close()


@app.get("/votes") # Keep this endpoint as is for fetching vote lists if needed
def get_votes(post_id: Optional[int] = None, reply_id: Optional[int] = None):
    if not post_id and not reply_id:
        raise HTTPException(status_code=400, detail="Either post_id or reply_id must be provided.")

    print(f"🔹 Fetching votes for post_id={post_id}, reply_id={reply_id}")
    # ... (rest of the get_votes logic remains the same) ...
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        query = "SELECT id, user_id, post_id, reply_id, vote_type FROM votes WHERE "
        params = []
        if post_id:
            query += "post_id = %s "
            params.append(post_id)
        elif reply_id:
            query += "reply_id = %s "
            params.append(reply_id)
        query += "ORDER BY created_at DESC;"
        cursor.execute(query, tuple(params))
        votes = cursor.fetchall()
        print(f"✅ Fetched {len(votes)} votes")
        return {"votes": votes}
    except Exception as e:
        print(f"❌ Error fetching votes: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()


# ------------------------
# Reply Endpoints
# ------------------------

@app.post("/replies", status_code=status.HTTP_201_CREATED)
def create_reply(reply_data: ReplyCreate, user_id: int = Depends(get_current_user)):
    print(f"🔹 Creating reply by user: {user_id}, Data: {reply_data}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    try:
        # Optional: Validate parent_reply_id exists and belongs to the same post_id
        if reply_data.parent_reply_id:
            cursor.execute("SELECT post_id FROM replies WHERE id = %s", (reply_data.parent_reply_id,))
            parent = cursor.fetchone()
            if not parent:
                 raise HTTPException(status_code=400, detail="Parent reply ID does not exist.")
            if parent['post_id'] != reply_data.post_id:
                 raise HTTPException(status_code=400, detail="Parent reply belongs to a different post.")

        cursor.execute(
            """
            INSERT INTO replies (post_id, user_id, content, parent_reply_id)
            VALUES (%s, %s, %s, %s) RETURNING id;
            """,
            (reply_data.post_id, user_id, reply_data.content, reply_data.parent_reply_id)
        )
        result = cursor.fetchone()
        if not result:
            raise HTTPException(status_code=500, detail="Reply insertion failed.")

        reply_id = result["id"]
        conn.commit()
        print(f"✅ Reply created with ID: {reply_id}")

        # Fetch the created reply to return it
        cursor.execute(
            """
            SELECT r.*, u.username AS author_name, u.image_path AS author_avatar
            FROM replies r
            JOIN users u ON r.user_id = u.id
            WHERE r.id = %s
            """,
            (reply_id,)
        )
        created_reply = cursor.fetchone()
        return created_reply

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ Database Error creating reply: {e}")
        raise HTTPException(status_code=400, detail=str(e.pgerror))
    except Exception as e:
        conn.rollback()
        print(f"❌ Unexpected Error creating reply: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()


@app.get("/replies/{post_id}")
def get_replies(post_id: int):
    print(f"🔹 Fetching replies for post ID: {post_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    # Fetch replies along with author info and vote counts
    query = """
        SELECT
            r.id, r.post_id, r.user_id, r.content, r.parent_reply_id, r.created_at,
            u.username AS author_name,
            u.image_path AS author_avatar,
            COALESCE(v_counts.upvotes, 0) AS upvotes,
            COALESCE(v_counts.downvotes, 0) AS downvotes
        FROM replies r
        JOIN users u ON r.user_id = u.id
        LEFT JOIN (
            SELECT reply_id,
                   COUNT(*) FILTER (WHERE vote_type = TRUE) AS upvotes,
                   COUNT(*) FILTER (WHERE vote_type = FALSE) AS downvotes
            FROM votes
            WHERE reply_id IS NOT NULL
            GROUP BY reply_id
        ) AS v_counts ON r.id = v_counts.reply_id
        WHERE r.post_id = %s
        ORDER BY r.created_at ASC; -- Order by creation time
    """
    try:
        cursor.execute(query, (post_id,))
        replies = cursor.fetchall()
        print(f"✅ Fetched {len(replies)} replies for post {post_id}")
        # In a real app, you might want to structure this hierarchically
        # before sending, or let the frontend handle hierarchy based on parent_reply_id.
        return {"replies": replies}
    except Exception as e:
        print(f"❌ Error fetching replies: {e}")
        raise HTTPException(status_code=500, detail="Error fetching replies")
    finally:
        cursor.close()
        conn.close()


@app.delete("/replies/{reply_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_reply(reply_id: int, user_id: int = Depends(get_current_user)):
    print(f"🔹 Deleting reply ID: {reply_id} by user ID: {user_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    try:
        # Check ownership
        cursor.execute("SELECT user_id FROM replies WHERE id = %s;", (reply_id,))
        reply = cursor.fetchone()

        if not reply:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reply not found")

        if reply["user_id"] != user_id:
             raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Unauthorized to delete this reply")

        # Perform deletion (cascades should handle votes, favorites, child replies)
        cursor.execute("DELETE FROM replies WHERE id = %s;", (reply_id,))
        conn.commit()
        print(f"✅ Reply ID {reply_id} deleted successfully")

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ SQL Error deleting reply: {e.pgcode} - {e.pgerror}")
        raise HTTPException(status_code=400, detail=f"Database error: {e.pgerror}")
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        print(f"❌ Unexpected Error deleting reply: {repr(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()
    return # Return No Content


# ------------------------
# Chat Endpoints (WebSocket & HTTP)
# ------------------------

# --- WebSocket Endpoint ---
@app.websocket("/ws/{room_type}/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_type: str, room_id: int):
    # Basic Authentication (More robust needed for production: e.g., token in query param or initial message)
    # For now, let's assume connection implies some level of access, refine later.
    # user_id = await get_current_user_ws(websocket) # Needs implementation
    # if not user_id: return

    valid_room_types = ["community", "event"]
    if room_type not in valid_room_types:
        print(f"Invalid room type: {room_type}")
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    room_identifier = f"{room_type}_{room_id}"

    await manager.connect(websocket, room_identifier)
    try:
        while True:
            data = await websocket.receive_text()
            print(f"Received message in room {room_identifier}: {data}")
            # Here, you'd typically parse the message (e.g., JSON)
            # Extract user ID, content, save to DB, then broadcast
            # This example just broadcasts the raw text received
            # In production: Validate data, get user info, save, create ChatMessageData, broadcast JSON
            await manager.broadcast(f"Message: {data}", room_identifier)
    except WebSocketDisconnect:
        manager.disconnect(websocket, room_identifier)
        print(f"WebSocket disconnected from room {room_identifier}")
    except Exception as e:
         print(f"Error in WebSocket handler for room {room_identifier}: {e}")
         manager.disconnect(websocket, room_identifier) # Ensure cleanup on error
         # Optionally try to send an error message before closing if possible
         try:
             await websocket.close(code=status.WS_1011_INTERNAL_ERROR)
         except:
             pass # Ignore errors during close after another error

# --- HTTP Endpoints for Chat History/Sending (as fallback or initial load) ---

@app.post("/chat/messages", status_code=status.HTTP_201_CREATED, response_model=ChatMessageData)
async def send_chat_message_http(
    message_data: ChatMessageCreate,
    user_id: int = Depends(get_current_user),
    community_id: Optional[int] = None,
    event_id: Optional[int] = None
):
    print(f"🔹 HTTP Send Message: User={user_id}, Comm={community_id}, Event={event_id}")

    if community_id is None and event_id is None:
        raise HTTPException(status_code=400, detail="Either community_id or event_id must be provided.")
    if community_id is not None and event_id is not None:
         raise HTTPException(status_code=400, detail="Cannot send message to both community and event.")

    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    try:
        cursor.execute(
            """
            INSERT INTO chat_messages (community_id, event_id, user_id, content)
            VALUES (%s, %s, %s, %s) RETURNING id, timestamp;
            """,
            (community_id, event_id, user_id, message_data.content)
        )
        result = cursor.fetchone()
        if not result:
            raise HTTPException(status_code=500, detail="Message insertion failed.")

        message_id = result["id"]
        timestamp = result["timestamp"]

        # Fetch username for broadcasting
        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user_info = cursor.fetchone()
        username = user_info['username'] if user_info else "Unknown"

        conn.commit()
        print(f"✅ Message {message_id} saved to DB.")

        # Prepare data for broadcast and return
        chat_message = ChatMessageData(
             message_id=message_id,
             community_id=community_id,
             event_id=event_id,
             user_id=user_id,
             username=username,
             content=message_data.content,
             timestamp=timestamp
         )

        # Broadcast via WebSocket manager
        room_id_str = f"community_{community_id}" if community_id else f"event_{event_id}"
        await manager.broadcast(chat_message.json(), room_id_str)

        return chat_message

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ DB Error sending message: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except Exception as e:
        conn.rollback()
        print(f"❌ Error sending message via HTTP: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/chat/messages")
async def get_chat_messages(
    community_id: Optional[int] = None,
    event_id: Optional[int] = None,
    limit: int = 50, # Default limit
    before_id: Optional[int] = None # For pagination (load older messages)
):
    print(f"🔹 HTTP Get Messages: Comm={community_id}, Event={event_id}, Limit={limit}, Before={before_id}")
    if community_id is None and event_id is None:
        raise HTTPException(status_code=400, detail="Either community_id or event_id must be provided.")
    # Allow fetching for both if needed? For now, assume one or the other.
    # if community_id is not None and event_id is not None:
    #     raise HTTPException(status_code=400, detail="Cannot specify both community_id and event_id.")

    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    query = """
        SELECT m.id as message_id, m.community_id, m.event_id, m.user_id, m.content, m.timestamp,
               u.username
        FROM chat_messages m
        JOIN users u ON m.user_id = u.id
        WHERE """
    params = []
    filters = []

    if community_id is not None:
        filters.append("m.community_id = %s")
        params.append(community_id)
    if event_id is not None:
         # Allow fetching event messages OR community messages if event_id specified
         # If you ONLY want event messages, use: filters.append("m.event_id = %s")
         filters.append("(m.event_id = %s OR (m.community_id = (SELECT community_id FROM events WHERE id = %s) AND m.event_id IS NULL))")
         params.extend([event_id, event_id]) # Needs event_id twice
    # This logic needs refinement based on exact chat scoping requirements


    if before_id is not None:
        filters.append("m.id < %s")
        params.append(before_id)

    query += " AND ".join(filters)
    query += " ORDER BY m.timestamp DESC LIMIT %s;" # Fetch latest first
    params.append(limit)

    try:
        cursor.execute(query, tuple(params))
        messages = cursor.fetchall()
        # Convert datetime to ISO format string for JSON compatibility
        for msg in messages:
            if isinstance(msg.get('timestamp'), datetime):
                 msg['timestamp'] = msg['timestamp'].isoformat()

        print(f"✅ Fetched {len(messages)} messages.")
        return {"messages": messages} # Return newest first, frontend should reverse
    except Exception as e:
        print(f"❌ Error fetching messages: {e}")
        raise HTTPException(status_code=500, detail="Error fetching messages")
    finally:
        cursor.close()
        conn.close()


# ------------------------
# Other Endpoints (Membership, Favorites, etc.) - Assume they are mostly okay,
# but ensure they use Depends(get_current_user) for authentication.
# ------------------------

# --- Community Membership ---
@app.post("/communities/{community_id}/join", status_code=status.HTTP_200_OK)
def join_community(community_id: int, user_id: int = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO community_members (user_id, community_id) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING id;", (user_id, community_id))
        result = cursor.fetchone()
        conn.commit()
        if result:
             return {"message": "Joined community successfully"}
        else:
             return {"message": "Already a member"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.delete("/communities/{community_id}/leave", status_code=status.HTTP_200_OK)
def leave_community(community_id: int, user_id: int = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM community_members WHERE user_id = %s AND community_id = %s RETURNING id;", (user_id, community_id))
        result = cursor.fetchone()
        conn.commit()
        if result:
             return {"message": "Left community successfully"}
        else:
             return {"message": "Not a member"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

# --- Post Favorites ---
@app.post("/posts/{post_id}/favorite", status_code=status.HTTP_200_OK)
def favorite_post(post_id: int, user_id: int = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO post_favorites (user_id, post_id) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING id;", (user_id, post_id))
        result = cursor.fetchone()
        conn.commit()
        if result:
             return {"message": "Post favorited"}
        else:
             return {"message": "Post already favorited"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.delete("/posts/{post_id}/unfavorite", status_code=status.HTTP_200_OK)
def unfavorite_post(post_id: int, user_id: int = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM post_favorites WHERE user_id = %s AND post_id = %s RETURNING id;", (user_id, post_id))
        result = cursor.fetchone()
        conn.commit()
        if result:
            return {"message": "Post unfavorited"}
        else:
            return {"message": "Post was not favorited"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()


# --- Reply Favorites --- (Similar pattern for favorite/unfavorite)
@app.post("/replies/{reply_id}/favorite", status_code=status.HTTP_200_OK)
def favorite_reply(reply_id: int, user_id: int = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO reply_favorites (user_id, reply_id) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING id;", (user_id, reply_id))
        result = cursor.fetchone()
        conn.commit()
        if result:
             return {"message": "Reply favorited"}
        else:
             return {"message": "Reply already favorited"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.delete("/replies/{reply_id}/unfavorite", status_code=status.HTTP_200_OK)
def unfavorite_reply(reply_id: int, user_id: int = Depends(get_current_user)):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM reply_favorites WHERE user_id = %s AND reply_id = %s RETURNING id;", (user_id, reply_id))
        result = cursor.fetchone()
        conn.commit()
        if result:
             return {"message": "Reply unfavorited"}
        else:
             return {"message": "Reply was not favorited"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()


# --- Community Post Management --- (Ensure authentication)
@app.post("/communities/{community_id}/add_post/{post_id}", status_code=status.HTTP_201_CREATED)
def add_post_to_community(community_id: int, post_id: int, user_id: int = Depends(get_current_user)):
     # Add logic here to check if the user has permission to add posts to this community (e.g., is a member or moderator)
     # ... permission check ...
     # if not has_permission:
     #     raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to add posts to this community")

     conn = get_db_connection()
     cursor = conn.cursor()
     try:
        cursor.execute("INSERT INTO community_posts (community_id, post_id) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING id;", (community_id, post_id))
        result = cursor.fetchone()
        conn.commit()
        if result:
            return {"message": "Post added to community"}
        else:
            return {"message": "Post already in community"}
     except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
     finally:
        cursor.close()
        conn.close()

@app.delete("/communities/{community_id}/remove_post/{post_id}", status_code=status.HTTP_200_OK)
def remove_post_from_community(community_id: int, post_id: int, user_id: int = Depends(get_current_user)):
     # Add logic here to check if the user has permission (e.g., is moderator or author of post)
     # ... permission check ...

     conn = get_db_connection()
     cursor = conn.cursor()
     try:
        cursor.execute("DELETE FROM community_posts WHERE community_id = %s AND post_id = %s RETURNING id;", (community_id, post_id))
        result = cursor.fetchone()
        conn.commit()
        if result:
            return {"message": "Post removed from community"}
        else:
            return {"message": "Post was not in this community"}
     except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
     finally:
        cursor.close()
        conn.close()

@app.post("/communities/{community_id}/events", status_code=status.HTTP_201_CREATED, response_model=EventDetails)
def create_event_endpoint(
    community_id: int,
    event_data: EventCreate,
    user_id: int = Depends(get_current_user)
):
    print(f"🔹 Creating event in community {community_id} by user {user_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        # Optional: Check if user is member/admin of the community
        # ...

        cursor.execute(
            """
            INSERT INTO events (community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id, created_at;
            """,
            (community_id, user_id, event_data.title, event_data.description, event_data.location,
             event_data.event_timestamp, event_data.max_participants, event_data.image_url)
        )
        result = cursor.fetchone()
        if not result:
            raise HTTPException(status_code=500, detail="Event creation failed.")

        event_id = result['id']
        created_at = result['created_at']

        # Automatically add creator as participant
        cursor.execute(
            "INSERT INTO event_participants (event_id, user_id) VALUES (%s, %s) ON CONFLICT DO NOTHING;",
            (event_id, user_id)
        )
        conn.commit()
        print(f"✅ Event {event_id} created successfully.")

        # Return the created event details
        return EventDetails(
            id=event_id, community_id=community_id, creator_id=user_id, created_at=created_at,
            participant_count=1, # Creator is the first participant
            **event_data.dict() # Include fields from EventCreate
        )

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ DB Error creating event: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except Exception as e:
        conn.rollback()
        print(f"❌ Error creating event: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/communities/{community_id}/events", response_model=List[EventDetails])
def list_community_events(community_id: int):
    print(f"🔹 Fetching events for community {community_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    query = """
        SELECT e.*, COUNT(ep.user_id) as participant_count
        FROM events e
        LEFT JOIN event_participants ep ON e.id = ep.event_id
        WHERE e.community_id = %s
        GROUP BY e.id
        ORDER BY e.event_timestamp ASC;
    """
    try:
        cursor.execute(query, (community_id,))
        events = cursor.fetchall()
        print(f"✅ Fetched {len(events)} events for community {community_id}")
        return events
    except Exception as e:
        print(f"❌ Error fetching community events: {e}")
        raise HTTPException(status_code=500, detail="Error fetching events")
    finally:
        cursor.close()
        conn.close()

@app.get("/events/{event_id}", response_model=EventDetails)
def get_event_details(event_id: int):
    print(f"🔹 Fetching details for event {event_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    query = """
        SELECT e.*, COUNT(ep.user_id) as participant_count
        FROM events e
        LEFT JOIN event_participants ep ON e.id = ep.event_id
        WHERE e.id = %s
        GROUP BY e.id;
    """
    try:
        cursor.execute(query, (event_id,))
        event = cursor.fetchone()
        if not event:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        print(f"✅ Fetched details for event {event_id}")
        return event
    except Exception as e:
        print(f"❌ Error fetching event details: {e}")
        raise HTTPException(status_code=500, detail="Error fetching event details")
    finally:
        cursor.close()
        conn.close()

@app.put("/events/{event_id}", response_model=EventDetails)
def update_event_endpoint(
    event_id: int,
    event_update: EventUpdate,
    user_id: int = Depends(get_current_user)
):
    print(f"🔹 Updating event {event_id} by user {user_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    try:
        # Check ownership
        cursor.execute("SELECT creator_id FROM events WHERE id = %s;", (event_id,))
        event = cursor.fetchone()
        if not event:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        if event['creator_id'] != user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to update this event")

        # Build update query dynamically based on provided fields
        update_data = event_update.dict(exclude_unset=True) # Get only fields that were explicitly set
        if not update_data:
            raise HTTPException(status_code=400, detail="No update data provided")

        set_clauses = []
        params = []
        for key, value in update_data.items():
            set_clauses.append(f"{key} = %s")
            params.append(value)

        params.append(event_id) # Add event_id for the WHERE clause

        query = f"UPDATE events SET {', '.join(set_clauses)} WHERE id = %s RETURNING *;"

        cursor.execute(query, tuple(params))
        updated_event_base = cursor.fetchone()
        conn.commit()
        print(f"✅ Event {event_id} updated successfully.")

         # Fetch participant count separately after update
        cursor.execute("SELECT COUNT(*) as count FROM event_participants WHERE event_id = %s", (event_id,))
        count_result = cursor.fetchone()
        participant_count = count_result['count'] if count_result else 0

        updated_event_base['participant_count'] = participant_count # Add count to response dict

        return updated_event_base # Pydantic will validate against EventDetails

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ DB Error updating event: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except HTTPException as he:
         conn.rollback()
         raise he
    except Exception as e:
        conn.rollback()
        print(f"❌ Error updating event: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.delete("/events/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_event_endpoint(event_id: int, user_id: int = Depends(get_current_user)):
    print(f"🔹 Deleting event {event_id} by user {user_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        # Check ownership
        cursor.execute("SELECT creator_id FROM events WHERE id = %s;", (event_id,))
        event = cursor.fetchone()
        if not event:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
        if event['creator_id'] != user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to delete this event")

        # Delete event (cascades should handle participants)
        cursor.execute("DELETE FROM events WHERE id = %s;", (event_id,))
        conn.commit()
        print(f"✅ Event {event_id} deleted successfully.")

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ DB Error deleting event: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        print(f"❌ Error deleting event: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()
    return # No content

@app.post("/events/{event_id}/join", status_code=status.HTTP_200_OK)
def join_event_endpoint(event_id: int, user_id: int = Depends(get_current_user)):
    print(f"🔹 User {user_id} joining event {event_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        # Optional: Check if event is full before attempting insert
        cursor.execute("SELECT max_participants FROM events WHERE id = %s;", (event_id,))
        event = cursor.fetchone()
        if not event:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

        cursor.execute("SELECT COUNT(*) as current_participants FROM event_participants WHERE event_id = %s;", (event_id,))
        participation = cursor.fetchone()
        if participation and participation['current_participants'] >= event['max_participants']:
             raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Event is full")

        # Attempt to join
        cursor.execute(
            "INSERT INTO event_participants (event_id, user_id) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING id;",
            (event_id, user_id)
        )
        result = cursor.fetchone()
        conn.commit()
        if result:
            print(f"✅ User {user_id} joined event {event_id}")
            return {"message": "Successfully joined event"}
        else:
            print(f"ℹ️ User {user_id} already in event {event_id}")
            return {"message": "Already joined this event"}

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ DB Error joining event: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except HTTPException as he:
         conn.rollback()
         raise he
    except Exception as e:
        conn.rollback()
        print(f"❌ Error joining event: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.delete("/events/{event_id}/leave", status_code=status.HTTP_200_OK)
def leave_event_endpoint(event_id: int, user_id: int = Depends(get_current_user)):
    print(f"🔹 User {user_id} leaving event {event_id}")
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cursor.execute(
            "DELETE FROM event_participants WHERE event_id = %s AND user_id = %s RETURNING id;",
            (event_id, user_id)
        )
        result = cursor.fetchone()
        conn.commit()
        if result:
            print(f"✅ User {user_id} left event {event_id}")
            return {"message": "Successfully left event"}
        else:
            print(f"ℹ️ User {user_id} was not in event {event_id}")
            return {"message": "Not currently participating in this event"}

    except psycopg2.Error as e:
        conn.rollback()
        print(f"❌ DB Error leaving event: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e.pgerror}")
    except Exception as e:
        conn.rollback()
        print(f"❌ Error leaving event: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

# Add a simple root endpoint for testing
@app.get("/")
def read_root():
    return {"message": "Connections API is running!"}