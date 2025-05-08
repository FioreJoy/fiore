# tests/test_communities.py
import pytest
import time
from .helpers import make_api_request, prepare_file_details, extract_minio_object_name, results
from datetime import datetime
from pathlib import Path
import os

pytestmark = pytest.mark.ordering(order=3)
test_image_file_details = None
module_data = {"created_community_id": None}

@pytest.fixture(scope="module", autouse=True)
def load_files_and_init(authenticated_session):
    global test_image_file_details
    module_data["created_community_id"] = None
    img_path = os.getenv("TEST_IMAGE_PATH_ABS")
    test_image_file_details = prepare_file_details(img_path)
    if not test_image_file_details: print("WARN: Community image tests skipped.")
    yield
    created_id = module_data.get("created_community_id")
    if created_id:
        print(f"\n--- Teardown: Attempting to delete community {created_id} ---")
        auth_info = authenticated_session
        make_api_request(auth_info["session"], "DELETE", f"{auth_info['base_url']}/communities/{created_id}",
                         f"Teardown Delete Community {created_id}", expected_status=[204, 404])

@pytest.mark.ordering(order=3.1)
def test_create_community(authenticated_session):
    global module_data
    auth_info = authenticated_session
    community_name = f"Pytest Community {datetime.now().strftime('%H%M%S%f')}"
    community_data = {"name": community_name, "description": "Test", "primary_location": "(11.0, 11.0)", "interest": "Music"}
    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/communities", "Create Community", data=community_data, expected_status=[201]) # Use data for form
    assert resp is not None and resp.get("name") == community_data["name"]
    created_id = resp.get("id"); assert created_id is not None
    module_data["created_community_id"] = created_id; print(f"    Stored created community ID: {created_id}")

@pytest.mark.ordering(order=3.2)
def test_list_communities(authenticated_session, test_data_ids):
    auth_info = authenticated_session
    resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/communities", "List Communities")
    assert isinstance(resp, list)
    target_id = test_data_ids['community_id']; created_id = module_data.get("created_community_id")
    assert any(c.get('id') == target_id for c in resp)
    if created_id: assert any(c.get('id') == created_id for c in resp)
    else: pytest.skip("Skipping created community list check.")

@pytest.mark.ordering(order=3.3)
def test_list_trending_communities(authenticated_session):
    auth_info = authenticated_session
    resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/communities/trending", "List Trending Communities", expected_status=[200])
    assert isinstance(resp, list)

@pytest.mark.ordering(order=3.4)
def test_get_community_details(authenticated_session, test_data_ids):
    auth_info = authenticated_session; community_id = test_data_ids['community_id']
    resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/communities/{community_id}/details", f"Get Community {community_id} Details")
    assert resp is not None and resp.get("id") == community_id

@pytest.mark.ordering(order=3.5)
def test_join_leave_community(authenticated_session, test_data_ids):
    auth_info = authenticated_session; community_id = test_data_ids['community_id']; session=auth_info["session"]; base_url=auth_info['base_url']
    resp_join = make_api_request(session, "POST", f"{base_url}/communities/{community_id}/join", f"Join Community {community_id}", data=None, expected_status=[200])
    assert resp_join is not None and resp_join.get("success") is True
    resp_leave = make_api_request(session, "DELETE", f"{base_url}/communities/{community_id}/leave", f"Leave Community {community_id}", expected_status=[200])
    assert resp_leave is not None and resp_leave.get("success") is True

@pytest.mark.ordering(order=3.6)
def test_link_unlink_post_community(authenticated_session, test_data_ids):
    auth_info = authenticated_session; community_id = test_data_ids['community_id']; session=auth_info["session"]; base_url=auth_info['base_url']
    post_to_link = test_data_ids['post_id_to_link']; post_in_comm = test_data_ids['post_id_in_comm']
    resp_add = make_api_request(session, "POST", f"{base_url}/communities/{community_id}/posts/{post_to_link}", f"Add Post {post_to_link} to Community {community_id}", data=None, expected_status=[201])
    assert resp_add is not None and resp_add.get("success") is True
    resp_remove = make_api_request(session, "DELETE", f"{base_url}/communities/{community_id}/posts/{post_to_link}", f"Remove Post {post_to_link} from Community {community_id}", expected_status=[200])
    assert resp_remove is not None and resp_remove.get("success") is True
    resp_remove_existing = make_api_request(session, "DELETE", f"{base_url}/communities/{community_id}/posts/{post_in_comm}", f"Remove Already Linked Post {post_in_comm}", expected_status=[200])
    assert resp_remove_existing is not None
    make_api_request(session, "POST", f"{base_url}/communities/{community_id}/posts/{post_in_comm}", f"Re-Add Post {post_in_comm} to Community {community_id}", data=None, expected_status=[201])

@pytest.mark.ordering(order=3.7)
def test_list_community_events(authenticated_session, test_data_ids):
    auth_info = authenticated_session; community_id = test_data_ids['community_id']; session=auth_info["session"]; base_url=auth_info['base_url']
    resp = make_api_request(session, "GET", f"{base_url}/communities/{community_id}/events", f"List Events for Community {community_id}")
    assert isinstance(resp, list)

@pytest.mark.ordering(order=3.8)
def test_update_community_logo(authenticated_session, test_data_ids):
    if not test_image_file_details: pytest.skip("Skipping Community Logo update test - No image provided.")
    auth_info = authenticated_session; community_id = test_data_ids['community_id']; base_url = auth_info['base_url']; session = auth_info['session']; bucket_name = auth_info['bucket_name']
    logo_files = {'logo': test_image_file_details}
    logo_update_resp = make_api_request(session, "POST", f"{base_url}/communities/{community_id}/logo", f"Update Community {community_id} Logo", files=logo_files, expected_status=[200]) # Removed is_json
    assert logo_update_resp is not None; logo_obj_name_expected = None; new_logo_url = logo_update_resp.get('logo_url'); assert new_logo_url is not None; print(f"    Logo update returned URL: {new_logo_url}")
    logo_obj_name_expected = extract_minio_object_name(new_logo_url, bucket_name)
    time.sleep(0.5)
    details_resp = make_api_request(session, "GET", f"{base_url}/communities/{community_id}/details", f"Get Community {community_id} Details (After Logo Update)")
    assert details_resp is not None; url_after = details_resp.get("logo_url"); assert url_after is not None
    obj_name_after = extract_minio_object_name(url_after, bucket_name); print(f"    Details after update show logo URL: {url_after}")
    assert obj_name_after == logo_obj_name_expected, f"Logo URL mismatch after update. Expected obj: {logo_obj_name_expected}, Got obj: {obj_name_after}"
    print("    Update Persistence Check: Logo URL updated and persisted.")

# Note: Delete test is handled by the fixture teardown
