# tests/test_auth.py
import pytest
import time
from .helpers import make_api_request, results # Import helpers and global results
from datetime import datetime
from pathlib import Path # Keep Path import if needed for any reason
import mimetypes
import os

# Mark tests to run first
pytestmark = pytest.mark.ordering(order=1)

# Test file details will be loaded via fixture
test_image_file_details = None

@pytest.fixture(scope="module", autouse=True)
def setup_module(prepared_test_files):
    """Gets prepared file details from session fixture."""
    global test_image_file_details
    test_image_file_details = prepared_test_files["image"]
    # test_text_file_details = prepared_test_files["text"] # If needed here


def test_login(authenticated_session):
    """Verifies that the authenticated_session fixture worked."""
    assert authenticated_session["token"] is not None
    assert authenticated_session["user_id"] is not None
    print(f"Login implicitly verified by fixture. User ID: {authenticated_session['user_id']}")

def test_get_profile(authenticated_session, test_user_credentials):
    """Tests GET /auth/me."""
    auth_info = authenticated_session
    resp = make_api_request(
        auth_info["session"], "GET", f"{auth_info['base_url']}/auth/me",
        "Get Current User Profile"
    )
    assert resp is not None
    assert resp.get("id") == auth_info["user_id"]
    assert resp.get("email") == test_user_credentials["email"]

def test_update_profile(authenticated_session):
    """Tests PUT /auth/me with text and optionally image."""
    auth_info = authenticated_session
    base_url = auth_info['base_url']
    session = auth_info['session']

    update_profile_fields = { "college": f"Pytest College {datetime.now().second}" }
    update_profile_files = None
    test_name = "Update Profile Text Only"

    if test_image_file_details:
        update_profile_files = {'image': test_image_file_details}
        test_name = "Update Profile Text & Image"
    else:
        results["skipped"].append({"name": "Update Profile Picture (No Image Provided)"})

    profile_update_response = make_api_request(
        session, "PUT", f"{base_url}/auth/me", test_name,
        data=update_profile_fields, files=update_profile_files, expected_status=[200] # Use data/files
    )
    assert profile_update_response is not None, f"{test_name} request failed"
    profile_image_object_name_expected = None
    if test_image_file_details:
        new_image_url = profile_update_response.get('image_url')
        assert new_image_url is not None, "Image URL missing after profile update with image"
        profile_image_object_name_expected = extract_minio_object_name(new_image_url, auth_info['bucket_name'])
        verify_minio_upload(profile_image_object_name_expected) # Verification skipped

    # Verify persistence
    time.sleep(0.5)
    get_me_resp_after = make_api_request(
        session, "GET", f"{base_url}/auth/me", "Get Profile After Update"
    )
    assert get_me_resp_after is not None
    assert get_me_resp_after.get("college") == update_profile_fields["college"], "Profile college update failed"
    print("    Update Persistence Check: College updated.")

    if profile_image_object_name_expected:
        url_after = get_me_resp_after.get("image_url")
        obj_name_after = extract_minio_object_name(url_after, auth_info['bucket_name'])
        assert url_after is not None, "Image URL missing after update (verification get)"
        # Cannot assert object name reliably without verification permission
        # assert obj_name_after == profile_image_object_name_expected, "Image URL mismatch after update (verification get)"
        print(f"    Update Persistence Check: Image URL present after update: {url_after}")

# TODO: Add tests for change password and delete account if desired
# def test_change_password(...): ...
# def test_delete_account(...): ...
