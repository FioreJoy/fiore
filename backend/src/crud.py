# backend/crud.py
import psycopg2
import psycopg2.extras # For RealDictCursor, though connection factory handles it
from datetime import datetime, timezone, timedelta
from typing import List, Optional, Dict, Any
import bcrypt # Import bcrypt here for password check
from .utils import get_minio_url # Import the URL generator
from .utils import format_location_for_db # Ensure this is imported
from . import schemas
#from sqlalchemy.orm import Session
#from . import models
# --- User CRUD ---

def get_user_by_email(cursor: psycopg2.extensions.cursor, email: str) -> Optional[Dict[str, Any]]:
    """Fetches a user by email."""
    cursor.execute("SELECT id, username, password_hash FROM users WHERE email = %s", (email,))
    return cursor.fetchone()

def get_user_by_id(cursor: psycopg2.extensions.cursor, user_id: int) -> Optional[Dict[str, Any]]:
    """Fetches a user by ID including image_path."""
    cursor.execute(
        """SELECT id, name, username, email, gender, image_path, -- Select image_path
                  current_location, college, interest, created_at, last_seen
           FROM users WHERE id = %s;""",
        (user_id,)
    )
    user_data = cursor.fetchone()
    # if user_data and user_data.get('image_path'): # Generate full URL before returning
    #     user_data['image_url'] = get_minio_url(user_data['image_path'])
    return user_data


def create_user(cursor: psycopg2.extensions.cursor, name: str, username: str, email: str, password: str, gender: str, current_location_str: str, college: str, interests_str: Optional[str], image_path: Optional[str]) -> Optional[int]: # Accept image_path
    """Creates a new user with image_path and returns the new user ID."""
    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    try:
        cursor.execute(
            """
            INSERT INTO users (name, username, email, password_hash, gender, current_location, college, interest, image_path) -- Use image_path
            VALUES (%s, %s, %s, %s, %s, %s::point, %s, %s, %s) RETURNING id;
            """,
            (name, username, email, hashed_password, gender, current_location_str, college, interests_str, image_path) # Pass image_path
        )
        result = cursor.fetchone()
        return result['id'] if result else None
    except psycopg2.IntegrityError:
        # Let the route handler catch this and return 409
        raise
    except Exception as e:
        print(f"Error in create_user: {e}")
        raise # Re-raise for route handler
def update_user_profile(cursor: psycopg2.extensions.cursor, user_id: int, update_data: Dict[str, Any]) -> bool:
    """Updates user profile fields."""
    set_clauses = []
    params = []
    allowed_fields = ['name', 'username', 'gender', 'current_location', 'college', 'interest', 'image_path'] # Add 'image_path'

    # Special handling for location POINT format if needed
    if 'current_location' in update_data and isinstance(update_data['current_location'], dict):
        # Assuming dict {'longitude': lon, 'latitude': lat} is passed
        lon = update_data['current_location'].get('longitude', 0)
        lat = update_data['current_location'].get('latitude', 0)
        update_data['current_location_str'] = f'({lon},{lat})' # Format for DB
    elif 'current_location' in update_data:
        # Assume it's already a string like '(lon,lat)'
        update_data['current_location_str'] = update_data['current_location']


    for key, value in update_data.items():
        if key in allowed_fields:
            if key == 'current_location': # Use the formatted string
                set_clauses.append("current_location = %s::point")
                params.append(update_data['current_location_str'])
            else:
                set_clauses.append(f"{key} = %s")
                params.append(value)

    if not set_clauses:
        return False # Nothing to update

    params.append(user_id)
    query = f"UPDATE users SET {', '.join(set_clauses)} WHERE id = %s;"
    try:
        cursor.execute(query, tuple(params))
        return cursor.rowcount > 0 # Return True if update happened
    except Exception as e:
        print(f"Error updating user profile (ID: {user_id}): {e}")
        raise # Re-raise for route handler

def update_user_last_seen(cursor: psycopg2.extensions.cursor, user_id: int):
     """Updates the last_seen timestamp for a user."""
     # Note: This is also handled in database.py for the dependency.
     # This version could be used within route handlers if needed.
     try:
         cursor.execute("UPDATE users SET last_seen = NOW() WHERE id = %s", (user_id,))
         print(f"CRUD: Updated last_seen for user {user_id}")
     except Exception as e:
          print(f"CRUD Error updating last_seen for user {user_id}: {e}")
          raise

