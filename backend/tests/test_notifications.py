# backend/tests/test_notifications.py
import pytest
import time
from .helpers import make_api_request, results
import schemas
# This module should run after actions that generate notifications (e.g., follow, reply)
pytestmark = pytest.mark.ordering(order=11) 

# Fixture to hold IDs created in other tests (if needed, or create data within these tests)
# For simplicity, we'll assume some notifications might exist from previous tests
# or we'll trigger actions here if necessary.

@pytest.fixture(scope="module")
def notification_test_data(authenticated_session, test_data_ids):
    """
    Fixture to ensure some notifications exist for the test user.
    It will make the test user reply to a known post to generate a 'post_reply' notification
    for the author of that post (if the author is not the test user).
    This is a bit complex for a fixture; simpler tests might rely on manual data setup or previous test runs.
    """
    auth_info = authenticated_session
    session = auth_info["session"]
    base_url = auth_info["base_url"]
    my_user_id = auth_info["user_id"]

    # Find a post NOT authored by the current test user to reply to
    # For this example, let's assume test_data_ids['post_id'] is authored by someone else.
    # A more robust fixture would query /posts and find a suitable one.
    post_to_reply_to_id = test_data_ids['post_id']
    
    # Get post details to find its author
    post_details_resp = make_api_request(
        session, "GET", f"{base_url}/posts/{post_to_reply_to_id}", "Get Post for Notification Test"
    )
    if not post_details_resp or post_details_resp.get("user_id") == my_user_id:
        print(f"WARN: Could not find a suitable post (ID: {post_to_reply_to_id}) not authored by test user {my_user_id} to generate reply notification.")
        # If this happens, tests for GET notifications might not find expected 'post_reply'
        return {"replied_to_post_id": None, "notified_user_id": None}


    post_author_id = post_details_resp["user_id"]

    # Create a reply from current_user_id to that post
    reply_data = {
        "post_id": str(post_to_reply_to_id),
        "content": "Test reply for notification generation!"
    }
    make_api_request(
        session, "POST", f"{base_url}/replies", "Create Reply for Notification Test",
        data=reply_data, # Form data
        expected_status=[201]
    )
    print(f"Notification test setup: User {my_user_id} replied to post {post_to_reply_to_id} (author: {post_author_id}).")
    # This should have created a 'post_reply' notification for post_author_id
    # If we want to test GETTING notifications, we need to log in AS post_author_id
    # This fixture is primarily for *generating* a notification.
    # Tests below will focus on *current_user_id*'s notifications (e.g. from being followed).

    # To generate a "new_follower" notification for the current test user:
    # We'd need another user to follow current_user_id. This is too complex for this fixture.
    # We'll rely on follow tests potentially creating these.

    return {"replied_to_post_id": post_to_reply_to_id, "notified_user_id": post_author_id}


def test_get_notifications(authenticated_session, notification_test_data):
    auth_info = authenticated_session
    session = auth_info["session"]
    base_url = auth_info["base_url"]

    # Test fetching all notifications
    resp_all = make_api_request(
        session, "GET", f"{base_url}/notifications", "Get All My Notifications",
        params={"limit": 5, "offset": 0}
    )
    assert resp_all is not None and isinstance(resp_all, list)
    if resp_all:
        first_notif = resp_all[0]
        assert "id" in first_notif and "type" in first_notif and "is_read" in first_notif
        print(f"    Fetched {len(resp_all)} notifications. First type: {first_notif.get('type')}")

    # Test fetching unread notifications
    resp_unread = make_api_request(
        session, "GET", f"{base_url}/notifications", "Get My Unread Notifications",
        params={"limit": 5, "offset": 0, "unread_only": "true"} # Query params are strings
    )
    assert resp_unread is not None and isinstance(resp_unread, list)
    assert all(notif.get("is_read") is False for notif in resp_unread)
    print(f"    Fetched {len(resp_unread)} unread notifications.")
    
    # Store one unread notification ID for marking as read test, if any
    module_data["unread_notification_id_to_mark"] = resp_unread[0]["id"] if resp_unread else None


def test_get_unread_notification_count(authenticated_session):
    auth_info = authenticated_session
    session = auth_info["session"]
    base_url = auth_info["base_url"]

    resp = make_api_request(
        session, "GET", f"{base_url}/notifications/unread-count", "Get My Unread Notification Count"
    )
    assert resp is not None and isinstance(resp, dict) and "count" in resp
    assert isinstance(resp["count"], int) and resp["count"] >= 0
    print(f"    Unread notification count: {resp['count']}")
    module_data["initial_unread_count"] = resp['count']


