# backend/src/crud/__init__.py

from ._user import (
    get_user_by_email, get_user_by_id, create_user, update_user_profile,
    update_user_last_seen, delete_user, follow_user, unfollow_user,
    get_followers, get_following, get_user_graph_counts,
    # --- NEW USER EXPORTS ---
    get_user_joined_communities_graph,
    get_user_participated_events_graph,
    check_is_following,
    get_user_joined_communities_count,
    get_user_participated_events_count,
    get_post_ids_by_user,
    get_community_ids_joined_by_user,
    get_event_ids_participated_by_user
    # --- END NEW USER EXPORTS ---
)
from ._community import (
    create_community_db, get_community_by_id, get_communities_db, get_community_counts,
    update_community_details_db, update_community_logo_path_db, # <-- ADDED
    get_trending_communities_db, get_community_details_db, delete_community_db,
    join_community_db, leave_community_db, add_post_to_community_db,
    remove_post_from_community_db, get_community_members_graph, check_is_member,
    get_community_member_ids,
    get_community_event_ids,
    get_post_ids_for_community
)

from ._post import (
    create_post_db, get_post_by_id, get_post_counts, get_posts_db, delete_post_db,
    get_followed_posts_in_community_graph,
    get_reply_ids_for_post
)
from ._reply import (
    create_reply_db, get_reply_by_id, get_reply_counts, get_replies_for_post_db, delete_reply_db
)
from ._event import (
    create_event_db, get_event_by_id, get_event_participant_count, get_event_details_db,
    get_events_for_community_db, update_event_db, delete_event_db, join_event_db, leave_event_db,
    get_event_participants_graph,
    check_is_participating,
    get_event_participant_ids
)
from ._chat import (
    create_chat_message_db,
    get_chat_messages_db
)

from ._vote import (
    cast_vote_db,
    remove_vote_db,
    get_viewer_vote_status )

from ._favorite import (
    add_favorite_db,
    remove_favorite_db,
    get_viewer_favorite_status )

from ._graph import (
    execute_cypher,
    build_cypher_set_clauses,
    #get_graph_counts
)

from ._settings import (
    get_notification_settings,
    update_notification_settings)

from ._block import (
    block_user_db,
    unblock_user_db,
    get_blocked_users_db )

from ._media import (
    create_media_item, link_media_to_post, link_media_to_reply, link_media_to_chat_message,
    set_user_profile_picture, set_community_logo,
    get_media_items_for_post,
    get_media_items_for_reply,
    get_media_items_for_chat_message,
    get_user_profile_picture_media, get_community_logo_media,
    delete_media_item, get_media_item_by_id
)

from ._search import search_all

from ._feed import (
    get_following_feed,
    get_discover_feed)
# Import graph helpers only if they need to be used directly outside the crud package
# from ._graph import execute_cypher, build_cypher_set_clauses, get_graph_counts