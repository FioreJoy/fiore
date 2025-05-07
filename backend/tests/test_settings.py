# tests/test_settings.py
import pytest
from .helpers import make_api_request, results
import time

pytestmark = pytest.mark.ordering(order=9)

def test_get_notification_settings(authenticated_session):
    auth_info = authenticated_session
    resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/settings/notifications", "Get Notification Settings", expected_status=[200])
    assert resp is not None; assert "new_post_in_community" in resp; assert "direct_message" in resp
    print(f"    Initial Settings Received: {resp}")

def test_update_notification_settings(authenticated_session):
    auth_info = authenticated_session; base_url = auth_info['base_url']; session = auth_info['session']
    settings_data = {"new_post_in_community": False, "new_reply_to_post": False, "new_event_in_community": True, "event_reminder": False, "direct_message": True}
    update_resp = make_api_request(session, "PUT", f"{base_url}/settings/notifications", "Update Notification Settings", json_data=settings_data, expected_status=[200]) # Use json_data
    assert update_resp is not None; assert update_resp.get("new_post_in_community") is False; assert update_resp.get("direct_message") is True; print(f"    Update Response Received: {update_resp}")
    time.sleep(0.5)
    get_resp_after = make_api_request(session, "GET", f"{base_url}/settings/notifications", "Get Notification Settings (After Update)")
    assert get_resp_after is not None; assert get_resp_after.get("new_post_in_community") is settings_data["new_post_in_community"]; assert get_resp_after.get("direct_message") is settings_data["direct_message"]; print("    Update Persistence Check: Settings updated correctly.")
    default_settings = {"new_post_in_community": True, "new_reply_to_post": True, "new_event_in_community": True, "event_reminder": True, "direct_message": False}
    make_api_request(session, "PUT", f"{base_url}/settings/notifications", "Revert Notification Settings", json_data=default_settings, expected_status=[200]) # Use json_data
