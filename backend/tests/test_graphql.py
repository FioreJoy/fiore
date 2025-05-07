# tests/test_graphql.py
import pytest
from .helpers import make_api_request, results
import json
import os # Import os

# Import created ID from posts test module
# Note: Relies on test execution order if using global variable
# Better approach: use pytest fixtures with broader scope or temp files/DB state
try:
    from .test_posts import module_data as posts_module_data
except ImportError:
    posts_module_data = {"created_post_id_with_media": None}


pytestmark = pytest.mark.ordering(order=10)

@pytest.fixture(scope="module")
def post_id_for_gql(test_data_ids):
    """Provides the post ID to use for GraphQL tests."""
    # Use the one created with media if available, otherwise fallback
    return posts_module_data.get("created_post_id_with_media") or test_data_ids['post_id']


def test_graphql_get_viewer(authenticated_session):
    auth_info = authenticated_session
    gql_query = {"query": "query { viewer { id username email } }"}
    # *** MODIFICATION: Removed use_api_key=False, API key will be sent by default via session ***
    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/graphql", "GraphQL Get Viewer", json_data=gql_query, expected_status=[200])
    # *** END MODIFICATION ***
    assert resp is not None and "data" in resp; viewer_data = resp["data"].get("viewer"); assert viewer_data is not None; assert viewer_data.get("id") == str(auth_info["user_id"]); assert viewer_data.get("username") is not None; print(f"    GraphQL Viewer Check: ID {viewer_data.get('id')} matches.")

def test_graphql_get_user(authenticated_session, test_data_ids):
    auth_info = authenticated_session; target_user_id = test_data_ids['target_user_id']
    gql_query = {"query": "query GetUser($userId: ID!) { user(id: $userId) { id username name followersCount } }", "variables": {"userId": str(target_user_id)}}
    # *** MODIFICATION: Removed use_api_key=False ***
    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/graphql", f"GraphQL Get User {target_user_id}", json_data=gql_query, expected_status=[200])
    # *** END MODIFICATION ***
    assert resp is not None and "data" in resp; user_data = resp["data"].get("user"); assert user_data is not None; assert user_data.get("id") == str(target_user_id); assert user_data.get("username") is not None; assert "followersCount" in user_data; print(f"    GraphQL User Check: ID {user_data.get('id')} received.")

def test_graphql_get_post_with_media(authenticated_session, post_id_for_gql):
    auth_info = authenticated_session
    post_id_to_query = post_id_for_gql # Get ID from fixture
    print(f"--- Testing GraphQL Get Post with Media (ID: {post_id_to_query}) ---")
    gql_query = {"query": "query GetPostWithMedia($postId: ID!) { post(id: $postId) { id title media { id url mimeType } } }", "variables": {"postId": str(post_id_to_query)}}
    # *** MODIFICATION: Removed use_api_key=False ***
    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/graphql", f"GraphQL Get Post {post_id_to_query} with Media", json_data=gql_query, expected_status=[200])
    # *** END MODIFICATION ***
    assert resp is not None; assert "data" in resp; post_data = resp["data"].get("post"); assert post_data is not None; assert post_data.get("id") == str(post_id_to_query)
    media_list = post_data.get("media"); assert isinstance(media_list, list)
    print(f"    GraphQL Post Media Check: Retrieved media list (count: {len(media_list)}) for post {post_id_to_query}.")
    # Cannot reliably assert count/content without knowing exact state from test_posts run