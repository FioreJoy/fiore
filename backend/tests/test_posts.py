# tests/test_posts.py
import pytest
from .helpers import make_api_request, prepare_file_details, extract_minio_object_name, results
from datetime import datetime
import os
from pathlib import Path

pytestmark = pytest.mark.ordering(order=5) # Changed order to run after communities/events

test_image_file_details = None
test_text_file_details = None
# Use module_data dict for shared state within this module
module_data = {"created_post_id_with_media": None}

@pytest.fixture(scope="module", autouse=True)
def load_files_and_init_post_id(authenticated_session): # Add session for potential cleanup
    global test_image_file_details, test_text_file_details
    module_data["created_post_id_with_media"] = None

    img_path = os.getenv("TEST_IMAGE_PATH_ABS")
    test_image_file_details = prepare_file_details(img_path)
    if not test_image_file_details: print("WARN: Post image tests skipped.")

    text_file_path = Path("./test_upload_posts.txt").resolve()
    try:
        text_content = f"Posts test file {datetime.now()}".encode('utf-8')
        text_file_path.write_bytes(text_content)
        test_text_file_details = (text_file_path.name, text_content, 'text/plain')
        print(f"✅ Posts test text file ready: {text_file_path}")
    except Exception as e: print(f"⚠️ Warning: Could not prepare posts text file: {e}")

    yield # Run tests

    # Teardown: Delete created post and text file
    created_id = module_data.get("created_post_id_with_media")
    if created_id:
        print(f"\n--- Teardown: Attempting to delete post {created_id} ---")
        auth_info = authenticated_session
        make_api_request(auth_info["session"], "DELETE", f"{auth_info['base_url']}/posts/{created_id}",
                         f"Teardown Delete Post {created_id}", expected_status=[204, 404])
    if text_file_path.exists():
        try: text_file_path.unlink(); print(f"🧹 Cleaned up post test file: {text_file_path}")
        except Exception as e: print(f"⚠️ Error cleaning up post test file: {e}")


@pytest.mark.ordering(order=5.1)
def test_create_post_no_media(authenticated_session, test_data_ids):
    auth_info = authenticated_session
    post_fields = {"title": f"Pytest Post NoMedia {datetime.now().strftime('%H%M%S')}", "content": "Test.", "community_id": str(test_data_ids['community_id'])}
    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/posts", "Create Post (No Media)", data=post_fields, expected_status=[201]) # Use data for form
    assert resp is not None; assert resp.get("title") == post_fields["title"]; assert resp.get("user_id") == auth_info["user_id"]; assert resp.get("media") == []

@pytest.mark.ordering(order=5.2)
def test_create_post_with_media(authenticated_session, test_data_ids):
    global module_data
    auth_info = authenticated_session
    if not test_image_file_details and not test_text_file_details: pytest.skip("Skipping multi-media post test: No test files.")
    post_fields_multi = {"title": f"Pytest Post MultiMedia {datetime.now().strftime('%H%M%S')}", "content": "Files!", "community_id": str(test_data_ids['community_id'])}
    post_files_multi_tuples = []
    if test_image_file_details: post_files_multi_tuples.append(('files', test_image_file_details))
    if test_text_file_details: post_files_multi_tuples.append(('files', test_text_file_details))
    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/posts", "Create Post (With Multiple Media)", data=post_fields_multi, files=post_files_multi_tuples, expected_status=[201]) # Use data/files
    assert resp is not None; created_id = resp.get('id'); assert created_id is not None; module_data["created_post_id_with_media"] = created_id; print(f"    Stored created post ID: {created_id}")
    assert resp.get("user_id") == auth_info["user_id"]; media_list = resp.get('media'); expected_media_count = len(post_files_multi_tuples)
    assert isinstance(media_list, list) and len(media_list) == expected_media_count, f"Media count mismatch create (Got {len(media_list)}, Expect {expected_media_count})"
    print(f"    Media Count Check (Create): SUCCESS ({len(media_list)}/{expected_media_count})")
    for item in media_list: assert isinstance(item, dict) and item.get('url'), "Invalid media item format/URL"

@pytest.mark.ordering(order=5.3)
def test_get_created_post_details(authenticated_session):
    created_id = module_data.get("created_post_id_with_media")
    if not created_id: pytest.skip("Skipping test: No post with media was created.")
    auth_info = authenticated_session
    expected_media_count = 0;
    if test_image_file_details: expected_media_count += 1
    if test_text_file_details: expected_media_count += 1
    resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/posts/{created_id}", f"Get Created Post {created_id} Details")
    assert resp is not None; assert resp.get("id") == created_id; assert resp.get("user_id") == auth_info["user_id"]
    media_list = resp.get('media'); assert isinstance(media_list, list) and len(media_list) == expected_media_count, f"Media count mismatch GET (Got {len(media_list)}, Expect {expected_media_count})"
    print(f"    Single Post Media Count Check (GET): SUCCESS ({len(media_list)}/{expected_media_count})")
    for item in media_list: assert isinstance(item, dict) and item.get('url'), "Invalid media item format/URL in GET"

@pytest.mark.ordering(order=5.4)
def test_list_posts(authenticated_session, test_data_ids):
    auth_info = authenticated_session; session = auth_info['session']; base_url = auth_info['base_url']; community_id = test_data_ids['community_id']; user_id = auth_info['user_id']
    resp_general = make_api_request(session, "GET", f"{base_url}/posts", "List Posts (General)", params={"limit": 5}); assert isinstance(resp_general, list)
    resp_comm = make_api_request(session, "GET", f"{base_url}/posts", f"List Posts (Community)", params={"community_id": community_id, "limit": 5}); assert isinstance(resp_comm, list)
    resp_user = make_api_request(session, "GET", f"{base_url}/posts", f"List Posts (User)", params={"user_id": user_id, "limit": 5}); assert isinstance(resp_user, list); assert all(p.get('user_id') == user_id for p in resp_user)

@pytest.mark.ordering(order=5.5)
def test_list_trending_posts(authenticated_session):
    auth_info = authenticated_session
    resp = make_api_request(auth_info["session"], "GET", f"{auth_info['base_url']}/posts/trending", "List Trending Posts", expected_status=[200])
    assert isinstance(resp, list), "Trending posts did not return a list"

@pytest.mark.ordering(order=5.6)
def test_favorite_unfavorite_post(authenticated_session):
    post_id = module_data.get("created_post_id_with_media")
    if not post_id: pytest.skip("Skipping favorite test: No post was created.")
    auth_info = authenticated_session; session = auth_info['session']; base_url = auth_info['base_url']
    resp_fav = make_api_request(session, "POST", f"{base_url}/posts/{post_id}/favorite", f"Favorite Post {post_id}", data=None, expected_status=[200])
    assert resp_fav is not None and resp_fav.get("success") is True; fav_count_after_fav = resp_fav["new_counts"]["favorite_count"]; assert fav_count_after_fav > 0
    resp_unfav = make_api_request(session, "DELETE", f"{base_url}/posts/{post_id}/favorite", f"Unfavorite Post {post_id}", expected_status=[200])
    assert resp_unfav is not None and resp_unfav.get("success") is True; assert resp_unfav.get("new_counts", {}).get("favorite_count", -1) == fav_count_after_fav - 1

# Note: Deletion test is handled by the fixture teardown
