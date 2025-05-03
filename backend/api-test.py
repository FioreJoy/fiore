#!/usr/bin/env python
# -*- coding: utf-8 -*-

import requests
import json
from getpass import getpass
from typing import Dict, Any, Optional, List
from datetime import datetime, timezone
import time
import os
from pathlib import Path # For easier path handling
from dotenv import load_dotenv # For reading .env
from minio import Minio # For checking MinIO (optional)
from minio.error import S3Error
import mimetypes # For guessing file type
import traceback # For printing stack traces

# --- Configuration ---
BASE_URL = "http://localhost:1163" # Adjust if your backend runs elsewhere

# --- Load .env ---
# Tries to find .env in common locations relative to the script
dotenv_path_options = [
    Path('.') / '.env',                         # Current directory
    Path(__file__).resolve().parent / '.env',         # Script's directory
    Path(__file__).resolve().parent.parent / '.env'  # Parent of script's directory
]
dotenv_path = next((path for path in dotenv_path_options if path.is_file()), None)

if dotenv_path:
    print(f"Loading environment variables from: {dotenv_path}")
    load_dotenv(dotenv_path=dotenv_path)
else:
    print("Warning: .env file not found in standard locations.")

# --- Credentials and Keys from .env ---
API_KEY = os.getenv("API_KEY")
# Provide defaults for user credentials if not in .env or use inputs
USER_EMAIL_DEFAULT = os.getenv("TEST_USER_EMAIL", "alice@example.com")

# --- Placeholder IDs (MODIFY THESE WITH ACTUAL IDs FROM YOUR DB!) ---
# Ensure these IDs exist in your database and are appropriate for tests
try:
    TARGET_USER_ID_TO_VIEW_AND_BLOCK = int(os.getenv("TEST_TARGET_USER_ID", "2"))
    OTHER_USER_ID_TO_FOLLOW = int(os.getenv("TEST_OTHER_USER_ID", "5"))
    TARGET_COMMUNITY_ID = int(os.getenv("TEST_COMMUNITY_ID", "1"))
    TARGET_POST_ID = int(os.getenv("TEST_POST_ID", "47")) # A post that exists
    TARGET_REPLY_ID = int(os.getenv("TEST_REPLY_ID", "29")) # A reply that exists
    TARGET_EVENT_ID = int(os.getenv("TEST_EVENT_ID", "1"))
    POST_IN_COMMUNITY_ID = int(os.getenv("TEST_POST_IN_COMMUNITY_ID", "10"))
    POST_NOT_IN_COMMUNITY_ID = int(os.getenv("TEST_POST_NOT_IN_COMMUNITY_ID", "45"))
except ValueError:
    print("ERROR: Ensure TEST_* IDs in .env or script are valid integers.")
    exit()
# --- End Placeholder IDs ---

# MinIO Client Setup (Optional - for verification)
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "connections") # Default bucket name
MINIO_USE_SSL = os.getenv("MINIO_USE_SSL", "true").lower() == "true"
minio_client = None
if MINIO_ENDPOINT and MINIO_ACCESS_KEY and MINIO_SECRET_KEY:
    try:
        minio_client = Minio(
            MINIO_ENDPOINT,
            access_key=MINIO_ACCESS_KEY,
            secret_key=MINIO_SECRET_KEY,
            secure=MINIO_USE_SSL
        )
        # Test connection by checking if bucket exists
        print(f"Checking MinIO bucket '{MINIO_BUCKET}'...")
        if not minio_client.bucket_exists(MINIO_BUCKET):
            print(f"Warning: MinIO bucket '{MINIO_BUCKET}' not found!")
            minio_client = None # Disable client if bucket missing
        else:
            print(f"✅ MinIO Client initialized for verification ({MINIO_ENDPOINT}/{MINIO_BUCKET}).")
    except Exception as e:
        print(f"⚠️ Warning: Failed to initialize/connect MinIO client: {e}")
        minio_client = None
else:
    print("⚠️ Warning: MinIO credentials not found in .env. Cannot verify uploads.")

