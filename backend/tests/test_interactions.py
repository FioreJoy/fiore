# tests/test_interactions.py
import pytest
from .helpers import make_api_request, results
from datetime import datetime

pytestmark = pytest.mark.ordering(order=7)

@pytest.fixture(scope="module")

def created_post(authenticated_session, test_data_ids):

    """Creates a post and returns its ID."""

    auth_info = authenticated_session

    community_id = test_data_ids['community_id']

    post_fields = {"title": f"Pytest Interactions Post {datetime.now().strftime('%H%M%S')}", "content": "Test.", "community_id": str(community_id)}

    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/posts", "Create Post (for interactions test)", data=post_fields, expected_status=[201])

    assert resp is not None

    return resp.get("id")



@pytest.fixture(scope="module")

def created_reply(authenticated_session, created_post):

    """Creates a reply for the created post and returns its ID."""

    auth_info = authenticated_session

    post_id = created_post

    reply_fields = {"post_id": str(post_id), "content": f"Pytest Interactions Reply {datetime.now().strftime('%H%M%S')}"}

    resp = make_api_request(auth_info["session"], "POST", f"{auth_info['base_url']}/replies", "Create Reply (for interactions test)", data=reply_fields, expected_status=[201])

    assert resp is not None

    return resp.get("id")



def test_vote_post(authenticated_session, created_post):

    auth_info = authenticated_session; post_id = created_post; base_url = auth_info['base_url']; session = auth_info['session']

    print(f"--- Test: Voting on Post ID: {post_id} ---")



    # STEP 1: Ensure an UPVOTE is set

    vote_data_up = {"post_id": post_id, "reply_id": None, "vote_type": True}

    resp_set_upvote = make_api_request(session, "POST", f"{base_url}/votes", f"Set Upvote Post {post_id}", json_data=vote_data_up, expected_status=[200])

    assert resp_set_upvote is not None and resp_set_upvote.get("success") is True



def test_vote_reply(authenticated_session, created_reply):

    auth_info = authenticated_session; reply_id = created_reply; base_url = auth_info['base_url']; session = auth_info['session']

    print(f"--- Test: Voting on Reply ID: {reply_id} ---")



    # STEP 1: Ensure an UPVOTE is set

    vote_data_up = {"post_id": None, "reply_id": reply_id, "vote_type": True}

    print("Action: Attempting to set/ensure UPVOTE on reply")

    resp_set_upvote = make_api_request(session, "POST", f"{base_url}/votes", f"Set Upvote Reply {reply_id}", json_data=vote_data_up, expected_status=[200])

    assert resp_set_upvote is not None and resp_set_upvote.get("success") is True