# --- Post CRUD ---

def create_post_db(cursor: psycopg2.extensions.cursor, user_id: int, title: str, content: str, image_path: Optional[str] = None, community_id: Optional[int] = None) -> Optional[int]:
    """Creates a post, optionally with an image path and links to a community."""
    try:
        cursor.execute(
            "INSERT INTO posts (user_id, title, content, image_path) VALUES (%s, %s, %s, %s) RETURNING id;", # Added image_path
            (user_id, title, content, image_path), # Pass image_path
        )
        post_result = cursor.fetchone()
        if not post_result:
            return None
        post_id = post_result["id"]

        if community_id is not None:
            cursor.execute(
                """
                INSERT INTO community_posts (community_id, post_id)
                VALUES (%s, %s) ON CONFLICT (community_id, post_id) DO NOTHING;
                """,
                (community_id, post_id)
            )
        return post_id
    except Exception as e:
         print(f"Error in create_post_db: {e}")
         raise

def get_post_by_id(cursor: psycopg2.extensions.cursor, post_id: int) -> Optional[Dict[str, Any]]:
    """Fetches a single post by its ID."""
    cursor.execute("SELECT * FROM posts WHERE id = %s", (post_id,))
    return cursor.fetchone()

def get_posts_db(cursor: psycopg2.extensions.cursor, community_id: Optional[int] = None, user_id: Optional[int] = None) -> List[Dict[str, Any]]:
    """Fetches posts, optionally filtered, includes image_path."""
    query = """
        SELECT
            p.id, p.user_id, p.content, p.title, p.created_at, p.image_path, -- Added p.image_path
            u.username AS author_name,
            u.image_path AS author_avatar, -- Renamed author_avatar from u.image_path
            COALESCE(v_counts.upvotes, 0) AS upvotes,
            COALESCE(v_counts.downvotes, 0) AS downvotes,
            COALESCE(r_counts.reply_count, 0) AS reply_count,
            c.id as community_id,
            c.name as community_name
        FROM posts p
        JOIN users u ON p.user_id = u.id
        LEFT JOIN community_posts cp ON p.id = cp.post_id
        LEFT JOIN communities c ON cp.community_id = c.id
        LEFT JOIN (
            SELECT post_id,
                   COUNT(*) FILTER (WHERE vote_type = TRUE) AS upvotes,
                   COUNT(*) FILTER (WHERE vote_type = FALSE) AS downvotes
            FROM votes WHERE post_id IS NOT NULL GROUP BY post_id
        ) AS v_counts ON p.id = v_counts.post_id
        LEFT JOIN (
            SELECT post_id, COUNT(*) AS reply_count
            FROM replies GROUP BY post_id
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

    cursor.execute(query, tuple(params))
    return cursor.fetchall()

def get_trending_posts_db(cursor: psycopg2.extensions.cursor) -> List[Dict[str, Any]]:
    """Fetches trending posts, includes image_path."""
    query = """
        SELECT
            p.id, p.user_id, p.content, p.title, p.created_at, p.image_path, -- Added p.image_path
            u.username AS author_name,
            u.image_path AS author_avatar, -- Renamed author_avatar from u.image_path
            c.id as community_id,
            c.name as community_name,
            (COALESCE(recent_votes.count, 0) + COALESCE(recent_replies.count, 0)) AS recent_activity_score,
             COALESCE(v_counts.upvotes, 0) AS upvotes,
             COALESCE(v_counts.downvotes, 0) AS downvotes,
             COALESCE(r_counts.reply_count, 0) AS reply_count
        FROM posts p
         -- ... (rest of joins and conditions) ...
    """
    cursor.execute(query)
    return cursor.fetchall()

def delete_post_db(cursor: psycopg2.extensions.cursor, post_id: int) -> int:
    """Deletes a post by ID. Returns the number of rows affected."""
    cursor.execute("DELETE FROM posts WHERE id = %s;", (post_id,))
    return cursor.rowcount

# --- Community CRUD ---
def create_community_db(cursor: psycopg2.extensions.cursor, name: str, description: Optional[str], created_by: int, primary_location_str: str, interest: Optional[str], logo_path: Optional[str]) -> Optional[int]: # Added logo_path
    """Creates a community with logo_path, returns community ID."""
    try:
        cursor.execute(
            """
            INSERT INTO communities (name, description, created_by, primary_location, interest, logo_path) -- Added logo_path
            VALUES (%s, %s, %s, %s::point, %s, %s) RETURNING id; -- Added %s for logo_path
            """,
            (name, description, created_by, primary_location_str, interest, logo_path), # Pass logo_path
        )
        result = cursor.fetchone()
        if not result: return None
        community_id = result["id"]
        # Automatically add creator as member
        cursor.execute(
            "INSERT INTO community_members (user_id, community_id) VALUES (%s, %s) ON CONFLICT DO NOTHING;",
            (created_by, community_id)
        )
        return community_id
    except psycopg2.IntegrityError:
        raise # Let route handle conflict
    except Exception as e:
         print(f"Error in create_community_db: {e}")
         raise

def get_community_by_id(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
    """Fetches basic community data by ID."""
    cursor.execute("SELECT * FROM communities WHERE id = %s", (community_id,))
    return cursor.fetchone()

def get_communities_db(cursor: psycopg2.extensions.cursor) -> List[Dict[str, Any]]:
    """Fetches all communities with member counts and logo_path."""
    query = """
        SELECT c.*, COUNT(cm.user_id) as member_count, c.logo_path -- Added c.logo_path
        FROM communities c
        LEFT JOIN community_members cm ON c.id = cm.community_id
        GROUP BY c.id
        ORDER BY c.created_at DESC;
    """
    cursor.execute(query)
    return cursor.fetchall()
def update_community_details_db(cursor: psycopg2.extensions.cursor, community_id: int, update_data: schemas.CommunityUpdate) -> bool:
    """ Updates community details based on provided data. Returns True if updated, False otherwise. """
    set_clauses = []
    params = []

    # Use model_dump(exclude_unset=True) for Pydantic v2 or .dict(exclude_unset=True) for v1
    update_dict = update_data.model_dump(exclude_unset=True) # Pydantic v2
    # update_dict = update_data.dict(exclude_unset=True) # Pydantic v1

    for key, value in update_dict.items():
        if key == 'primary_location' and value:
            # Format the location string if provided
            formatted_location = format_location_for_db(value)
            set_clauses.append("primary_location = %s::point")
            params.append(formatted_location)
        elif key in ['name', 'description', 'interest']: # Allowed fields
            set_clauses.append(f"{key} = %s")
            params.append(value)
        # Add other updatable fields here if necessary

    if not set_clauses:
        return False # Nothing to update

    params.append(community_id)
    query = f"UPDATE communities SET {', '.join(set_clauses)} WHERE id = %s;"

    try:
        cursor.execute(query, tuple(params))
        # rowcount > 0 indicates the update happened (row was found and potentially changed)
        return cursor.rowcount > 0
    except psycopg2.Error as e:
        print(f"Error updating community details (ID: {community_id}): {e}")
        raise # Re-raise for the endpoint handler to catch (e.g., name conflict)
    except Exception as e:
         print(f"Unexpected error updating community details (ID: {community_id}): {e}")
         raise

# --- NEW: Function to Update Community Logo Path ---
def update_community_logo_path_db(cursor: psycopg2.extensions.cursor, community_id: int, logo_path: Optional[str]) -> bool:
    """ Updates only the logo_path for a community. Returns True if updated. """
    try:
        cursor.execute(
            "UPDATE communities SET logo_path = %s WHERE id = %s;",
            (logo_path, community_id)
        )
        return cursor.rowcount > 0
    except Exception as e:
         print(f"Error updating community logo path (ID: {community_id}): {e}")
         raise

def get_trending_communities_db(cursor: psycopg2.extensions.cursor) -> List[Dict[str, Any]]:
     """Fetches trending communities based on recent activity."""
     # Using the existing query from main.py
     query = """
        SELECT
            c.id, c.name, c.description, c.interest, c.primary_location,
            (COALESCE(recent_members.count, 0) + COALESCE(recent_posts.count, 0)) AS recent_activity_score,
            COALESCE(total_members.count, 0) as member_count
        FROM communities c
        LEFT JOIN (
            SELECT community_id, COUNT(*) as count FROM community_members
            WHERE joined_at >= NOW() - INTERVAL '48 hours' GROUP BY community_id
        ) AS recent_members ON c.id = recent_members.community_id
        LEFT JOIN (
            SELECT cp.community_id, COUNT(*) as count FROM community_posts cp
            JOIN posts p ON cp.post_id = p.id
            WHERE p.created_at >= NOW() - INTERVAL '48 hours' GROUP BY cp.community_id
        ) AS recent_posts ON c.id = recent_posts.community_id
        LEFT JOIN (
             SELECT community_id, COUNT(*) as count FROM community_members GROUP BY community_id
        ) AS total_members ON c.id = total_members.community_id
        WHERE c.created_at >= NOW() - INTERVAL '30 days'
        ORDER BY recent_activity_score DESC, c.created_at DESC
        LIMIT 15;
     """
     cursor.execute(query)
     return cursor.fetchall()


def get_community_details_db(cursor: psycopg2.extensions.cursor, community_id: int) -> Optional[Dict[str, Any]]:
    """Fetches detailed community data including online count."""
    ONLINE_THRESHOLD_MINUTES = 5 # Move this constant?
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
    cursor.execute(query, (online_threshold, community_id))
    return cursor.fetchone()

def delete_community_db(cursor: psycopg2.extensions.cursor, community_id: int) -> int:
    """Deletes a community by ID. Returns row count."""
    cursor.execute("DELETE FROM communities WHERE id = %s;", (community_id,))
    return cursor.rowcount

def join_community_db(cursor: psycopg2.extensions.cursor, user_id: int, community_id: int) -> Optional[int]:
    """Adds a user to a community. Returns member ID if added, None otherwise."""
    cursor.execute(
        "INSERT INTO community_members (user_id, community_id) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING id;",
        (user_id, community_id)
    )
    result = cursor.fetchone()
    return result['id'] if result else None

def leave_community_db(cursor: psycopg2.extensions.cursor, user_id: int, community_id: int) -> Optional[int]:
    """Removes a user from a community. Returns deleted ID if successful."""
    cursor.execute(
        "DELETE FROM community_members WHERE user_id = %s AND community_id = %s RETURNING id;",
        (user_id, community_id)
    )
    result = cursor.fetchone()
    return result['id'] if result else None

def add_post_to_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> Optional[int]:
     """Links a post to a community."""
     cursor.execute(
         "INSERT INTO community_posts (community_id, post_id) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING id;",
         (community_id, post_id)
     )
     result = cursor.fetchone()
     return result['id'] if result else None

def remove_post_from_community_db(cursor: psycopg2.extensions.cursor, community_id: int, post_id: int) -> Optional[int]:
     """Unlinks a post from a community."""
     cursor.execute(
         "DELETE FROM community_posts WHERE community_id = %s AND post_id = %s RETURNING id;",
         (community_id, post_id)
     )
     result = cursor.fetchone()
     return result['id'] if result else None


# --- Vote CRUD ---
def get_existing_vote(cursor: psycopg2.extensions.cursor, user_id: int, post_id: Optional[int], reply_id: Optional[int]) -> Optional[Dict[str, Any]]:
    """Checks if a user has voted on a specific post or reply."""
    target_column = "post_id" if post_id else "reply_id"
    target_id = post_id if post_id else reply_id
    cursor.execute(
        f"SELECT id, vote_type FROM votes WHERE user_id = %s AND {target_column} = %s;",
        (user_id, target_id)
    )
    return cursor.fetchone()

def create_vote_db(cursor: psycopg2.extensions.cursor, user_id: int, post_id: Optional[int], reply_id: Optional[int], vote_type: bool) -> Optional[int]:
    """Inserts a new vote."""
    cursor.execute(
        "INSERT INTO votes (user_id, post_id, reply_id, vote_type) VALUES (%s, %s, %s, %s) RETURNING id;",
        (user_id, post_id, reply_id, vote_type)
    )
    result = cursor.fetchone()
    return result['id'] if result else None

def update_vote_db(cursor: psycopg2.extensions.cursor, vote_id: int, vote_type: bool) -> Optional[int]:
    """Updates an existing vote's type."""
    cursor.execute(
        "UPDATE votes SET vote_type = %s, created_at = NOW() WHERE id = %s RETURNING id;",
        (vote_type, vote_id)
    )
    result = cursor.fetchone()
    return result['id'] if result else None