# Store results
results = { "success": [], "failed": [], "skipped": [], }
session = requests.Session() # Use a session for potential connection reuse
auth_token = "" # Stores the JWT token after login
base_headers = {} # Stores common headers (Accept, API Key, Auth)
logged_in_user_id = None # Store logged-in user ID after login
uploaded_media_paths = [] # Store MinIO paths of uploaded files for potential cleanup

def update_headers():
    """Updates base_headers dictionary with current api_key and auth_token."""
    global base_headers
    base_headers = {"Accept": "application/json"}
    if API_KEY: base_headers["X-API-Key"] = API_KEY
    if auth_token: base_headers["Authorization"] = f"Bearer {auth_token}"

# --- make_request Helper Function ---
def make_request(
        method: str, endpoint: str, test_name: str,
        expected_status: List[int] = [200, 201, 204], # Common success codes
        data: Optional[Dict[str, Any]] = None, # For JSON body or Form fields with files
        params: Optional[Dict[str, Any]] = None, # For URL query parameters
        files: Optional[Dict[str, tuple]] = None, # For multipart file uploads: {'field': (filename, content_bytes, mimetype)}
        use_auth: bool = True, # Send Authorization header?
        use_api_key: bool = True, # Send X-API-Key header?
        is_json: bool = True # Treat 'data' as JSON body? (Ignored if 'files' is present)
):
    """Makes an API request, logs details, stores results."""
    global results
    url = f"{BASE_URL}{endpoint}"
    headers = base_headers.copy() # Start with base headers
    # Remove headers conditionally
    if not use_api_key and "X-API-Key" in headers: del headers["X-API-Key"]
    if not use_auth and "Authorization" in headers: del headers["Authorization"]

    # Prepare keyword arguments for requests
    req_kwargs = {"headers": headers, "params": params, "timeout": 30}
    request_body_log = "(None)" # For logging clarity

    # Determine Content-Type and body/files based on method and inputs
    if method.upper() in ["POST", "PUT", "PATCH"]:
        if files:
            # Multipart request
            if "Content-Type" in headers: del headers["Content-Type"] # Let requests library set it
            req_kwargs["data"] = data # Non-file form fields go here
            req_kwargs["files"] = files
            request_body_log = f"(MultipartFormData: Fields={data}, Files={list(files.keys())})"
        elif data:
            if is_json:
                # JSON request
                headers["Content-Type"] = "application/json"
                req_kwargs["json"] = data # requests handles JSON encoding
                request_body_log = f"(JSON Body: {json.dumps(data)})"
            else:
                # Form URL Encoded request (if not JSON and not files)
                headers["Content-Type"] = "application/x-www-form-urlencoded"
                req_kwargs["data"] = data
                request_body_log = f"(FormUrlEncoded Body: {data})"
        elif not data: # No body
            headers["Content-Length"] = "0" # Explicitly set for POST/PUT without body
            if "Content-Type" in headers: del headers["Content-Type"]

    # Update headers in kwargs *after* potential modifications
    req_kwargs["headers"] = headers

    print(f"\n--- Testing: {test_name} ({method.upper()} {endpoint}) ---")
    # print(f"    Headers: {headers}") # Uncomment for verbose header logging
    # print(f"    Params: {params}")   # Uncomment for verbose query param logging
    # print(f"    Body/Files Log: {request_body_log}") # Uncomment for verbose body logging

    try:
        response = session.request(method, url, **req_kwargs)
        print(f"    Status Code: {response.status_code}")
        response_data, response_text = None, ""
        try:
            response_text = response.text
            if response_text:
                response_data = response.json() # Try parsing JSON
                # print(f"    Response JSON: {json.dumps(response_data, indent=2)}") # Uncomment for verbose JSON output
            # else: print("    Response Body: (Empty)")
        except json.JSONDecodeError:
            print(f"    Response Text (Not JSON): {response_text[:300]}...") # Log start of non-JSON response
            response_data = {"error": "Non-JSON response", "content": response_text}

        # Check if status code is one of the expected success codes
        if response.status_code in expected_status:
            print(f"    Result: SUCCESS")
            results["success"].append({"name": test_name, "status": response.status_code})
            return response_data # Return parsed data on success
        else:
            print(f"    Result: FAILED")
            results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {endpoint}", "status": response.status_code, "response": response_data or response_text})
            return None # Return None on failure

    # Handle common request exceptions
    except requests.exceptions.Timeout:
        print(f"    Result: FAILED (Timeout)")
        results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {endpoint}", "status": "Timeout", "response": "Request timed out"})
    except requests.exceptions.ConnectionError as e:
        print(f"    Result: FAILED (Connection Error)")
        results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {endpoint}", "status": "Connection Error", "response": str(e)})
    except Exception as e:
        print(f"    Result: FAILED (Unexpected Script Error: {e})")
        results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {endpoint}", "status": "Script Error", "response": str(e)})
        traceback.print_exc() # Print full traceback for script errors
    return None

