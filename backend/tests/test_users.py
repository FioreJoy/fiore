# tests/test_users.py
import pytest
import time
from .helpers import make_api_request, results # CORRECTED Import

# Mark to run after auth tests
pytestmark = pytest.mark.ordering(order=2)

# Test Data (Loaded via fixtures in conftest.py)

def test_get_other_user_profile(authenticated_session, test_data_ids):
    """Tests fetching another user's profile."""
    auth_info = authenticated_session
    target_user_id = test_data_ids['target_user_id']
    assert target_user_id != auth_info['user_id'], "Target user ID cannot be the logged-in user ID for this test."

    resp = make_api_request( # CORRECTED Function name
        auth_info["session"], "GET", f"{auth_info['base_url']}/users/{target_user_id}",
        f"Get Profile User {target_user_id}"
    )
    assert resp is not None, f"Failed to get profile for user {target_user_id}"
    assert resp.get("id") == target_user_id

def test_follow_unfollow_user(authenticated_session, test_data_ids):
    """Tests the follow/unfollow cycle."""
    auth_info = authenticated_session
    other_user_id = test_data_ids['other_user_id']
    my_user_id = auth_info['user_id']
    base_url = auth_info['base_url']
    session = auth_info['session']
    assert other_user_id != my_user_id, "Other user ID cannot be the logged-in user ID for this test."

    # Follow
    resp_follow = make_api_request(session, "POST", f"{base_url}/users/{other_user_id}/follow", f"Follow User {other_user_id}", data=None, expected_status=[200])
    assert resp_follow is not None and resp_follow.get("success") is True

    # Check My Following List
    time.sleep(0.5) # Increased delay
    resp_following = make_api_request(session, "GET", f"{base_url}/users/{my_user_id}/following", f"Get My Following List")
    assert resp_following is not None
    assert any(u.get('id') == other_user_id for u in resp_following), f"User {other_user_id} not in following list after follow"
    print(f"    Follow Check: User {other_user_id} found in following list.")

    # Check Other User's Followers List
    resp_followers = make_api_request(session, "GET", f"{base_url}/users/{other_user_id}/followers", f"Get Followers List User {other_user_id}")
    assert resp_followers is not None
    assert any(u.get('id') == my_user_id for u in resp_followers), f"User {my_user_id} not in followers list of {other_user_id}"
    print(f"    Follow Check: User {my_user_id} found in followers list.")

    # Unfollow
    resp_unfollow = make_api_request(session, "DELETE", f"{base_url}/users/{other_user_id}/follow", f"Unfollow User {other_user_id}", expected_status=[200])
    assert resp_unfollow is not None and resp_unfollow.get("success") is True

    # Check My Following List Again
    time.sleep(0.5) # Increased delay
    resp_following_after = make_api_request(session, "GET", f"{base_url}/users/{my_user_id}/following", f"Get My Following List (After Unfollow)")
    assert resp_following_after is not None
    assert not any(u.get('id') == other_user_id for u in resp_following_after), f"User {other_user_id} still in following list after unfollow"
    print(f"    Unfollow Check: User {other_user_id} NOT found in following list.")

def test_block_unblock_user(authenticated_session, test_data_ids):
    """Tests the block/unblock cycle."""
    auth_info = authenticated_session
    target_user_id = test_data_ids['target_user_id']
    base_url = auth_info['base_url']
    session = auth_info['session']
    assert target_user_id != auth_info['user_id'], "Cannot block self."

    # Block
    make_api_request(session, "POST", f"{base_url}/users/me/block/{target_user_id}", f"Block User {target_user_id}", expected_status=[204]) # CORRECTED

    # Verify Blocked List
    time.sleep(0.3)
    blocked_resp = make_api_request(session, "GET", f"{base_url}/users/me/blocked", "Get Blocked Users (After Block)") # CORRECTED
    assert blocked_resp is not None, "Failed to fetch blocked list after blocking"
    assert any(u.get('blocked_id') == target_user_id for u in blocked_resp), f"Block Verification Failed: User {target_user_id} not found in list."
    print(f"    Block Verification: User {target_user_id} FOUND in blocked list.")

    # Unblock
    make_api_request(session, "DELETE", f"{base_url}/users/me/unblock/{target_user_id}", f"Unblock User {target_user_id}", expected_status=[204]) # CORRECTED

    # Verify Blocked List Again
    time.sleep(0.3)
    unblocked_resp = make_api_request(session, "GET", f"{base_url}/users/me/blocked", "Get Blocked Users (After Unblock)") # CORRECTED
    assert unblocked_resp is not None, "Failed to fetch blocked list after unblocking"
    assert not any(u.get('blocked_id') == target_user_id for u in unblocked_resp), f"Unblock Verification Failed: User {target_user_id} still found in list."
    print(f"    Unblock Verification: User {target_user_id} NOT found in blocked list.")

def test_get_my_lists(authenticated_session):
    """Tests endpoints under /users/me/ for lists."""
    auth_info = authenticated_session
    base_url = auth_info['base_url']
    session = auth_info['session']

    resp_comm = make_api_request(session, "GET", f"{base_url}/users/me/communities", "Get My Joined Communities")
    assert isinstance(resp_comm, list), "/users/me/communities did not return a list"

    resp_events = make_api_request(session, "GET", f"{base_url}/users/me/events", "Get My Joined Events")
    assert isinstance(resp_events, list), "/users/me/events did not return a list"

    resp_stats = make_api_request(session, "GET", f"{base_url}/users/me/stats", "Get My Stats")
    assert isinstance(resp_stats, dict), "/users/me/stats did not return a dict"
    assert "communities_joined" in resp_stats and "events_attended" in resp_stats and "posts_created" in resp_stats