def delete_vote_db(cursor: psycopg2.extensions.cursor, vote_id: int) -> int:
    """Deletes a vote by ID."""
    cursor.execute("DELETE FROM votes WHERE id = %s;", (vote_id,))
    return cursor.rowcount

def get_votes_db(cursor: psycopg2.extensions.cursor, post_id: Optional[int] = None, reply_id: Optional[int] = None) -> List[Dict[str, Any]]:
    """Fetches votes for a specific post or reply."""
    query = "SELECT id, user_id, post_id, reply_id, vote_type FROM votes WHERE "
    params = []
    if post_id:
        query += "post_id = %s "
        params.append(post_id)
    elif reply_id:
        query += "reply_id = %s "
        params.append(reply_id)
    else:
        return [] # Should not happen if route validates
    query += "ORDER BY created_at DESC;"
    cursor.execute(query, tuple(params))
    return cursor.fetchall()


# --- Reply CRUD ---
def get_reply_by_id(cursor: psycopg2.extensions.cursor, reply_id: int) -> Optional[Dict[str, Any]]:
    """Fetches a single reply by ID."""
    cursor.execute("SELECT id, user_id, post_id FROM replies WHERE id = %s", (reply_id,))
    return cursor.fetchone()

def create_reply_db(cursor: psycopg2.extensions.cursor, post_id: int, user_id: int, content: str, parent_reply_id: Optional[int]) -> Optional[int]:
    """Creates a reply, returns reply ID."""
    try:
        cursor.execute(
            """
            INSERT INTO replies (post_id, user_id, content, parent_reply_id)
            VALUES (%s, %s, %s, %s) RETURNING id;
            """,
            (post_id, user_id, content, parent_reply_id)
        )
        result = cursor.fetchone()
        return result['id'] if result else None
    except Exception as e:
         print(f"Error in create_reply_db: {e}")
         raise