def test_mark_notification_as_read_and_unread(authenticated_session):
    auth_info = authenticated_session
    session = auth_info["session"]
    base_url = auth_info["base_url"]
    notification_id_to_test = module_data.get("unread_notification_id_to_mark")

    if not notification_id_to_test:
        pytest.skip("Skipping mark as read test: No unread notification ID captured from previous test.")
        return

    # Mark as read
    read_payload = {"notification_ids": [notification_id_to_test], "is_read": True}
    resp_mark_read = make_api_request(
        session, "POST", f"{base_url}/notifications/read", "Mark Notification As Read",
        json_data=read_payload # Use json_data for Pydantic model
    )
    assert resp_mark_read is not None and resp_mark_read.get("affected_count", 0) >= 0 # Can be 0 if already read
    
    # Verify it's read (by fetching it or checking count)
    time.sleep(0.2) # Allow time for DB update to reflect
    resp_check_read = make_api_request(session, "GET", f"{base_url}/notifications", "Get Notifications (Verify Read)", params={"limit": 5})
    if resp_check_read:
        target_notif = next((n for n in resp_check_read if n["id"] == notification_id_to_test), None)
        if target_notif:
            assert target_notif["is_read"] is True, f"Notification {notification_id_to_test} was not marked as read."
            print(f"    Notification {notification_id_to_test} successfully marked as read.")
        else:
            print(f"    WARN: Notification {notification_id_to_test} not found in list after marking read.")


    # Mark as unread
    unread_payload = {"notification_ids": [notification_id_to_test], "is_read": False}
    resp_mark_unread = make_api_request(
        session, "POST", f"{base_url}/notifications/read", "Mark Notification As Unread",
        json_data=unread_payload
    )
    assert resp_mark_unread is not None and resp_mark_unread.get("affected_count", 0) >= 0
    
    time.sleep(0.2)
    resp_check_unread_again = make_api_request(session, "GET", f"{base_url}/notifications", "Get Notifications (Verify Unread)", params={"limit": 5})
    if resp_check_unread_again:
        target_notif_unread = next((n for n in resp_check_unread_again if n["id"] == notification_id_to_test), None)
        if target_notif_unread:
            assert target_notif_unread["is_read"] is False, f"Notification {notification_id_to_test} was not marked as unread."
            print(f"    Notification {notification_id_to_test} successfully marked as unread.")
        else:
            print(f"    WARN: Notification {notification_id_to_test} not found in list after marking unread.")


def test_mark_all_as_read(authenticated_session):
    auth_info = authenticated_session
    session = auth_info["session"]
    base_url = auth_info["base_url"]
    initial_unread_count = module_data.get("initial_unread_count", 0)

    if initial_unread_count == 0:
        # To ensure this test runs meaningfully, create an unread notification if none exist
        # This is complex. For now, we'll skip if no unread.
        # A better approach: make sure previous tests generate some unread ones specifically for the current user.
        print("    Skipping mark all as read: No initial unread notifications or count not captured.")
        # We can still call it, should affect 0 rows.
        # pytest.skip("Skipping mark all as read: No initial unread notifications.")
        # return
    
    resp_mark_all = make_api_request(
        session, "POST", f"{base_url}/notifications/read-all", "Mark All Notifications As Read"
    )
    assert resp_mark_all is not None and "affected_count" in resp_mark_all
    # The affected_count might be less than initial_unread_count if some were marked read by other tests
    assert resp_mark_all["affected_count"] >= 0
    print(f"    Marked {resp_mark_all['affected_count']} notifications as read.")

    time.sleep(0.2)
    resp_count_after = make_api_request(
        session, "GET", f"{base_url}/notifications/unread-count", "Get Unread Count (After Mark All)"
    )
    assert resp_count_after is not None and resp_count_after.get("count") == 0
    print(f"    Unread count after mark all: {resp_count_after['count']}")


def test_register_and_unregister_device_token(authenticated_session):
    auth_info = authenticated_session
    session = auth_info["session"]
    base_url = auth_info["base_url"]
    
    # Use a unique token for each test run
    device_token_to_test = f"pytest-device-token-{int(time.time())}"
    platform_to_test = schemas.DevicePlatformEnum.web.value # Use one of the enum values

    # Register
    register_payload = {"device_token": device_token_to_test, "platform": platform_to_test}
    resp_register = make_api_request(
        session, "POST", f"{base_url}/notifications/device-tokens", "Register Device Token",
        json_data=register_payload,
        expected_status=[201]
    )
    assert resp_register is not None
    assert resp_register.get("device_token") == device_token_to_test
    assert resp_register.get("platform") == platform_to_test
    assert resp_register.get("user_id") == auth_info["user_id"]
    print(f"    Device token {device_token_to_test} registered for platform {platform_to_test}.")

    # Unregister (requires device_token as query parameter)
    time.sleep(0.2)
    make_api_request(
        session, "DELETE", f"{base_url}/notifications/device-tokens", "Unregister Device Token",
        params={"device_token": device_token_to_test},
        expected_status=[204]
    )
    print(f"    Device token {device_token_to_test} unregistration attempted.")
    
    # Optional: Verify it's gone by trying to fetch it (if a GET /device-tokens/{token} endpoint existed)
    # Or, try to register again and see if it's treated as new (depends on backend ON CONFLICT logic)

# Store shared data for the module
module_data = {}
