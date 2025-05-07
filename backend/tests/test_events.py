# tests/test_events.py
import pytest
import time
from .helpers import make_api_request, prepare_file_details, extract_minio_object_name, results
from datetime import datetime, timezone, timedelta
from pathlib import Path
import os
import uuid # Import uuid

pytestmark = pytest.mark.ordering(order=4)
test_image_file_details = None
test_text_file_details = None
module_data = {"created_event_id": None}

@pytest.fixture(scope="module", autouse=True)
def load_files_and_init(authenticated_session):
    global test_image_file_details, test_text_file_details
    module_data["created_event_id"] = None
    img_path = os.getenv("TEST_IMAGE_PATH_ABS"); test_image_file_details = prepare_file_details(img_path)
    if not test_image_file_details: print("WARN: Event image tests skipped.")
    text_file_path = Path("./test_upload_events.txt").resolve()
    try: text_content_str = f"Event test {datetime.now()}"; text_content_bytes = text_content_str.encode('utf-8'); text_file_path.write_bytes(text_content_bytes); test_text_file_details = (text_file_path.name, text_content_bytes, 'text/plain'); print(f"✅ Event test text file ready: {text_file_path}")
    except Exception as e: print(f"⚠️ Warning: Could not prepare event text file: {e}")
    yield
    created_id = module_data.get("created_event_id")
    if created_id:
        print(f"\n--- Teardown: Attempting to delete event {created_id} ---")
        auth_info = authenticated_session
        make_api_request(auth_info["session"], "DELETE", f"{auth_info['base_url']}/events/{created_id}", f"Teardown Delete Event {created_id}", expected_status=[204, 404])
    if text_file_path.exists():
        try: text_file_path.unlink(); print(f"🧹 Cleaned up event test file: {text_file_path}")
        except Exception as e: print(f"⚠️ Error cleaning up event test file: {e}")

@pytest.mark.ordering(order=4.1)
def test_create_event_with_image(authenticated_session, test_data_ids):
    global module_data
    auth_info = authenticated_session; community_id = test_data_ids['community_id']; session = auth_info['session']; base_url = auth_info['base_url']; bucket_name = auth_info['bucket_name']
    if not test_image_file_details: pytest.skip("Skipping Create Event with Image: No image file provided.")
    event_fields = {"title": f"Pytest Event w/ Img {datetime.now().strftime('%H%M%S')}", "description": "Banner!", "location": "Virtual", "event_timestamp": (datetime.now(timezone.utc) + timedelta(days=14)).isoformat(), "max_participants": "50"}
    event_files = {'image': test_image_file_details}
    resp = make_api_request(session, "POST", f"{base_url}/communities/{community_id}/events", "Create Event (With Image)", data=event_fields, files=event_files, expected_status=[201]) # Removed is_json
    assert resp is not None; created_id = resp.get('id'); assert created_id is not None
    module_data["created_event_id"] = created_id; print(f"    Stored created event ID: {created_id}")
    assert resp.get("title") == event_fields["title"]; assert resp.get("community_id") == community_id; assert resp.get("creator_id") == auth_info["user_id"]
    image_url = resp.get('image_url'); assert image_url is not None; print(f"    Create event returned image URL: {image_url}")
    obj_name = extract_minio_object_name(image_url, bucket_name); assert obj_name is not None
    # verify_minio_upload(obj_name)

@pytest.mark.ordering(order=4.2)
def test_get_event_details(authenticated_session, test_data_ids):
    auth_info = authenticated_session; session = auth_info['session']; base_url = auth_info['base_url']
    event_id_to_get = module_data.get("created_event_id") or test_data_ids['event_id']
    created_with_image = module_data.get("created_event_id") is not None and test_image_file_details is not None
    print(f"--- Test: Getting details for Event ID: {event_id_to_get} ---")
    resp = make_api_request(session, "GET", f"{base_url}/events/{event_id_to_get}", f"Get Event {event_id_to_get} Details")
    assert resp is not None; assert resp.get("id") == event_id_to_get
    image_url = resp.get('image_url')
    if created_with_image: assert image_url is not None, f"Event {event_id_to_get} details missing image_url when expected."; print(f"    Get Event Details Check: Image URL found: {image_url}")
    else: print(f"    Get Event Details Check: Image URL presence check skipped.")

@pytest.mark.ordering(order=4.3)
def test_join_leave_event(authenticated_session, test_data_ids):
    auth_info = authenticated_session; event_id = module_data.get("created_event_id") or test_data_ids['event_id']
    session = auth_info['session']; base_url = auth_info['base_url']
    print(f"--- Test: Joining/Leaving Event ID: {event_id} ---")
    resp_join = make_api_request(session, "POST", f"{base_url}/events/{event_id}/join", f"Join Event {event_id}", data=None, expected_status=[200])
    assert resp_join is not None and resp_join.get("success") is True
    resp_leave = make_api_request(session, "DELETE", f"{base_url}/events/{event_id}/leave", f"Leave Event {event_id}", expected_status=[200])
    assert resp_leave is not None and resp_leave.get("success") is True

@pytest.mark.ordering(order=4.4)
def test_update_event_image(authenticated_session):
    event_id = module_data.get("created_event_id")
    if not event_id: pytest.skip("Skipping Update Event Image: No event was created in this module run.")
    if not test_text_file_details: pytest.skip("Skipping Update Event Image: No text test file available.")
    auth_info = authenticated_session; base_url = auth_info['base_url']; session = auth_info['session']; bucket_name = auth_info['bucket_name']
    print(f"--- Test: Updating image for Event ID: {event_id} ---")
    update_event_files = {'image': test_text_file_details}
    details_before = make_api_request(session, "GET", f"{base_url}/events/{event_id}", f"Get Event {event_id} Details (Before Image Update)")
    original_image_url = details_before.get("image_url") if details_before else None
    original_obj_name = extract_minio_object_name(original_image_url, bucket_name)

    update_resp = make_api_request(session, "PUT", f"{base_url}/events/{event_id}", "Update Event Image", files=update_event_files, expected_status=[200]) # Removed is_json
    assert update_resp is not None; updated_image_url = update_resp.get('image_url'); assert updated_image_url is not None; print(f"    Update event returned image URL: {updated_image_url}")
    updated_obj_name = extract_minio_object_name(updated_image_url, bucket_name)
    # verify_minio_upload(updated_obj_name)
    assert updated_image_url != original_image_url, "Event image URL did not change after update"
    assert updated_obj_name != original_obj_name, "Event image object name did not change after update"
    print("    Update Check: Event image URL changed.")

    time.sleep(0.5)
    details_after = make_api_request(session, "GET", f"{base_url}/events/{event_id}", f"Get Event {event_id} Details (After Image Update)")
    assert details_after is not None; url_after_update = details_after.get("image_url"); obj_name_after_update = extract_minio_object_name(url_after_update, bucket_name)
    assert obj_name_after_update == updated_obj_name, "Event image URL mismatch after update (persistence check)"
    print("    Update Persistence Check: New Event Image URL persisted.")
