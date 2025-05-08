# tests/test_replies.py
import pytest
import time
from .helpers import make_api_request, prepare_file_details, extract_minio_object_name, results
from datetime import datetime
from pathlib import Path
import os

pytestmark = pytest.mark.ordering(order=6)
test_image_file_details = None
module_data = {"created_reply_id_with_media": None}

@pytest.fixture(scope="module", autouse=True)
def load_files_and_init(authenticated_session): # Add session for potential cleanup
    global test_image_file_details
    module_data["created_reply_id_with_media"] = None
    img_path = os.getenv("TEST_IMAGE_PATH_ABS")
    test_image_file_details = prepare_file_details(img_path)
    if not test_image_file_details: print("WARN: Reply image tests skipped.")
    yield
    # Optional Teardown: Delete created reply
    created_id = module_data.get("created_reply_id_with_media")
    if created_id:
        print(f"\n--- Teardown: Attempting to delete reply {created_id} ---")
        auth_info = authenticated_session
        make_api_request(auth_info["session"], "DELETE", f"{auth_info['base_url']}/replies/{created_id}",
                         f"Teardown Delete Reply {created_id}", expected_status=[204, 404])


@pytest.mark.ordering(order=6.1)
def test_create_reply_no_media(authenticated_session, test_data_ids):
    auth_info = authenticated_session; post_id = test_data_ids['post_id']
    reply_fields = {"post_id": str(post_id), "content": f"Pytest reply no media {datetime.now().strftime('%H%M%S')}"}
    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/replies", "Create Reply (No Media)", data=reply_fields, expected_status=[201]) # Use data for form
    assert resp is not None; assert resp.get("content") == reply_fields["content"]; assert resp.get("user_id") == auth_info["user_id"]; assert resp.get("post_id") == post_id; assert resp.get("media") == []

@pytest.mark.ordering(order=6.2)
def test_create_reply_with_media(authenticated_session, test_data_ids):
    global module_data
    auth_info = authenticated_session; post_id = test_data_ids['post_id']; bucket_name = auth_info['bucket_name']
    if not test_image_file_details: pytest.skip("Skipping Create Reply with Image.")
    reply_fields_media = {"post_id": str(post_id), "content": f"Pytest reply w/ media {datetime.now().strftime('%H%M%S')}"}
    reply_files_list = [('files', test_image_file_details)]
    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/replies", "Create Reply (With Image)", data=reply_fields_media, files=reply_files_list, expected_status=[201]) # Use data/files
    assert resp is not None; created_id = resp.get('id'); assert created_id is not None; module_data["created_reply_id_with_media"] = created_id; print(f"    Stored created reply ID: {created_id}")
    assert resp.get("user_id") == auth_info["user_id"]; assert resp.get("post_id") == post_id
    media_list = resp.get('media'); assert isinstance(media_list, list) and len(media_list) > 0; reply_image_url = media_list[0].get('url'); assert reply_image_url is not None; print(f"    Create reply returned media URL: {reply_image_url}")
    # verify_minio_upload(extract_minio_object_name(reply_image_url, bucket_name))

@pytest.mark.ordering(order=6.3)
def test_get_replies_for_post(authenticated_session, test_data_ids):
    auth_info = authenticated_session; post_id = test_data_ids['post_id']
    created_reply_id = module_data.get("created_reply_id_with_media")
    expect_media = created_reply_id is not None and test_image_file_details is not None
    resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/replies/{post_id}", f"List Replies for Post {post_id} (Check Media)")
    assert resp is not None; assert isinstance(resp, list)
    if created_reply_id:
        found_reply_dict = next((r for r in resp if r.get('id') == created_reply_id), None)
        assert found_reply_dict is not None, f"Created reply {created_reply_id} not found."
        media_list = found_reply_dict.get('media', [])
        if expect_media:
            assert isinstance(media_list, list) and len(media_list) > 0, f"Reply {created_reply_id} media missing when expected." # Corrected Assertion message ID
            assert media_list[0].get('url') is not None, f"Reply {created_reply_id} media URL is null/missing."
            print(f"    Reply Media Check: SUCCESS - Found media for created reply {created_reply_id}.")
        else:
             assert len(media_list) == 0, f"Reply {created_reply_id} unexpectedly has media."
             print(f"    Reply Media Check: SUCCESS - No media found (as expected).")

@pytest.mark.ordering(order=6.4)
def test_favorite_unfavorite_reply(authenticated_session, test_data_ids):
    auth_info = authenticated_session; session = auth_info['session']; base_url = auth_info['base_url']
    reply_id_to_fav = module_data.get("created_reply_id_with_media") or test_data_ids['reply_id']
    print(f"--- Test: Favoriting/Unfavoriting Reply ID: {reply_id_to_fav} ---")
    resp_fav = make_api_request(session, "POST", f"{base_url}/replies/{reply_id_to_fav}/favorite", f"Favorite Reply {reply_id_to_fav}", data=None, expected_status=[200])
    assert resp_fav is not None and resp_fav.get("success") is True; fav_count_after_fav = resp_fav["new_counts"]["favorite_count"]; assert fav_count_after_fav > 0
    resp_unfav = make_api_request(session, "DELETE", f"{base_url}/replies/{reply_id_to_fav}/favorite", f"Unfavorite Reply {reply_id_to_fav}", expected_status=[200])
    assert resp_unfav is not None and resp_unfav.get("success") is True; assert resp_unfav.get("new_counts", {}).get("favorite_count", -1) == fav_count_after_fav - 1

# Optional: Delete test handled by fixture teardown
