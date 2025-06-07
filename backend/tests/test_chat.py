# tests/test_chat.py
import pytest
import time
from .helpers import make_api_request, prepare_file_details, extract_minio_object_name, results
from datetime import datetime
from pathlib import Path
import os

pytestmark = pytest.mark.ordering(order=8) # Ensure it runs after some data might exist
test_image_file_details = None
module_data = {"created_chat_msg_id_with_media": None}

@pytest.fixture(scope="module", autouse=True)
def load_files_and_init_chat(prepared_test_files): # Renamed fixture for clarity
    global test_image_file_details
    module_data["created_chat_msg_id_with_media"] = None
    # 'prepared_test_files' comes from conftest.py and provides {"image": ..., "text": ...}
    test_image_file_details = prepared_test_files["image"]
    if not test_image_file_details:
        print("WARN (test_chat.py): Test image file not available. Media upload tests in chat will be skipped.")

def test_get_chat_history_community(authenticated_session, test_data_ids):
    auth_info = authenticated_session; community_id = test_data_ids['community_id']
    resp = make_api_request(
        auth_info["session"], "GET", f"{auth_info['base_url']}/chat/messages",
        f"Get Chat History (Community {community_id})",
        params={"community_id": community_id, "limit": "5"} # Query params are strings
    )
    assert resp is not None; assert isinstance(resp, list)
    if len(resp) > 0: assert "message_id" in resp[0]; assert resp[0].get("community_id") == community_id

def test_get_chat_history_event(authenticated_session, test_data_ids):
    auth_info = authenticated_session; event_id = test_data_ids['event_id']
    resp = make_api_request(
        auth_info["session"], "GET", f"{auth_info['base_url']}/chat/messages",
        f"Get Chat History (Event {event_id})",
        params={"event_id": event_id, "limit": "5"} # Query params are strings
    )
    assert resp is not None; assert isinstance(resp, list)
    if len(resp) > 0: assert "message_id" in resp[0]; assert resp[0].get("event_id") == event_id


# DM history test (assuming current user is ID from auth_info['user_id']
# and target_data_ids['target_user_id'] is the other participant)
def test_get_chat_history_dm(authenticated_session, test_data_ids):
    auth_info = authenticated_session
    my_user_id = auth_info['user_id']
    other_user_id = test_data_ids['target_user_id'] # A user different from the logged-in one

    assert my_user_id != other_user_id, "For DM history test, 'target_user_id' must be different from current user."

    resp = make_api_request(
        auth_info["session"], "GET", f"{auth_info['base_url']}/chat/messages",
        f"Get Chat History (DM between {my_user_id} and {other_user_id})",
        params={"dm_with_user_id": str(other_user_id), "limit": "5"} # Pass the other user's ID
    )
    assert resp is not None, f"DM history request between {my_user_id} and {other_user_id} failed to get a response."
    assert isinstance(resp, list), "DM history response is not a list."
    # Further checks depend on whether mock DMs exist.
    # For now, just checking it returns a list is a good start.
    print(f"    DM history fetch between {my_user_id} and {other_user_id} returned {len(resp)} messages.")


def test_send_chat_message_text_community(authenticated_session, test_data_ids):
    auth_info = authenticated_session; community_id = test_data_ids['community_id']
    # Data for form fields, including community_id
    chat_data_form = {
        "content": f"Pytest HTTP Text Msg Community {datetime.now().strftime('%H%M%S')}",
        "community_id": str(community_id) # Send community_id as part of form data
    }
    resp = make_api_request(
        auth_info["session"], "POST", f"{auth_info['base_url']}/chat/messages",
        f"Send HTTP Chat (Community {community_id} - Text Only)",
        data=chat_data_form, # All Form(...) params go here
        # params=None, # No query parameters needed for this POST
        expected_status=[201]
    )
    assert resp is not None, "Send text chat message to community failed"
    assert resp.get("content") == chat_data_form["content"]
    assert resp.get("user_id") == auth_info["user_id"]
    assert resp.get("community_id") == community_id
    assert resp.get("event_id") is None
    assert resp.get("dm_recipient_user_id") is None # Or however your schema names it
    assert resp.get("media") == []