# --- Function to verify MinIO upload ---
def verify_minio_upload(object_name: Optional[str]):
    """Checks if an object exists in MinIO. Adds path to list on success."""
    if not minio_client: print(f"    MinIO Check Skipped: Client not configured."); return False
    if not object_name: print(f"    MinIO Check Skipped: No object name provided."); return False

    try:
        print(f"    Verifying MinIO object: {object_name} in bucket '{MINIO_BUCKET}'...")
        minio_client.stat_object(MINIO_BUCKET, object_name)
        print(f"    ✅ MinIO Verification: SUCCESS - Object found.")
        if object_name not in uploaded_media_paths: uploaded_media_paths.append(object_name)
        return True
    except S3Error as e:
        if e.code == 'NoSuchKey': print(f"    ❌ MinIO Verification: FAILED - Object '{object_name}' not found.")
        else: print(f"    ❌ MinIO Verification: ERROR - {e}")
        return False
    except Exception as e: print(f"    ❌ MinIO Verification: UNEXPECTED ERROR - {e}"); return False

# --- Function to clean up MinIO uploads ---
def cleanup_minio_uploads():
    """Deletes files uploaded during the test run from MinIO."""
    if not minio_client or not uploaded_media_paths: return
    print("\n--- Cleaning up uploaded MinIO test files ---")
    from minio.deleteobjects import DeleteObject
    objects_to_delete = [DeleteObject(p) for p in uploaded_media_paths]
    if objects_to_delete:
        try:
            errors = minio_client.remove_objects(MINIO_BUCKET, objects_to_delete)
            error_count = 0
            for error in errors: print(f"    MinIO Delete Error: {error}"); error_count+=1
            deleted_count = len(uploaded_media_paths) - error_count
            print(f"--- MinIO Cleanup: Deleted {deleted_count}/{len(uploaded_media_paths)} objects ---")
            uploaded_media_paths.clear() # Clear list after attempt
        except Exception as e: print(f"--- MinIO Cleanup: ERROR during bulk delete - {e} ---")