def get_replies_for_post_db(cursor: psycopg2.extensions.cursor, post_id: int) -> List[Dict[str, Any]]:
    """Fetches replies, includes author's avatar path."""
    query = """
        SELECT
            r.id, r.post_id, r.user_id, r.content, r.parent_reply_id, r.created_at,
            u.username AS author_name,
            u.image_path AS author_avatar, -- Select author's image_path
            COALESCE(v_counts.upvotes, 0) AS upvotes,
            COALESCE(v_counts.downvotes, 0) AS downvotes
        FROM replies r
        JOIN users u ON r.user_id = u.id
        LEFT JOIN (
            SELECT reply_id,
                   COUNT(*) FILTER (WHERE vote_type = TRUE) AS upvotes,
                   COUNT(*) FILTER (WHERE vote_type = FALSE) AS downvotes
            FROM votes WHERE reply_id IS NOT NULL GROUP BY reply_id
        ) AS v_counts ON r.id = v_counts.reply_id
        WHERE r.post_id = %s
        ORDER BY r.created_at ASC;
    """
    cursor.execute(query, (post_id,))
    return cursor.fetchall()

def delete_reply_db(cursor: psycopg2.extensions.cursor, reply_id: int) -> int:
    """Deletes a reply by ID."""
    cursor.execute("DELETE FROM replies WHERE id = %s;", (reply_id,))
    return cursor.rowcount