def test_send_chat_message_text_event(authenticated_session, test_data_ids):
    auth_info = authenticated_session; event_id = test_data_ids['event_id']
    chat_data_form = {
        "content": f"Pytest HTTP Text Msg Event {datetime.now().strftime('%H%M%S')}",
        "event_id": str(event_id)
    }
    resp = make_api_request(
        auth_info["session"], "POST", f"{auth_info['base_url']}/chat/messages",
        f"Send HTTP Chat (Event {event_id} - Text Only)",
        data=chat_data_form,
        expected_status=[201]
    )
    assert resp is not None, "Send text chat message to event failed"
    assert resp.get("event_id") == event_id
    assert resp.get("community_id") is None

def test_send_chat_message_text_dm(authenticated_session, test_data_ids):
    auth_info = authenticated_session;
    recipient_id = test_data_ids['target_user_id'] # Send DM to target_user_id
    assert auth_info['user_id'] != recipient_id, "Cannot send DM to self in test."

    chat_data_form = {
        "content": f"Pytest HTTP DM Text Msg {datetime.now().strftime('%H%M%S')}",
        "dm_recipient_user_id": str(recipient_id)
    }
    resp = make_api_request(
        auth_info["session"], "POST", f"{auth_info['base_url']}/chat/messages",
        f"Send HTTP DM (To User {recipient_id} - Text Only)",
        data=chat_data_form,
        expected_status=[201]
    )
    assert resp is not None, f"Send DM text message to user {recipient_id} failed"
    assert resp.get("content") == chat_data_form["content"]
    assert resp.get("user_id") == auth_info["user_id"] # This is the sender
    assert resp.get("sender_id") == auth_info["user_id"]
    assert resp.get("recipient_id") == recipient_id
    assert resp.get("community_id") is None
    assert resp.get("event_id") is None
    assert resp.get("media") == []


def test_send_chat_message_with_media_community(authenticated_session, test_data_ids):
    # global module_data # No longer need to store created_chat_msg_id globally from here
    auth_info = authenticated_session; community_id = test_data_ids['community_id']
    if not test_image_file_details: pytest.skip("Skipping Send HTTP Chat With Image to Community.")

    chat_fields_media = {
        "content": f"Pytest Chat msg w/ media Community {datetime.now().strftime('%H%M%S')}",
        "community_id": str(community_id)
    }
    chat_files_list = [('files', test_image_file_details)]

    resp = make_api_request(
        auth_info["session"], "POST", f"{auth_info['base_url']}/chat/messages",
        f"Send HTTP Chat (Community {community_id} - With Image)",
        data=chat_fields_media,
        files=chat_files_list,
        expected_status=[201]
    )
    assert resp is not None, "Send chat message with media to community failed"
    created_id = resp.get('message_id'); assert created_id is not None
    # module_data["created_chat_msg_id_with_media"] = created_id # Store if other tests in this file need it
    print(f"    Created chat message ID in community: {created_id}")
    assert resp.get("community_id") == community_id
    media_list = resp.get('media'); assert isinstance(media_list, list) and len(media_list) > 0
    assert media_list[0].get('url') is not None


# Test history AFTER send (can be removed if covered by individual get tests or becomes flaky)
# def test_get_chat_history_after_send(authenticated_session, test_data_ids):
#     created_msg_id = module_data.get("created_chat_msg_id_with_media")
#     if not created_msg_id: pytest.skip("Skipping chat history verification, no message created by prior test.")
#     auth_info = authenticated_session; community_id = test_data_ids['community_id']
#     # This logic needs to be robust: which room was the created_msg_id for?
#     # For simplicity, assume it was a community message to community_id

#     time.sleep(0.5) # Allow for potential eventual consistency or processing delay
#     resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/chat/messages",
#                             f"Get Chat History (Comm {community_id}, After Media Send)",
#                             params={"community_id": community_id, "limit": "10"})
#     assert resp is not None; assert isinstance(resp, list)
#     found_msg_dict = next((m for m in resp if m.get('message_id') == created_msg_id), None)
#     assert found_msg_dict is not None, f"Created chat msg {created_msg_id} not found in history."
#     media_list = found_msg_dict.get('media', [])
#     if test_image_file_details: # Only assert if we expected media
#         assert isinstance(media_list, list) and len(media_list) > 0, f"Chat msg {created_msg_id} media missing."
#         assert media_list[0].get('url') is not None
#         print(f"    Chat Media Check (After Send): SUCCESS - Found media for msg {created_msg_id}.")
#     else:
#         assert len(media_list) == 0, f"Chat msg {created_msg_id} unexpectedly has media."