# --- Main Test Execution Function ---
def run_tests():
    global api_key, auth_token, base_headers, logged_in_user_id, USER_EMAIL_DEFAULT
    print("--- API Endpoint Test Script ---")
    # --- Get Credentials & Image Path ---
    api_key_env = os.getenv("API_KEY")
    api_key_input = input(f"Enter API Key [{api_key_env or 'REQUIRED'}]: ")
    api_key = api_key_input or api_key_env
    if not api_key: print("API Key is required."); exit()

    email_input = input(f"Enter Test User Email [Default: {USER_EMAIL_DEFAULT}]: ")
    password_input = getpass(f"Enter Password for {email_input or USER_EMAIL_DEFAULT}: ")
    test_email = email_input or USER_EMAIL_DEFAULT
    test_password = password_input
    if not test_password: print("Password is required."); exit()

    image_path_input = input("Enter ABSOLUTE path to a test image (e.g., /path/to/test.jpg) [Leave blank to skip image tests]: ")
    test_image_path = Path(image_path_input) if image_path_input else None
    image_file_content = None; image_filename = None; image_content_type = None
    if test_image_path and test_image_path.is_file():
        try:
            image_filename = test_image_path.name
            image_file_content = test_image_path.read_bytes()
            content_type, _ = mimetypes.guess_type(image_filename)
            image_content_type = content_type or 'application/octet-stream'
            print(f"✅ Test image ready: {test_image_path} ({image_content_type})")
        except Exception as e: print(f"⚠️ Warning: Could not read test image file '{test_image_path}': {e}"); test_image_path = None
    elif image_path_input: print(f"⚠️ Warning: Test image path '{image_path_input}' not found."); test_image_path = None

    update_headers() # Initial headers with API Key

    # === 1. Authentication ===
    print("\n--- Section: Authentication ---")
    login_data = {"email": test_email, "password": test_password}
    login_response = make_request("POST", "/auth/login", "User Login", data=login_data, use_auth=False, is_json=True) # Login uses JSON

    if login_response and login_response.get("token"):
        auth_token = login_response.get("token"); logged_in_user_id = login_response.get("user_id")
        print(f"\n*** Logged in as User ID: {logged_in_user_id}. Token acquired. ***")
        update_headers()
    else: print("\n*** Login Failed. Cannot proceed. ***"); print_summary(); exit()

    make_request("GET", "/auth/me", "Get Current User Profile")

    # --- Update Profile (Multipart Form) ---
    update_profile_fields = { "college": f"API Test College {datetime.now().second}" }
    update_profile_files = None
    test_name_profile = "Update User Profile (Form w/o Image)"
    if test_image_path and image_filename and image_file_content and image_content_type:
        # Create the tuple needed by 'requests' files kwarg
        update_profile_files = {'image': (image_filename, image_file_content, image_content_type)}
        test_name_profile = "Update User Profile (Form w/ Image)"
    else: results["skipped"].append({"name": "Update Profile Picture"})

    # Profile update endpoint expects multipart/form-data
    profile_update_response = make_request("PUT", "/auth/me", test_name_profile, data=update_profile_fields, files=update_profile_files, is_json=False)
    if profile_update_response and update_profile_files:
        # Verify upload based on response (assuming it includes the new path)
        new_avatar_path = profile_update_response.get('image_path') # Check actual response key
        verify_minio_upload(new_avatar_path)

    results["skipped"].append({"name": "Change Password"}) # Skipping password change test

    # === 2. Users ===
    print("\n--- Section: Users ---")
    if logged_in_user_id is None: print("ERROR: Logged in user ID not set."); exit()
    if TARGET_USER_ID_TO_VIEW_AND_BLOCK == logged_in_user_id or OTHER_USER_ID_TO_FOLLOW == logged_in_user_id:
        print("\nERROR: Placeholder IDs must differ from logged in user."); exit()

    make_request("GET", f"/users/{TARGET_USER_ID_TO_VIEW_AND_BLOCK}", f"Get Profile User {TARGET_USER_ID_TO_VIEW_AND_BLOCK}")
    # Follow/Unfollow Tests
    make_request("POST", f"/users/{OTHER_USER_ID_TO_FOLLOW}/follow", f"Follow User {OTHER_USER_ID_TO_FOLLOW}", data=None) # No body needed
    make_request("GET", f"/users/{logged_in_user_id}/following", f"Get My Following List")
    make_request("GET", f"/users/{OTHER_USER_ID_TO_FOLLOW}/followers", f"Get Followers List User {OTHER_USER_ID_TO_FOLLOW}")
    make_request("DELETE", f"/users/{OTHER_USER_ID_TO_FOLLOW}/follow", f"Unfollow User {OTHER_USER_ID_TO_FOLLOW}")
    # Blocking Tests
    make_request("POST", f"/users/me/block/{TARGET_USER_ID_TO_VIEW_AND_BLOCK}", f"Block User {TARGET_USER_ID_TO_VIEW_AND_BLOCK}", expected_status=[204])
    time.sleep(0.5)
    make_request("GET", "/users/me/blocked", "Get Blocked Users (After Block)")
    make_request("DELETE", f"/users/me/unblock/{TARGET_USER_ID_TO_VIEW_AND_BLOCK}", f"Unblock User {TARGET_USER_ID_TO_VIEW_AND_BLOCK}", expected_status=[204])
    time.sleep(0.5)
    make_request("GET", "/users/me/blocked", "Get Blocked Users (After Unblock)")
    # Other User Endpoints
    make_request("GET", "/users/me/communities", "Get My Joined Communities")
    make_request("GET", "/users/me/events", "Get My Joined Events")
    make_request("GET", "/users/me/stats", "Get My Stats")


    # === 3. Communities ===
    print("\n--- Section: Communities ---")
    make_request("GET", "/communities", "List Communities")
    make_request("GET", "/communities/trending", "List Trending Communities", expected_status=[200, 405])
    make_request("GET", f"/communities/{TARGET_COMMUNITY_ID}/details", f"Get Community {TARGET_COMMUNITY_ID} Details")
    make_request("POST", f"/communities/{TARGET_COMMUNITY_ID}/join", f"Join Community {TARGET_COMMUNITY_ID}", data=None)
    make_request("DELETE", f"/communities/{TARGET_COMMUNITY_ID}/leave", f"Leave Community {TARGET_COMMUNITY_ID}", data=None)
    make_request("POST", f"/communities/{TARGET_COMMUNITY_ID}/posts/{POST_NOT_IN_COMMUNITY_ID}", f"Add Post {POST_NOT_IN_COMMUNITY_ID} to Community {TARGET_COMMUNITY_ID}", data=None)
    make_request("DELETE", f"/communities/{TARGET_COMMUNITY_ID}/posts/{POST_NOT_IN_COMMUNITY_ID}", f"Remove Post {POST_NOT_IN_COMMUNITY_ID} from Community {TARGET_COMMUNITY_ID}", data=None)
    make_request("GET", f"/communities/{TARGET_COMMUNITY_ID}/events", f"List Events for Community {TARGET_COMMUNITY_ID}")
    # Test Update Community Logo
    if test_image_path and image_filename and image_file_content and image_content_type:
        logo_files = {'logo': (image_filename, image_file_content, image_content_type)}
        logo_update_resp = make_request("POST", f"/communities/{TARGET_COMMUNITY_ID}/logo", f"Update Community {TARGET_COMMUNITY_ID} Logo", files=logo_files, is_json=False)
        if logo_update_resp:
            # Expecting full CommunityDisplay schema, logo_path might be nested or direct
            verify_minio_upload(logo_update_resp.get('logo_path') or logo_update_resp.get('logo', {}).get('minio_object_name'))
    else: results["skipped"].append({"name": "Update Community Logo"})


    # === 4. Events ===
    print("\n--- Section: Events ---")
    make_request("GET", f"/events/{TARGET_EVENT_ID}", f"Get Event {TARGET_EVENT_ID} Details")
    make_request("POST", f"/events/{TARGET_EVENT_ID}/join", f"Join Event {TARGET_EVENT_ID}", data=None)
    make_request("DELETE", f"/events/{TARGET_EVENT_ID}/leave", f"Leave Event {TARGET_EVENT_ID}", data=None)


    # === 5. Posts ===
    print("\n--- Section: Posts ---")
    # Test Create Post
    post_fields = {"title": f"Test Post {datetime.now()}", "content": "Testing media!", "community_id": str(TARGET_COMMUNITY_ID)}
    post_files = None
    test_name_post = "Create Post (No Image)"
    if test_image_path and image_filename and image_file_content and image_content_type:
        # Backend expects 'files: List[UploadFile] = File(...)'
        # 'requests' needs unique keys for 'files' dict, but FastAPI groups by field name.
        # Send as 'files' if backend expects exactly that name, or 'image' if it expects 'image'
        post_files = {'files': (image_filename, image_file_content, image_content_type)} # Use 'files' as key if needed
        # Or post_files = {'image': (...)} if that's the FastAPI parameter name
        test_name_post = "Create Post (With Image)"
    else: results["skipped"].append({"name": "Create Post With Image"})

    created_post_resp = make_request("POST", "/posts", test_name_post, data=post_fields, files=post_files, is_json=False) # Send as multipart/form-data
    # Verify upload based on response structure (assuming 'media' list)
    if created_post_resp and post_files:
        media_list = created_post_resp.get('media')
        if isinstance(media_list, list) and len(media_list) > 0 and isinstance(media_list[0], dict):
            verify_minio_upload(media_list[0].get('minio_object_name'))
        else: print("    WARN: Create post response missing expected media list.")

    # Other post tests
    make_request("GET", "/posts", "List Posts (General)", params={"limit": 5})
    make_request("GET", "/posts", f"List Posts (Community {TARGET_COMMUNITY_ID})", params={"community_id": TARGET_COMMUNITY_ID, "limit": 5})
    make_request("GET", "/posts", f"List Posts (User {TARGET_USER_ID_TO_VIEW_AND_BLOCK})", params={"user_id": TARGET_USER_ID_TO_VIEW_AND_BLOCK, "limit": 5})
    make_request("GET", "/posts/trending", "List Trending Posts", expected_status=[200, 405])
    make_request("POST", f"/posts/{TARGET_POST_ID}/favorite", f"Favorite Post {TARGET_POST_ID}", data=None)
    make_request("DELETE", f"/posts/{TARGET_POST_ID}/favorite", f"Unfavorite Post {TARGET_POST_ID}", data=None)


    # === 6. Replies ===
    print("\n--- Section: Replies ---")
    make_request("GET", f"/replies/{TARGET_POST_ID}", f"List Replies for Post {TARGET_POST_ID}")
    reply_data = {"post_id": TARGET_POST_ID, "content": f"Test reply {datetime.now()}"}
    make_request("POST", "/replies", f"Create Reply for Post {TARGET_POST_ID}", data=reply_data, is_json=True) # Replies likely use JSON
    make_request("POST", f"/replies/{TARGET_REPLY_ID}/favorite", f"Favorite Reply {TARGET_REPLY_ID}", data=None)
    make_request("DELETE", f"/replies/{TARGET_REPLY_ID}/favorite", f"Unfavorite Reply {TARGET_REPLY_ID}", data=None)


    # === 7. Votes ===
    print("\n--- Section: Votes ---")
    vote_post_up = {"post_id": TARGET_POST_ID, "reply_id": None, "vote_type": True}
    vote_post_down = {"post_id": TARGET_POST_ID, "reply_id": None, "vote_type": False}
    vote_reply_up = {"post_id": None, "reply_id": TARGET_REPLY_ID, "vote_type": True}
    make_request("POST", "/votes", f"Upvote Post {TARGET_POST_ID}", data=vote_post_up, is_json=True)
    make_request("POST", "/votes", f"Downvote Post {TARGET_POST_ID}", data=vote_post_down, is_json=True)
    make_request("POST", "/votes", f"Remove Vote Post {TARGET_POST_ID}", data=vote_post_down, is_json=True) # Send same again
    make_request("POST", "/votes", f"Upvote Reply {TARGET_REPLY_ID}", data=vote_reply_up, is_json=True)


    # === 8. Chat ===
    print("\n--- Section: Chat ---")
    make_request("GET", "/chat/messages", f"Get Chat History (Community {TARGET_COMMUNITY_ID})", params={"community_id": TARGET_COMMUNITY_ID, "limit": 5})
    make_request("GET", "/chat/messages", f"Get Chat History (Event {TARGET_EVENT_ID})", params={"event_id": TARGET_EVENT_ID, "limit": 5})
    chat_data = {"content": f"Test HTTP message from script {datetime.now()}"}
    make_request("POST", "/chat/messages", f"Send HTTP Chat (Community {TARGET_COMMUNITY_ID})", params={"community_id": TARGET_COMMUNITY_ID}, data=chat_data, is_json=True)


    # === 9. Settings ===
    print("\n--- Section: Settings ---")
    make_request("GET", "/settings/notifications", "Get Notification Settings", expected_status=[200]) # Expect 200 now
    settings_data = { "new_post_in_community": False, "new_reply_to_post": True, "new_event_in_community": True, "event_reminder": False, "direct_message": True } # Include all fields from schema
    make_request("PUT", "/settings/notifications", "Update Notification Settings", data=settings_data, is_json=True)


    # === 10. GraphQL ===
    print("\n--- Section: GraphQL ---")
    gql_query_viewer = {"query": "query { viewer { id username name followersCount } }"}
    gql_query_user_target = { "query": "query GetUser($userId: ID!) { user(id: $userId) { id username name followersCount isFollowedByViewer } }", "variables": {"userId": str(TARGET_USER_ID_TO_VIEW_AND_BLOCK)} }
    make_request("POST", "/graphql", "GraphQL Get Viewer", data=gql_query_viewer, use_api_key=False, is_json=True) # GQL uses JSON
    make_request("POST", "/graphql", f"GraphQL Get User {TARGET_USER_ID_TO_VIEW_AND_BLOCK}", data=gql_query_user_target, use_api_key=False, is_json=True)


