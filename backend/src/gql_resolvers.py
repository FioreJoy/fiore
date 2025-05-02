# backend/src/gql_resolvers.py
from typing import Optional, List # Add List
import strawberry # Add this import
from . import crud, utils # Assuming crud and utils are in the same directory level
from .database import get_db_connection
from .gql_types import UserType, LocationType # Import the GraphQL types
# Import other types if you define them (PostType, etc.)

# Helper function to convert DB data to GraphQL UserType
def map_db_user_to_gql_user(db_user: Optional[dict]) -> Optional[UserType]:
    if not db_user:
        return None

    # Convert db RealDictRow to regular dict if needed
    user_data = dict(db_user)

    # Parse location point string from DB -> LocationType object
    location_obj: Optional[LocationType] = None
    location_point_str = user_data.get('current_location')
    if location_point_str:
        location_dict = utils.parse_point_string(str(location_point_str))
        if location_dict:
            location_obj = LocationType(
                longitude=location_dict['longitude'],
                latitude=location_dict['latitude']
            )

    # Construct and return the Strawberry UserType
    return UserType(
        id=strawberry.ID(str(user_data.get('id'))), # Convert int ID to str for strawberry.ID
        name=user_data.get('name', ''),
        username=user_data.get('username', ''),
        email=user_data.get('email', ''), # Exposing email - ensure this is intended
        gender=user_data.get('gender', ''),
        college=user_data.get('college'),
        interest=user_data.get('interest'), # Assuming DB stores comma-sep string
        image_url=utils.get_minio_url(user_data.get('image_path')), # Generate URL
        current_location=location_obj,
        current_location_address=user_data.get('current_location_address'), # Get address string
        created_at=user_data.get('created_at', datetime.now()), # Provide default if missing
        last_seen=user_data.get('last_seen'),
        followers_count=user_data.get('followers_count', 0), # Get counts from DB data
        following_count=user_data.get('following_count', 0)
        # NOTE: Does not split 'interest' string into List[str] here.
        # If gql_types.UserType had `interests: List[str]`, you'd do the split here.
    )


# Resolver function for the 'user' query
async def get_user(id: strawberry.ID) -> Optional[UserType]:
    print(f"GraphQL Resolver: get_user called for ID: {id}")
    conn = None
    try:
        user_id_int = int(id) # Convert GraphQL ID (string) back to int for DB query
        conn = get_db_connection()
        cursor = conn.cursor()
        # Use the CRUD function that fetches counts
        db_user = crud.get_user_profile(cursor, user_id_int) # Use raw data fetch
        return map_db_user_to_gql_user(db_user) # Map to GQL type
    except ValueError:
        print(f"GraphQL Resolver Error: Invalid ID format '{id}'")
        return None # Or raise specific GraphQL error
    except Exception as e:
        print(f"GraphQL Resolver Error fetching user {id}: {e}")
        # In production, you might want structured logging and potentially
        # return a generic error to the client instead of raising raw exceptions.
        # raise e # Or return None / specific GraphQL error type
        return None
    finally:
        if conn:
            conn.close()

# --- Add other resolvers as needed for posts, communities, etc. ---
# Example:
# async def get_posts(limit: int = 10) -> List[PostType]:
#     # Fetch posts using crud.get_posts_db
#     # Map results to List[PostType] (similar helper function map_db_post_to_gql_post)
#     pass