# --- Favorites CRUD ---
def add_post_favorite_db(cursor: psycopg2.extensions.cursor, user_id: int, post_id: int) -> Optional[int]:
     cursor.execute("INSERT INTO post_favorites (user_id, post_id) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING id;", (user_id, post_id))
     result = cursor.fetchone()
     return result['id'] if result else None

def remove_post_favorite_db(cursor: psycopg2.extensions.cursor, user_id: int, post_id: int) -> Optional[int]:
     cursor.execute("DELETE FROM post_favorites WHERE user_id = %s AND post_id = %s RETURNING id;", (user_id, post_id))
     result = cursor.fetchone()
     return result['id'] if result else None

def add_reply_favorite_db(cursor: psycopg2.extensions.cursor, user_id: int, reply_id: int) -> Optional[int]:
     cursor.execute("INSERT INTO reply_favorites (user_id, reply_id) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING id;", (user_id, reply_id))
     result = cursor.fetchone()
     return result['id'] if result else None

def remove_reply_favorite_db(cursor: psycopg2.extensions.cursor, user_id: int, reply_id: int) -> Optional[int]:
     cursor.execute("DELETE FROM reply_favorites WHERE user_id = %s AND reply_id = %s RETURNING id;", (user_id, reply_id))
     result = cursor.fetchone()
     return result['id'] if result else None

