# tests/test_chat.py
import pytest
import time
from .helpers import make_api_request, prepare_file_details, extract_minio_object_name, results
from datetime import datetime
from pathlib import Path
import os

pytestmark = pytest.mark.ordering(order=8)
test_image_file_details = None
module_data = {"created_chat_msg_id_with_media": None}

@pytest.fixture(scope="module", autouse=True)
def load_files_and_init():
    global test_image_file_details
    module_data["created_chat_msg_id_with_media"] = None
    img_path = os.getenv("TEST_IMAGE_PATH_ABS"); test_image_file_details = prepare_file_details(img_path)
    if not test_image_file_details: print("WARN: Chat image tests skipped.")

def test_get_chat_history_community(authenticated_session, test_data_ids):
    auth_info = authenticated_session; community_id = test_data_ids['community_id']
    resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/chat/messages", f"Get Chat History (Community {community_id})", params={"community_id": community_id, "limit": 5})
    assert resp is not None; assert isinstance(resp, list)
    if len(resp) > 0: assert "message_id" in resp[0]; assert resp[0].get("community_id") == community_id

def test_get_chat_history_event(authenticated_session, test_data_ids):
    auth_info = authenticated_session; event_id = test_data_ids['event_id']
    resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/chat/messages", f"Get Chat History (Event {event_id})", params={"event_id": event_id, "limit": 5})
    assert resp is not None; assert isinstance(resp, list)
    if len(resp) > 0: assert "message_id" in resp[0]; assert resp[0].get("event_id") == event_id

def test_send_chat_message_text(authenticated_session, test_data_ids):
    """Tests sending a text-only chat message via HTTP."""
    auth_info = authenticated_session; community_id = test_data_ids['community_id']
    # Prepare data as form fields
    chat_data_form = {"content": f"Pytest HTTP Text Msg {datetime.now().strftime('%H%M%S')}"}

    resp = make_api_request(
        auth_info["session"], "POST", f"{auth_info['base_url']}/chat/messages",
        f"Send HTTP Chat (Community {community_id} - Text Only)",
        params={"community_id": community_id},
        data=chat_data_form, # Use 'data' for form fields
        # files=None, # No files for this test
        expected_status=[201]
    )
    assert resp is not None, "Send text chat message failed"
    assert resp.get("content") == chat_data_form["content"] # Check against form data
    assert resp.get("user_id") == auth_info["user_id"]; assert resp.get("community_id") == community_id; assert resp.get("event_id") is None; assert resp.get("media") == []

def test_send_chat_message_with_media(authenticated_session, test_data_ids):
    global module_data
    auth_info = authenticated_session; community_id = test_data_ids['community_id']; bucket_name = auth_info['bucket_name']
    if not test_image_file_details: pytest.skip("Skipping Send HTTP Chat With Image.")
    chat_fields_media = {"content": f"Pytest Chat msg w/ media {datetime.now().strftime('%H%M%S')}"}
    chat_files_list = [('files', test_image_file_details)]
    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/chat/messages", f"Send HTTP Chat (Community {community_id} - With Image)", params={"community_id": community_id}, data=chat_fields_media, files=chat_files_list, expected_status=[201]) # Use data/files
    assert resp is not None; created_id = resp.get('message_id'); assert created_id is not None; module_data["created_chat_msg_id_with_media"] = created_id; print(f"    Stored created chat message ID: {created_id}")
    assert resp.get("content") == chat_fields_media["content"]; assert resp.get("user_id") == auth_info["user_id"]; assert resp.get("community_id") == community_id
    media_list = resp.get('media'); assert isinstance(media_list, list) and len(media_list) > 0; chat_image_url = media_list[0].get('url'); assert chat_image_url is not None; print(f"    Send chat returned media URL: {chat_image_url}")
    # verify_minio_upload(extract_minio_object_name(chat_image_url, bucket_name))

def test_get_chat_history_after_send(authenticated_session, test_data_ids):
    auth_info = authenticated_session; community_id = test_data_ids['community_id']
    created_msg_id = module_data.get("created_chat_msg_id_with_media")
    expect_media = created_msg_id is not None and test_image_file_details is not None
    if not created_msg_id: pytest.skip("Skipping chat history verification.")
    time.sleep(0.5)
    resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/chat/messages", f"Get Chat History (Comm {community_id}, Check Media)", params={"community_id": community_id, "limit": 10})
    assert resp is not None; assert isinstance(resp, list)
    found_msg_dict = next((m for m in resp if m.get('message_id') == created_msg_id), None); assert found_msg_dict is not None, f"Created chat msg {created_msg_id} not found."
    media_list = found_msg_dict.get('media', [])
    if expect_media: assert isinstance(media_list, list) and len(media_list) > 0, f"Chat msg {created_msg_id} media missing."; assert media_list[0].get('url') is not None; print(f"    Chat Media Check: SUCCESS - Found media for msg {created_msg_id}.")
    else: assert len(media_list) == 0, f"Chat msg {created_msg_id} unexpectedly has media."; print(f"    Chat Media Check: SUCCESS - No media found (as expected).")
