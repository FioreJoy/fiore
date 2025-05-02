# backend/src/auth.py
import os
from datetime import datetime, timedelta, timezone
from typing import Optional
import jwt
from fastapi import Depends, HTTPException, status, Header # Added Header
from fastapi.security import OAuth2PasswordBearer
from jwt import PyJWTError, ExpiredSignatureError, InvalidTokenError
from dotenv import load_dotenv

# Import DB helpers (assuming direct usage or through crud)
from .database import get_db_connection, update_last_seen
# from . import crud # If crud functions are used within auth

load_dotenv()

SECRET_KEY = os.getenv("JWT_SECRET", "please_change_this_strong_secret_key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 # 7 days expiration

# --- Existing Functions ---

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(authorization: str = Header(...)) -> int:
    """
    Dependency to get the current user ID from the Authorization header.
    Raises HTTPException 401 if token is invalid, missing, or expired.
    Updates the user's last_seen timestamp.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    expired_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token has expired",
        headers={"WWW-Authenticate": "Bearer"},
    )
    invalid_format_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid token format",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not authorization or not authorization.startswith("Bearer "):
        print("Auth Error: Invalid token format or missing Authorization header")
        raise invalid_format_exception

    token = authorization.split("Bearer ")[1]

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id_from_payload: Optional[str] = payload.get("user_id") # Use Optional[str] initially
        if user_id_from_payload is None:
            print("Auth Error: Token payload missing 'user_id'")
            raise credentials_exception

        user_id = int(user_id_from_payload) # Convert to int
        print(f"Auth Success: Token validated for User ID: {user_id}")

        # Update last_seen timestamp
        # Note: Calling DB directly here might be less ideal than a background task
        # Consider potential performance impact under heavy load.
        try:
            update_last_seen(user_id)
        except Exception as db_err:
            # Log the error but don't fail the auth request itself
            print(f"Auth Warning: Failed to update last_seen for user {user_id}: {db_err}")

        return user_id
    except ExpiredSignatureError:
        print("Auth Error: Token expired")
        raise expired_exception
    except InvalidTokenError as e:
        print(f"Auth Error: Invalid Token - {e}")
        raise credentials_exception
    except ValueError: # Handle error if user_id_from_payload cannot be cast to int
        print(f"Auth Error: Invalid user_id format in token payload.")
        raise credentials_exception
    except Exception as e:
        print(f"Auth Error: Unexpected error during token validation: {e}")
        raise credentials_exception

# --- *** ADD THIS NEW FUNCTION *** ---
async def get_current_user_optional(authorization: Optional[str] = Header(None)) -> Optional[int]:
    """
    Dependency to optionally get the current user ID.
    Returns user ID if token is valid, None otherwise. Does NOT raise HTTPException.
    """
    if not authorization or not authorization.startswith("Bearer "):
        # No valid header provided, treat as anonymous
        return None
    token = authorization.split("Bearer ")[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id_from_payload = payload.get("user_id")
        if user_id_from_payload is None:
            print("Auth Optional Warning: Token payload missing 'user_id'")
            return None

        user_id = int(user_id_from_payload)

        # Optional: Update last_seen even for optional checks if desired
        # try:
        #     update_last_seen(user_id)
        # except Exception as db_err:
        #     print(f"Auth Optional Warning: Failed last_seen update for user {user_id}: {db_err}")

        print(f"Auth Optional Success: Found User ID: {user_id}")
        return user_id
    except ExpiredSignatureError:
        print("Auth Optional Info: Token expired.")
        return None
    except (jwt.PyJWTError, ValueError):
        # Includes InvalidTokenError and potential int conversion error
        print("Auth Optional Warning: Invalid token or user_id format.")
        return None
    except Exception as e:
        print(f"Auth Optional Error: Unexpected error during token validation: {e}")
        return None
# --- *** END OF NEW FUNCTION *** ---