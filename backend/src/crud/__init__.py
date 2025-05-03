# backend/src/crud/__init__.py

from ._user import (
    get_user_by_email, get_user_by_id, create_user, update_user_profile,
    update_user_last_seen, delete_user, follow_user, unfollow_user,
    get_followers, get_following, get_user_graph_counts,
    # --- NEW USER EXPORTS ---
    get_user_joined_communities_graph,
    get_user_participated_events_graph
    # --- END NEW USER EXPORTS ---
)
from ._community import (
    create_community_db, get_community_by_id, get_communities_db, get_community_counts,
    update_community_details_db, update_community_logo_path_db, get_trending_communities_db,
    get_community_details_db, delete_community_db, join_community_db, leave_community_db,
    add_post_to_community_db, remove_post_from_community_db,
    # --- NEW COMMUNITY EXPORT ---
    get_community_members_graph
    # --- END NEW COMMUNITY EXPORT ---
)
from ._post import (
    create_post_db, get_post_by_id, get_post_counts, get_posts_db, delete_post_db,
    # --- NEW POST EXPORT ---
    get_followed_posts_in_community_graph
    # --- END NEW POST EXPORT ---
)
from ._reply import (
    create_reply_db, get_reply_by_id, get_reply_counts, get_replies_for_post_db, delete_reply_db
)
from ._event import (
    create_event_db, get_event_by_id, get_event_participant_count, get_event_details_db,
    get_events_for_community_db, update_event_db, delete_event_db, join_event_db, leave_event_db,
    # --- NEW EVENT EXPORT ---
    get_event_participants_graph
    # --- END NEW EVENT EXPORT ---
)
from ._chat import (
    create_chat_message_db,
    get_chat_messages_db
)
from ._vote import (
    cast_vote_db,
    remove_vote_db
)
from ._favorite import (
    add_favorite_db,
    remove_favorite_db
)

# Import graph helpers only if they need to be used directly outside the crud package
# from ._graph import execute_cypher, build_cypher_set_clauses, get_graph_counts