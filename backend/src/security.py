# backend/src/security.py (or add to auth.py)

import os
from fastapi import Security, HTTPException, status
from fastapi.security import APIKeyHeader
from dotenv import load_dotenv

load_dotenv() # Load environment variables

# Define the header name we expect the API key in
API_KEY_HEADER = APIKeyHeader(name="X-API-Key", auto_error=False) # auto_error=False allows custom error handling

# Retrieve the valid API key(s) from environment variables
# For simplicity, we'll use one key here. For multiple keys, use a list or set.
VALID_API_KEY = os.getenv("API_KEY")
if not VALID_API_KEY:
    print("⚠️ WARNING: API_KEY environment variable not set. API key security will fail.")
    # You might want to raise an error or exit in a real application if the key is mandatory
    # raise ValueError("API_KEY environment variable is required but not set.")


async def get_api_key(api_key_header: str = Security(API_KEY_HEADER)):
    """
    Dependency function to validate the API key provided in the X-API-Key header.
    """
    if not api_key_header:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, # Use 401 when key is missing
            detail="Missing API Key in 'X-API-Key' header",
        )

    if api_key_header == VALID_API_KEY:
        # Key is valid, return it (or just return None/True if you only need validation)
        return api_key_header
    else:
        # Key is invalid
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, # Use 403 when key is invalid
            detail="Invalid API Key",
        )

# --- Optional: More robust validation with multiple keys ---
# VALID_API_KEYS = set(filter(None, os.getenv("VALID_API_KEYS", "").split(','))) # Expect comma-separated keys
# async def get_api_key_multiple(api_key_header: str = Security(API_KEY_HEADER)):
#     if not api_key_header:
#         raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing API Key")
#     if api_key_header in VALID_API_KEYS:
#         return api_key_header
#     else:
#         raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid API Key")
# --- End optional multiple key example ---
