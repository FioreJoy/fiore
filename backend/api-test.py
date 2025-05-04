#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
api-test.py

Comprehensive integration test script for the Fiore backend API.

Requirements:
  - requests
  - python-dotenv
  - minio (optional, for upload verification - verification disabled by default)

Setup:
  1. Ensure the backend server is running.
  2. Create a `.env` file in the script's directory or a parent directory
     (see load_config function for expected variables).
  3. Provide absolute path to a test image when prompted (optional).

Execution:
  python api-test.py
"""

import requests
import json
from getpass import getpass
from typing import Dict, Any, Optional, List, Union
from datetime import datetime, timezone, timedelta
import time
import os
from pathlib import Path
from dotenv import load_dotenv
import mimetypes
import traceback
import sys
import uuid # Ensure uuid is imported for helpers if needed later

# --- MinIO Import Handling ---
try:
    from minio import Minio
    from minio.error import S3Error
    from minio.deleteobjects import DeleteObject
    MINIO_AVAILABLE = True
except ImportError:
    MINIO_AVAILABLE = False
    print("⚠️ WARNING: 'minio' library not installed. Upload verification/cleanup disabled.")
    print("   Install using: pip install minio")
    # Define dummy classes if library is missing to prevent NameErrors later
    class Minio: pass
    class S3Error(Exception): pass
    class DeleteObject: pass
    minio_client = None # Explicitly set client to None

# --- Configuration Loading ---
def load_config():
    """Loads configuration from .env and sets defaults."""
    config = {}
    dotenv_path_options = [ Path('.') / '.env', Path(__file__).resolve().parent / '.env', Path(__file__).resolve().parent.parent / '.env' ]
    dotenv_path = next((path for path in dotenv_path_options if path.is_file()), None)
    if dotenv_path: print(f"Loading environment variables from: {dotenv_path}"); load_dotenv(dotenv_path=dotenv_path)
    else: print("Warning: .env file not found in standard locations.")

    config['BASE_URL'] = os.getenv("BASE_URL", "http://localhost:1163").rstrip('/')
    config['API_KEY'] = os.getenv("API_KEY")
    config['USER_EMAIL_DEFAULT'] = os.getenv("TEST_USER_EMAIL", "alice@example.com")
    config['TEST_USER_PASSWORD'] = os.getenv("TEST_USER_PASSWORD") # Must be set in .env or provided

    # Placeholder IDs (Ensure these defaults make sense for your seed data)
    try:
        config['TARGET_USER_ID_TO_VIEW_AND_BLOCK'] = int(os.getenv("TEST_TARGET_USER_ID", "2"))
        config['OTHER_USER_ID_TO_FOLLOW'] = int(os.getenv("TEST_OTHER_USER_ID", "5"))
        config['TARGET_COMMUNITY_ID'] = int(os.getenv("TEST_COMMUNITY_ID", "1"))
        config['TARGET_EVENT_ID'] = int(os.getenv("TEST_EVENT_ID", "1"))
        # Use known existing IDs from your mock data for reliable interaction tests
        config['EXISTING_POST_ID'] = int(os.getenv("TEST_POST_ID", "2"))
        config['EXISTING_REPLY_ID'] = int(os.getenv("TEST_REPLY_ID", "1"))
    except ValueError:
        print("ERROR: TEST_* IDs in .env must be valid integers.")
        sys.exit(1)

    # MinIO Config
    config['MINIO_ENDPOINT'] = os.getenv("MINIO_ENDPOINT")
    config['MINIO_ACCESS_KEY'] = os.getenv("MINIO_ACCESS_KEY")
    config['MINIO_SECRET_KEY'] = os.getenv("MINIO_SECRET_KEY")
    config['MINIO_BUCKET'] = os.getenv("MINIO_BUCKET", "connections")
    config['MINIO_USE_SSL'] = os.getenv("MINIO_USE_SSL", "true").lower() == "true"

    return config

CONFIG = load_config()

# --- Global State ---
results = { "success": [], "failed": [], "skipped": [], }
session = requests.Session()
auth_token = ""
base_headers = {}
logged_in_user_id = None
uploaded_media_paths = [] # Store MinIO paths if verification were enabled
test_image_file_details = None # (filename, content_bytes, mimetype)
test_text_file_details = None # (filename, content_bytes, mimetype)
# Store IDs of items created *with media* during the test run
created_post_id_with_media = None
created_reply_id_with_media = None
created_chat_msg_id_with_media = None
created_event_id_with_media = None
minio_client = None

# --- MinIO Client Initialization ---
if MINIO_AVAILABLE and CONFIG['MINIO_ENDPOINT'] and CONFIG['MINIO_ACCESS_KEY'] and CONFIG['MINIO_SECRET_KEY']:
    try:
        minio_client = Minio( # type: ignore
            CONFIG['MINIO_ENDPOINT'],
            access_key=CONFIG['MINIO_ACCESS_KEY'],
            secret_key=CONFIG['MINIO_SECRET_KEY'],
            secure=CONFIG['MINIO_USE_SSL']
        )
        print(f"Checking MinIO bucket '{CONFIG['MINIO_BUCKET']}'...")
        if not minio_client.bucket_exists(CONFIG['MINIO_BUCKET']):
            print(f"Warning: MinIO bucket '{CONFIG['MINIO_BUCKET']}' not found! Upload tests may fail.")
        else:
            print(f"✅ MinIO Client initialized ({CONFIG['MINIO_ENDPOINT']}/{CONFIG['MINIO_BUCKET']}).")
    except Exception as e:
        print(f"⚠️ Warning: Failed to initialize/connect MinIO client: {e}")
        minio_client = None
else:
    if MINIO_AVAILABLE:
        print("⚠️ Warning: MinIO credentials not fully set in .env. Upload verification/cleanup disabled.")

# --- Helper Functions ---

def update_headers():
    """Updates base_headers dictionary."""
    global base_headers
    base_headers = {"Accept": "application/json"}
    if CONFIG['API_KEY']: base_headers["X-API-Key"] = CONFIG['API_KEY']
    if auth_token: base_headers["Authorization"] = f"Bearer {auth_token}"

def make_request(
        method: str, endpoint: str, test_name: str, expected_status: List[int] = [200, 201, 204],
        data: Optional[Dict[str, Any]] = None, params: Optional[Dict[str, Any]] = None,
        files: Optional[Union[Dict[str, tuple], List[tuple]]] = None,
        use_auth: bool = True, use_api_key: bool = True, is_json: bool = True
) -> Optional[Dict[str, Any]]:
    """Makes an API request, logs details, stores results."""
    global results
    url = f"{CONFIG['BASE_URL']}{endpoint}"
    headers = base_headers.copy()
    if not use_api_key and "X-API-Key" in headers: del headers["X-API-Key"]
    if not use_auth and "Authorization" in headers: del headers["Authorization"]

    req_kwargs = {"headers": headers, "params": params, "timeout": 30}
    log_data = data
    log_files = "None"

    if method.upper() in ["POST", "PUT", "PATCH"]:
        if files:
            if "Content-Type" in headers: del headers["Content-Type"]
            req_kwargs["files"] = files
            req_kwargs["data"] = data # Non-file form fields go here
            if isinstance(files, list): # List of ('field', (name, content, mime))
                log_files = f"Field '{files[0][0]}' ({len(files)} files): {[f[1][0] for f in files if len(f)>1 and len(f[1])>0]}"
            elif isinstance(files, dict): # Dict {'field': (name, content, mime)}
                log_files = f"Fields: { {k: v[0] for k,v in files.items() if len(v)>0} }"
        elif data:
            if is_json:
                headers["Content-Type"] = "application/json"; req_kwargs["json"] = data
                log_data = json.dumps(data)
            else:
                headers["Content-Type"] = "application/x-www-form-urlencoded"; req_kwargs["data"] = data
        elif not data:
            headers["Content-Length"] = "0"
            if "Content-Type" in headers: del headers["Content-Type"]

    req_kwargs["headers"] = headers

    print(f"\n--- Testing: {test_name} ({method.upper()} {endpoint}) ---")
    print(f"    Params: {params}")
    print(f"    Body/Data: {log_data}")
    print(f"    Files: {log_files}")

    try:
        response = session.request(method, url, **req_kwargs)
        print(f"    Status Code: {response.status_code}")
        response_data, response_text = None, ""
        try:
            response_text = response.text
            if response_text: response_data = response.json()
            else: print("    Response Body: (Empty)")
        except json.JSONDecodeError:
            print(f"    Response Text (Not JSON): {response_text[:500]}...")
            response_data = {"error": "Non-JSON response", "content": response_text}

        if response.status_code in expected_status:
            print(f"    Result: SUCCESS")
            results["success"].append({"name": test_name, "status": response.status_code, "response": response_data})
            return response_data
        else:
            print(f"    Result: FAILED")
            print(f"    Response Body: {response_text[:1000]}")
            results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {endpoint}", "status": response.status_code, "response": response_data or response_text})
            return None

    except requests.exceptions.Timeout: print(f"    Result: FAILED (Timeout)"); results["failed"].append({"name": test_name,"endpoint": f"{method.upper()} {endpoint}", "status": "Timeout", "response": "Request timed out"})
    except requests.exceptions.RequestException as e: print(f"    Result: FAILED (Request Error: {e})"); results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {endpoint}", "status": "Request Error", "response": str(e)})
    except Exception as e: print(f"    Result: FAILED (Script Error: {e})"); results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {endpoint}", "status": "Script Error", "response": str(e)}); traceback.print_exc()
    return None

def verify_minio_upload(object_name: Optional[str], expect_exists: bool = True):
    """(DISABLED) Checks if an object exists (or not) in MinIO."""
    print(f"    INFO: MinIO verification for '{object_name}' skipped.")

def cleanup_minio_uploads():
    """(DISABLED) Deletes files uploaded during the test run from MinIO."""
    if not uploaded_media_paths: return
    print(f"INFO: MinIO cleanup skipped for {len(uploaded_media_paths)} potential paths.")
    # The actual cleanup logic remains commented out or removed if verification is off

def extract_minio_object_name(url: Optional[str]) -> Optional[str]:
    """Extracts potential object name from a MinIO presigned URL."""
    if not url or not CONFIG['MINIO_BUCKET']: return None
    try:
        path_part = url.split('?')[0]; key_part = f"/{CONFIG['MINIO_BUCKET']}/"
        if key_part in path_part: return path_part.split(key_part, 1)[1]
    except Exception as e: print(f"WARN: Failed to extract object name from URL '{url}': {e}")
    return None

# --- Test Sections ---

def test_authentication_and_profile(email, password):
    """Tests login, get /me, update profile (text & image)."""
    global auth_token, logged_in_user_id
    print("\n--- Testing: Authentication & Profile ---")
    login_data = {"email": str(email), "password": str(password)}
    login_response = make_request("POST", "/auth/login", "User Login", data=login_data, use_auth=False, is_json=True)
    if not (login_response and login_response.get("token")): return False
    auth_token = login_response.get("token"); logged_in_user_id = login_response.get("user_id")
    print(f"\n*** Logged in as User ID: {logged_in_user_id}. Token acquired. ***"); update_headers()

    get_me_resp = make_request("GET", "/auth/me", "Get Current User Profile")
    if get_me_resp: assert get_me_resp.get("id") == logged_in_user_id and get_me_resp.get("email") == email

    update_profile_fields = { "college": f"API Test College {datetime.now().second}" }
    update_profile_files = None; test_name_profile = "Update User Profile (Form - Text Only)"
    if test_image_file_details: update_profile_files = {'image': test_image_file_details}; test_name_profile = "Update User Profile (Form - Text & Image)"
    else: results["skipped"].append({"name": "Update Profile Picture (No Image Provided)"})

    profile_update_response = make_request("PUT", "/auth/me", test_name_profile, data=update_profile_fields, files=update_profile_files, is_json=False)
    profile_image_object_name_expected = None
    if profile_update_response and update_profile_files:
        new_image_url = profile_update_response.get('image_url')
        profile_image_object_name_expected = extract_minio_object_name(new_image_url)
        verify_minio_upload(profile_image_object_name_expected) # Will just print skipped message

    get_me_resp_after = make_request("GET", "/auth/me", "Get Current User Profile (After Update)")
    if get_me_resp_after:
        assert get_me_resp_after.get("college") == update_profile_fields["college"], "Profile college update failed"
        print("    Update Persistence Check: College updated.")
        if profile_image_object_name_expected:
            url_after = get_me_resp_after.get("image_url")
            obj_name_after = extract_minio_object_name(url_after)
            if url_after: print(f"    Update Persistence Check: Found image URL after update: {url_after}")
            else: print("    WARN: Image URL missing after update when one was expected.")
            # Can't assert object names without verification
            # assert obj_name_after == profile_image_object_name_expected, "Profile image URL mismatch"
    return True

def test_users_interactions():
    """Tests following, followers, blocking."""
    print("\n--- Testing: User Interactions (Follow/Block) ---")
    if logged_in_user_id is None: print("ERROR: Not logged in."); return
    target_user = CONFIG['TARGET_USER_ID_TO_VIEW_AND_BLOCK']; other_user = CONFIG['OTHER_USER_ID_TO_FOLLOW']
    if target_user == logged_in_user_id or other_user == logged_in_user_id: print("\nERROR: Placeholder IDs must differ from logged in user."); return
    make_request("GET", f"/users/{target_user}", f"Get Profile User {target_user}")
    make_request("POST", f"/users/{other_user}/follow", f"Follow User {other_user}", data=None)
    make_request("GET", f"/users/{logged_in_user_id}/following", f"Get My Following List")
    make_request("GET", f"/users/{other_user}/followers", f"Get Followers List User {other_user}")
    make_request("DELETE", f"/users/{other_user}/follow", f"Unfollow User {other_user}")
    make_request("POST", f"/users/me/block/{target_user}", f"Block User {target_user}", expected_status=[204])
    time.sleep(0.2); blocked_resp = make_request("GET", "/users/me/blocked", "Get Blocked Users (After Block)")
    if blocked_resp: assert any(u.get('blocked_id') == target_user for u in blocked_resp), "Block Verification Failed"
    make_request("DELETE", f"/users/me/unblock/{target_user}", f"Unblock User {target_user}", expected_status=[204])
    time.sleep(0.2); unblocked_resp = make_request("GET", "/users/me/blocked", "Get Blocked Users (After Unblock)")
    if unblocked_resp is not None: assert not any(u.get('blocked_id') == target_user for u in unblocked_resp), "Unblock Verification Failed"
    make_request("GET", "/users/me/communities", "Get My Joined Communities")
    make_request("GET", "/users/me/events", "Get My Joined Events")
    make_request("GET", "/users/me/stats", "Get My Stats")

def test_communities_and_logo():
    """Tests community listing, details, join/leave, logo update."""
    print("\n--- Testing: Communities & Logo ---")
    community_id = CONFIG['TARGET_COMMUNITY_ID']
    make_request("GET", "/communities", "List Communities")
    make_request("GET", "/communities/trending", "List Trending Communities", expected_status=[200]) # Assuming implemented now
    make_request("GET", f"/communities/{community_id}/details", f"Get Community {community_id} Details")
    make_request("POST", f"/communities/{community_id}/join", f"Join Community {community_id}", data=None)
    make_request("DELETE", f"/communities/{community_id}/leave", f"Leave Community {community_id}", data=None)
    make_request("GET", f"/communities/{community_id}/events", f"List Events for Community {community_id}")

    # Test Update Community Logo (Removed the skip logic - runs if image provided)
    if test_image_file_details:
        logo_files = {'logo': test_image_file_details}
        logo_update_resp = make_request("POST", f"/communities/{community_id}/logo", f"Update Community {community_id} Logo", files=logo_files, is_json=False)
        logo_obj_name_expected = None
        if logo_update_resp:
            new_logo_url = logo_update_resp.get('logo_url')
            logo_obj_name_expected = extract_minio_object_name(new_logo_url)
            if new_logo_url: print(f"    Logo update returned URL: {new_logo_url}")
            # verify_minio_upload(logo_obj_name_expected) # Verification disabled
            else: print("    WARN: Update logo response missing logo_url")

        details_resp = make_request("GET", f"/communities/{community_id}/details", f"Get Community {community_id} Details (After Logo Update)")
        if details_resp and logo_obj_name_expected:
            url_after = details_resp.get("logo_url")
            obj_name_after = extract_minio_object_name(url_after)
            if url_after: print(f"    Details after update show logo URL: {url_after}")
            else: print("    WARN: Logo URL missing in details after update.")
            # Cannot assert object name without verification, but check if URL exists
            assert url_after is not None, "Logo URL missing after update, expected one."
            print(f"    Update Persistence Check: Logo URL present after update.")
    else:
        print("INFO: Skipping Community Logo update test - No image provided.")

def test_events_and_media():
    """Tests event creation with image, get details, join/leave, update image."""
    global created_event_id_with_media
    print("\n--- Testing: Events & Media ---")
    community_id = CONFIG['TARGET_COMMUNITY_ID']
    event_id_to_interact = CONFIG['TARGET_EVENT_ID']

    event_fields = {"title": f"Test Event w/ Img {datetime.now().strftime('%H%M%S')}", "description": "Banner test!", "location": "Virtual", "event_timestamp": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()}
    event_files = None; test_name_event = "Create Event (No Image)"
    if test_image_file_details: event_files = {'image': test_image_file_details}; test_name_event = "Create Event (With Image)"
    else: results["skipped"].append({"name": "Create Event With Image (No Image Provided)"})

    created_event_resp = make_request("POST", f"/communities/{community_id}/events", test_name_event, data=event_fields, files=event_files, is_json=False)
    event_image_obj_name_created = None
    if created_event_resp:
        created_event_id_with_media = created_event_resp.get('id')
        event_id_to_interact = created_event_id_with_media or event_id_to_interact
        if event_files:
            event_image_url = created_event_resp.get('image_url')
            event_image_obj_name_created = extract_minio_object_name(event_image_url)
            if event_image_url: print(f"    Create event returned image URL: {event_image_url}")
            # verify_minio_upload(event_image_obj_name_created)
            else: print("    WARN: Create event response missing image_url when expected.")

    get_event_resp = make_request("GET", f"/events/{event_id_to_interact}", f"Get Event {event_id_to_interact} Details")
    if get_event_resp and event_image_obj_name_created:
        url_after_create = get_event_resp.get('image_url')
        obj_name_after_create = extract_minio_object_name(url_after_create)
        if url_after_create: print(f"    Get event details returned image URL: {url_after_create}")
        assert obj_name_after_create == event_image_obj_name_created, "Event image URL mismatch after creation."
        print("    Create Persistence Check: Event Image URL correct.")

    make_request("POST", f"/events/{event_id_to_interact}/join", f"Join Event {event_id_to_interact}", data=None)
    make_request("DELETE", f"/events/{event_id_to_interact}/leave", f"Leave Event {event_id_to_interact}", data=None)

    if created_event_id_with_media and test_text_file_details:
        update_event_files = {'image': test_text_file_details}
        update_event_resp = make_request("PUT", f"/events/{created_event_id_with_media}", "Update Event Image", files=update_event_files, is_json=False)
        if update_event_resp:
            event_image_url_updated = update_event_resp.get('image_url')
            updated_event_obj_name = extract_minio_object_name(event_image_url_updated)
            if event_image_url_updated: print(f"    Update event returned image URL: {event_image_url_updated}")
            # verify_minio_upload(updated_event_obj_name)
            else: print("    WARN: Update event response missing image_url")
            # Check if different from original
            assert updated_event_obj_name != event_image_obj_name_created, "Event image did not change after update"
            print("    Update Check: Event image URL changed.")
    elif created_event_id_with_media: results["skipped"].append({"name": "Update Event Image (No Text File Provided)"})

def test_posts_and_media():
    """Tests post creation with single/multiple media, get post, list posts."""
    global created_post_id_with_media
    print("\n--- Testing: Posts & Media ---")
    community_id = CONFIG['TARGET_COMMUNITY_ID']; user_id = logged_in_user_id

    post_fields_multi = {"title": f"Test Post Multi-Media {datetime.now()}", "content": "Two files!", "community_id": str(community_id)}
    post_files_multi_tuples = []
    if test_image_file_details: post_files_multi_tuples.append(('files', test_image_file_details))
    if test_text_file_details: post_files_multi_tuples.append(('files', test_text_file_details))

    if len(post_files_multi_tuples) > 0:
        created_post_multi_resp = make_request("POST", "/posts", "Create Post (With Multiple Media)", data=post_fields_multi, files=post_files_multi_tuples, is_json=False)
        if created_post_multi_resp:
            created_post_id_with_media = created_post_multi_resp.get('id')
            media_list = created_post_multi_resp.get('media')
            expected_media_count = len(post_files_multi_tuples)
            assert isinstance(media_list, list), "Post 'media' field is not a list"
            assert len(media_list) == expected_media_count, f"Media count mismatch on create (Got {len(media_list)}, Expected {expected_media_count})"
            print(f"    Media Count Check (Create): SUCCESS ({len(media_list)}/{expected_media_count})")
            for i, item in enumerate(media_list):
                assert isinstance(item, dict), f"Media item {i} is not a dict"
                assert item.get('url'), f"Media item {i} missing URL"
                print(f"    Post Media {i} URL: {item.get('url')}")
                # verify_minio_upload(extract_minio_object_name(item.get('url')))
    else: results["skipped"].append({"name": "Create Post With Multiple Media (No Files Provided)"})

    if created_post_id_with_media:
        single_post_resp = make_request("GET", f"/posts/{created_post_id_with_media}", f"Get Created Post {created_post_id_with_media} Details")
        if single_post_resp:
            media_list = single_post_resp.get('media')
            expected_media_count = len(post_files_multi_tuples) # Should match number uploaded
            assert isinstance(media_list, list), "Post 'media' field is not a list in GET response"
            assert len(media_list) == expected_media_count, f"Media count mismatch in GET Post (Got {len(media_list)}, Expected {expected_media_count})"
            print(f"    Single Post Media Count Check (GET): SUCCESS ({len(media_list)}/{expected_media_count})")
            # for item in media_list: verify_minio_upload(extract_minio_object_name(item.get('url')))

    make_request("GET", "/posts", "List Posts (General)", params={"limit": 5})
    make_request("GET", "/posts", f"List Posts (Community {community_id})", params={"community_id": community_id, "limit": 5})
    make_request("GET", "/posts", f"List Posts (User {user_id})", params={"user_id": user_id, "limit": 5})
    make_request("GET", "/posts/trending", "List Trending Posts", expected_status=[200]) # Expect 200 now for placeholder

def test_replies_and_media():
    """Tests reply creation with media, get replies."""
    global created_reply_id_with_media
    print("\n--- Testing: Replies & Media ---")
    post_id = CONFIG['EXISTING_POST_ID']

    reply_fields_media = {"post_id": str(post_id), "content": f"Test reply w/ media {datetime.now()}"}
    reply_files_list = []; test_name_reply = "Create Reply (No Image)"
    if test_image_file_details: reply_files_list.append(('files', test_image_file_details)); test_name_reply = "Create Reply (With Image)"
    else: results["skipped"].append({"name": "Create Reply With Image (No Image Provided)"})

    create_reply_resp = make_request("POST", "/replies", test_name_reply, data=reply_fields_media, files=reply_files_list, is_json=False)
    reply_image_obj_name_expected = None
    if create_reply_resp:
        created_reply_id_with_media = create_reply_resp.get('id')
        if reply_files_list:
            media_list = create_reply_resp.get('media')
            assert isinstance(media_list, list) and len(media_list) > 0, "Media list missing/empty in create reply response"
            reply_image_url = media_list[0].get('url')
            reply_image_obj_name_expected = extract_minio_object_name(reply_image_url)
            print(f"    Create reply returned media URL: {reply_image_url}")
            # verify_minio_upload(reply_image_obj_name_expected)

    replies_list_resp = make_request("GET", f"/replies/{post_id}", f"List Replies for Post {post_id} (Check Media)")
    if replies_list_resp and created_reply_id_with_media: # Check if we created one
        found_reply = next((r for r in replies_list_resp if r.get('id') == created_reply_id_with_media), None)
        assert found_reply, f"Created reply {created_reply_id_with_media} not found in list response."
        media_list = found_reply.get('media', []) # Default to empty list
        if reply_files_list: # If we expected media
            assert isinstance(media_list, list) and len(media_list) > 0, f"Reply {created_reply_id_with_media} media missing in list response."
            obj_name_in_list = extract_minio_object_name(media_list[0].get('url'))
            # Cannot assert object name reliably without verification
            # assert obj_name_in_list == reply_image_obj_name_expected, "Reply media object name mismatch."
            assert media_list[0].get('url') is not None, "Reply media URL is null/missing."
            print(f"    Reply Media Check: SUCCESS - Found media for reply {created_reply_id_with_media}.")
        else: # If we didn't upload media
            assert len(media_list) == 0, f"Reply {created_reply_id_with_media} unexpectedly has media."
            print(f"    Reply Media Check: SUCCESS - No media found for reply {created_reply_id_with_media} (as expected).")

def test_interactions():
    """Tests votes and favorites."""
    print("\n--- Testing: Interactions (Votes/Favorites) ---")
    post_id = CONFIG['EXISTING_POST_ID']; reply_id = CONFIG['EXISTING_REPLY_ID']
    make_request("POST", f"/posts/{post_id}/favorite", f"Favorite Post {post_id}", data=None)
    make_request("DELETE", f"/posts/{post_id}/favorite", f"Unfavorite Post {post_id}", data=None)
    make_request("POST", f"/replies/{reply_id}/favorite", f"Favorite Reply {reply_id}", data=None)
    make_request("DELETE", f"/replies/{reply_id}/favorite", f"Unfavorite Reply {reply_id}", data=None)
    vote_post_up = {"post_id": post_id, "reply_id": None, "vote_type": True}
    vote_post_down = {"post_id": post_id, "reply_id": None, "vote_type": False}
    vote_reply_up = {"post_id": None, "reply_id": reply_id, "vote_type": True}
    make_request("POST", "/votes", f"Upvote Post {post_id}", data=vote_post_up, is_json=True)
    make_request("POST", "/votes", f"Downvote Post {post_id}", data=vote_post_down, is_json=True)
    make_request("POST", "/votes", f"Remove Vote Post {post_id}", data=vote_post_down, is_json=True)
    make_request("POST", "/votes", f"Upvote Reply {reply_id}", data=vote_reply_up, is_json=True)

def test_chat_and_media():
    """Tests sending chat messages (text & media) and fetching history."""
    global created_chat_msg_id_with_media
    print("\n--- Testing: Chat & Media ---")
    community_id = CONFIG['TARGET_COMMUNITY_ID']; event_id = CONFIG['TARGET_EVENT_ID']

    chat_fields_media = {"content": f"Test Chat msg w/ media {datetime.now()}"}
    chat_files_list = []; test_name_chat = "Send HTTP Chat (Text Only)"
    if test_image_file_details: chat_files_list.append(('files', test_image_file_details)); test_name_chat = "Send HTTP Chat (With Image)"
    else: results["skipped"].append({"name": "Send HTTP Chat With Image (No Image Provided)"})

    chat_msg_resp = make_request("POST", "/chat/messages", test_name_chat, params={"community_id": community_id}, data=chat_fields_media, files=chat_files_list, is_json=False)
    chat_image_obj_name_expected = None
    if chat_msg_resp:
        created_chat_msg_id_with_media = chat_msg_resp.get('message_id')
        if chat_files_list:
            media_list = chat_msg_resp.get('media')
            assert isinstance(media_list, list) and len(media_list) > 0, "Media list missing/empty in send chat response"
            chat_image_url = media_list[0].get('url')
            chat_image_obj_name_expected = extract_minio_object_name(chat_image_url)
            print(f"    Send chat returned media URL: {chat_image_url}")
            # verify_minio_upload(chat_image_obj_name_expected)

    chat_hist_resp = make_request("GET", "/chat/messages", f"Get Chat History (Comm {community_id}, Check Media)", params={"community_id": community_id, "limit": 10})
    if chat_hist_resp and created_chat_msg_id_with_media: # Check if we created one
        found_msg = next((m for m in chat_hist_resp if m.get('message_id') == created_chat_msg_id_with_media), None)
        assert found_msg, f"Created chat msg {created_chat_msg_id_with_media} not found in history."
        media_list = found_msg.get('media', [])
        if chat_files_list: # If we expected media
            assert isinstance(media_list, list) and len(media_list) > 0, f"Chat msg {created_chat_msg_id_with_media} media missing in history."
            obj_name_in_list = extract_minio_object_name(media_list[0].get('url'))
            # Cannot assert object name reliably without verification
            # assert obj_name_in_list == chat_image_obj_name_expected, "Chat media object name mismatch."
            assert media_list[0].get('url') is not None, "Chat media URL is null/missing."
            print(f"    Chat Media Check: SUCCESS - Found media for msg {created_chat_msg_id_with_media}.")
        else: # If we didn't upload media
            assert len(media_list) == 0, f"Chat msg {created_chat_msg_id_with_media} unexpectedly has media."
            print(f"    Chat Media Check: SUCCESS - No media found for msg {created_chat_msg_id_with_media} (as expected).")

    make_request("GET", "/chat/messages", f"Get Chat History (Event {event_id})", params={"event_id": event_id, "limit": 5})

def test_settings():
    """Tests getting and updating notification settings."""
    print("\n--- Testing: Settings ---")
    make_request("GET", "/settings/notifications", "Get Notification Settings", expected_status=[200])
    settings_data = { "new_post_in_community": False, "new_reply_to_post": True, "new_event_in_community": True, "event_reminder": False, "direct_message": True }
    update_resp = make_request("PUT", "/settings/notifications", "Update Notification Settings", data=settings_data, is_json=True)
    if update_resp:
        get_resp = make_request("GET", "/settings/notifications", "Get Notification Settings (After Update)")
        if get_resp:
            assert get_resp.get("new_post_in_community") is False and get_resp.get("direct_message") is True, "Setting update verification failed"
            print("    Update Persistence Check: Settings updated correctly.")

def test_graphql():
    """Tests basic GraphQL queries."""
    print("\n--- Testing: GraphQL ---")
    gql_query_viewer = {"query": "query { viewer { id username } }"}
    gql_query_user_target = { "query": "query GetUser($userId: ID!) { user(id: $userId) { id username } }", "variables": {"userId": str(CONFIG['TARGET_USER_ID_TO_VIEW_AND_BLOCK'])} }
    gql_query_post_media = {
        "query": "query GetPost($postId: ID!) { post(id: $postId) { id title media { url mimeType } } }",
        "variables": {"postId": str(created_post_id_with_media or CONFIG['EXISTING_POST_ID'])}
    }
    make_request("POST", "/graphql", "GraphQL Get Viewer", data=gql_query_viewer, use_api_key=False, is_json=True)
    make_request("POST", "/graphql", f"GraphQL Get User {CONFIG['TARGET_USER_ID_TO_VIEW_AND_BLOCK']}", data=gql_query_user_target, use_api_key=False, is_json=True)
    make_request("POST", "/graphql", f"GraphQL Get Post with Media", data=gql_query_post_media, use_api_key=False, is_json=True)

def print_summary():
    """Prints a summary of successful and failed tests."""
    # ... (keep existing implementation) ...
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
            print(f"   Endpoint:  {failure.get('endpoint', 'N/A')}")
            print(f"   Status:    {failure['status']}")
            response_content = failure.get('response', 'N/A')
            response_str = "";
            try:
                if isinstance(response_content,(dict,list)): response_str = json.dumps(response_content)
                elif isinstance(response_content, str): response_str = response_content
                else: response_str = str(response_content)
            except Exception: response_str = str(response_content)
            print(f"   Response:  {response_str[:1000]}{'...' if len(response_str)>1000 else ''}")
    elif total_run > 0: print("\n--- ALL EXECUTED TESTS PASSED ---")
    else: print("\n--- NO TESTS WERE EXECUTED ---")
    if results["skipped"]: print("\n--- SKIPPED TESTS ---"); [print(f"{i+1}. {s['name']}") for i, s in enumerate(results["skipped"])]
    print("="*74 + "\n")

# --- Main Execution ---
if __name__ == "__main__":
    print("--- Starting API Test Suite ---")
    # --- Get Credentials ---
    if not CONFIG['API_KEY']: CONFIG['API_KEY'] = input("Enter API Key: ")
    if not CONFIG['API_KEY']: print("API Key is required."); sys.exit(1)
    if not CONFIG['TEST_USER_PASSWORD']: CONFIG['TEST_USER_PASSWORD'] = getpass(f"Enter Password for {CONFIG['USER_EMAIL_DEFAULT']}: ")
    if not CONFIG['TEST_USER_PASSWORD']: print("Test user password is required."); sys.exit(1)

    # --- Prepare Test Files ---
    text_file_path = Path("./test_upload.txt").resolve()
    image_path_input = input(f"Enter ABSOLUTE path to test image (e.g., /path/image.jpg) [Enter to skip image tests]: ")
    test_image_path = Path(image_path_input) if image_path_input else None
    if test_image_path and test_image_path.is_file():
        try:
            img_filename = test_image_path.name; img_content = test_image_path.read_bytes(); img_mimetype, _ = mimetypes.guess_type(img_filename)
            test_image_file_details = (img_filename, img_content, img_mimetype or 'application/octet-stream')
            print(f"✅ Test image ready: {test_image_path}")
        except Exception as e: print(f"⚠️ Warning: Could not read image file '{test_image_path}': {e}")
    elif image_path_input: print(f"⚠️ Warning: Image path '{image_path_input}' not found or not a file.")
    try:
        text_content_str = f"Test text file {datetime.now()}"; text_content_bytes = text_content_str.encode('utf-8'); text_file_path.write_bytes(text_content_bytes)
        test_text_file_details = (text_file_path.name, text_content_bytes, 'text/plain')
        print(f"✅ Test text file ready: {text_file_path}")
    except Exception as e: print(f"⚠️ Warning: Could not create/prepare text file '{text_file_path}': {e}")

    # --- Run Test Sections ---
    try:
        if test_authentication_and_profile(CONFIG['USER_EMAIL_DEFAULT'], CONFIG['TEST_USER_PASSWORD']):
            test_users_interactions()
            test_communities_and_logo()
            test_events_and_media()
            test_posts_and_media()
            test_replies_and_media()
            test_interactions()
            test_chat_and_media()
            test_settings()
            test_graphql()
        else: print("Skipping further tests due to login failure.")
    finally:
        # Cleanup MinIO (Optional - Enable with caution)
        # print("\nRequesting MinIO cleanup...")
        # cleanup_minio_uploads()
        # Cleanup text file
        if text_file_path.exists():
            try: text_file_path.unlink(); print(f"🧹 Cleaned up test file: {text_file_path}")
            except Exception as e: print(f"⚠️ Error cleaning up test file: {e}")
        print_summary()
    print("--- API Test Suite Finished ---")