def print_summary():
    """Prints a summary of successful and failed tests."""
    print("\n\n" + "="*30 + " TEST SUMMARY " + "="*30)
    success_count=len(results['success']);failed_count=len(results['failed']);skipped_count=len(results['skipped']);total_run=success_count+failed_count
    print(f"TOTAL TESTS DEFINED: {total_run + skipped_count}")
    print(f"TOTAL TESTS RUN:     {total_run}")
    print(f"SUCCESSFUL:          {success_count}")
    print(f"FAILED:              {failed_count}")
    print(f"SKIPPED:             {skipped_count}")
    if results["failed"]:
        print("\n--- FAILED ENDPOINTS ---")
        for i, failure in enumerate(results["failed"]):
            print(f"\n{i+1}. Test Name: {failure['name']}")
            print(f"   Endpoint:  {failure['endpoint']}")
            print(f"   Status:    {failure['status']}")
            response_content = failure['response']
            try:
                # Attempt to format nicely if it's JSON-like string or dict/list
                if isinstance(response_content,(dict,list)): print(f"   Response:  {json.dumps(response_content, indent=2)}")
                elif isinstance(response_content, str):
                    try: print(f"   Response:  {json.dumps(json.loads(response_content), indent=2)}")
                    except json.JSONDecodeError: print(f"   Response:  {response_content[:500]}...") # Limit length
                else: print(f"   Response:  {str(response_content)[:500]}...")
            except Exception: print(f"   Response:  {str(response_content)[:500]}...")
    elif total_run > 0: print("\n--- ALL EXECUTED TESTS PASSED ---")
    else: print("\n--- NO TESTS WERE EXECUTED ---")
    if results["skipped"]: print("\n--- SKIPPED TESTS ---"); [print(f"{i+1}. {s['name']}") for i, s in enumerate(results["skipped"])]
    print("="*74)