# --- Event CRUD ---
def create_event_db(cursor: psycopg2.extensions.cursor, community_id: int, creator_id: int, title: str, description: Optional[str], location: str, event_timestamp: datetime, max_participants: int, image_url: Optional[str]) -> Optional[Dict[str, Any]]:
    """Creates an event, adds creator as participant, returns event ID and created_at."""
    try:
        cursor.execute(
            """
            INSERT INTO events (community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id, created_at;
            """,
            (community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url)
        )
        result = cursor.fetchone()
        if not result: return None
        event_id = result['id']
        # Add creator as participant
        cursor.execute(
            "INSERT INTO event_participants (event_id, user_id) VALUES (%s, %s) ON CONFLICT DO NOTHING;",
            (event_id, creator_id)
        )
        return result # Contains {'id': ..., 'created_at': ...}
    except Exception as e:
         print(f"Error in create_event_db: {e}")
         raise

def get_events_for_community_db(cursor: psycopg2.extensions.cursor, community_id: int) -> List[Dict[str, Any]]:
    """Fetches events for a community with participant counts."""
    query = """
        SELECT e.*, COUNT(ep.user_id) as participant_count
        FROM events e
        LEFT JOIN event_participants ep ON e.id = ep.event_id
        WHERE e.community_id = %s
        GROUP BY e.id
        ORDER BY e.event_timestamp ASC;
    """
    cursor.execute(query, (community_id,))
    return cursor.fetchall()

def get_event_details_db(cursor: psycopg2.extensions.cursor, event_id: int) -> Optional[Dict[str, Any]]:
    """Fetches event details with participant count."""
    query = """
        SELECT e.*, COUNT(ep.user_id) as participant_count
        FROM events e
        LEFT JOIN event_participants ep ON e.id = ep.event_id
        WHERE e.id = %s
        GROUP BY e.id;
    """
    cursor.execute(query, (event_id,))
    return cursor.fetchone()

def update_event_db(cursor: psycopg2.extensions.cursor, event_id: int, update_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Updates an event with the provided data."""
    set_clauses = []
    params = []
    for key, value in update_data.items():
        # Basic check to prevent SQL injection, ideally validate keys against schema
        if key in ['title', 'description', 'location', 'event_timestamp', 'max_participants', 'image_url']:
            set_clauses.append(f"{key} = %s")
            params.append(value)

    if not set_clauses: return None # Nothing to update

    params.append(event_id)
    query = f"UPDATE events SET {', '.join(set_clauses)} WHERE id = %s RETURNING *;"
    cursor.execute(query, tuple(params))
    return cursor.fetchone()


def delete_event_db(cursor: psycopg2.extensions.cursor, event_id: int) -> int:
    """Deletes an event."""
    cursor.execute("DELETE FROM events WHERE id = %s;", (event_id,))
    return cursor.rowcount

def join_event_db(cursor: psycopg2.extensions.cursor, event_id: int, user_id: int) -> Optional[int]:
    """Adds a user as an event participant."""
    cursor.execute(
        "INSERT INTO event_participants (event_id, user_id) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING id;",
        (event_id, user_id)
    )
    result = cursor.fetchone()
    return result['id'] if result else None

def leave_event_db(cursor: psycopg2.extensions.cursor, event_id: int, user_id: int) -> Optional[int]:
    """Removes a user from event participants."""
    cursor.execute(
        "DELETE FROM event_participants WHERE event_id = %s AND user_id = %s RETURNING id;",
        (event_id, user_id)
    )
    result = cursor.fetchone()
    return result['id'] if result else None

def get_event_participant_count(cursor: psycopg2.extensions.cursor, event_id: int) -> int:
    """Gets the current participant count for an event."""
    cursor.execute("SELECT COUNT(*) as count FROM event_participants WHERE event_id = %s;", (event_id,))
    result = cursor.fetchone()
    return result['count'] if result else 0


# --- Chat CRUD ---
def create_chat_message_db(cursor: psycopg2.extensions.cursor, user_id: int, content: str, community_id: Optional[int], event_id: Optional[int]) -> Optional[Dict[str, Any]]:
    """Saves a chat message to the database."""
    try:
        cursor.execute(
            """
            INSERT INTO chat_messages (community_id, event_id, user_id, content)
            VALUES (%s, %s, %s, %s) RETURNING id, timestamp;
            """,
            (community_id, event_id, user_id, content)
        )
        result = cursor.fetchone()
        # Fetch username to include in the response (needed by ChatMessageData schema)
        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user_info = cursor.fetchone()
        username = user_info['username'] if user_info else "Unknown"

        return {
            "message_id": result["id"],
            "community_id": community_id,
            "event_id": event_id,
            "user_id": user_id,
            "username": username,
            "content": content,
            "timestamp": result["timestamp"]
        } if result else None
    except Exception as e:
        print(f"Error in create_chat_message_db: {e}")
        raise

def get_chat_messages_db(cursor: psycopg2.extensions.cursor, community_id: Optional[int], event_id: Optional[int], limit: int, before_id: Optional[int]) -> List[Dict[str, Any]]:
    """Fetches chat messages for a community or event."""
    query = """
        SELECT m.id as message_id, m.community_id, m.event_id, m.user_id, m.content, m.timestamp,
               u.username
        FROM chat_messages m
        JOIN users u ON m.user_id = u.id
        WHERE """
    params = []
    filters = []

    if event_id is not None:
        # Fetch messages specifically for the event OR general messages for the event's community
        # This assumes an event always belongs to a community
        filters.append("(m.event_id = %s OR (m.community_id = (SELECT community_id FROM events WHERE id = %s) AND m.event_id IS NULL))")
        params.extend([event_id, event_id])
    elif community_id is not None:
        # Fetch only general community messages (no specific event)
        filters.append("m.community_id = %s AND m.event_id IS NULL")
        params.append(community_id)
    else:
        return [] # Must provide community or event ID

    if before_id is not None:
        filters.append("m.id < %s")
        params.append(before_id)

    query += " AND ".join(filters)
    query += " ORDER BY m.timestamp DESC LIMIT %s;"
    params.append(limit)

    cursor.execute(query, tuple(params))
    return cursor.fetchall()


def follow_user(cursor, follower_id: int, following_id: int) -> bool:
    try:
        cursor.execute("""
            INSERT INTO user_followers (follower_id, following_id)
            VALUES (%s, %s)
            ON CONFLICT DO NOTHING
            RETURNING *
        """, (follower_id, following_id))
        return cursor.rowcount > 0
    except Exception as e:
        print(f"Error following user: {e}")
        return False

def follow_user(cursor, follower_id: int, following_id: int) -> bool:
    try:
        cursor.execute("""
            INSERT INTO user_followers (follower_id, following_id)
            VALUES (%s, %s)
            ON CONFLICT DO NOTHING
            RETURNING *
        """, (follower_id, following_id))
        return cursor.rowcount > 0
    except Exception as e:
        print(f"Error following user: {e}")
        return False
        
def unfollow_user(cursor: psycopg2.extensions.cursor, follower_id: int, following_id: int) -> bool:
    try:
        cursor.execute(
            """
            DELETE FROM user_followers
            WHERE follower_id = %s AND following_id = %s;
            """,
            (follower_id, following_id)
        )
        return cursor.rowcount > 0
    except Exception as e:
        print(f"Error unfollowing user (follower: {follower_id}, following: {following_id}): {e}")
        return False

def get_user_profile(cursor, user_id: int):
    cursor.execute("""
        SELECT u.*, 
            (SELECT COUNT(*) FROM user_followers WHERE following_id = u.id) AS followers_count,
            (SELECT COUNT(*) FROM user_followers WHERE follower_id = u.id) AS following_count
        FROM users u
        WHERE u.id = %s
    """, (user_id,))
    user = cursor.fetchone()
    return None

def get_followers(cursor, user_id: int):
    cursor.execute("""
        SELECT u.id, u.name, u.username, u.image_path
        FROM user_followers f
        JOIN users u ON f.follower_id = u.id
        WHERE f.following_id = %s
    """, (user_id,))
    return cursor.fetchall()

def get_users_in_community(cursor, community_id: int):
    cursor.execute("""
        SELECT u.id, u.name, u.username, u.gender
        FROM community_members cm
        JOIN users u ON cm.user_id = u.id
        WHERE cm.community_id = %s;
    """, (community_id,))
    return cursor.fetchall()