# --- Main Execution ---
if __name__ == "__main__":
    image_file_handle = None # Keep track of opened file
    try:
        # --- Prepare image file details if path provided ---
        image_path_input = input("Enter ABSOLUTE path to a test image (e.g., /path/to/test.jpg) [Leave blank to skip image tests]: ")
        test_image_path = Path(image_path_input) if image_path_input else None
        test_image_file_details = None
        if test_image_path and test_image_path.is_file():
            try:
                image_filename = test_image_path.name
                image_file_handle = open(test_image_path, 'rb') # Open file handle
                image_file_content = image_file_handle.read() # Read content
                content_type, _ = mimetypes.guess_type(image_filename)
                image_content_type = content_type or 'application/octet-stream'
                # Store tuple for requests, including handle (requests closes it)
                test_image_file_details = (image_filename, image_file_content, image_content_type)
                print(f"✅ Test image ready: {test_image_path} ({image_content_type})")
            except Exception as e:
                print(f"⚠️ Warning: Could not read/prepare test image file '{test_image_path}': {e}")
                if image_file_handle: image_file_handle.close()
                test_image_file_details = None
        elif image_path_input:
            print(f"⚠️ Warning: Test image path '{image_path_input}' not found or is not a file.")
            test_image_file_details = None

        run_tests() # Pass image details tuple to run_tests if needed directly, or use global

    finally:
        # Clean up MinIO uploads
        # Uncomment carefully after verifying tests work
        # cleanup_minio_uploads()

        # Close the image file handle if it was opened
        if image_file_handle:
            try: image_file_handle.close()
            except: pass

        print_summary()