# backend/src/crud/__init__.py

# Import functions from specific modules to make them available directly under 'crud'
# e.g., from ._user import get_user_by_id, create_user, ...
# This allows usage like: from .. import crud; crud.get_user_by_id(...)

from ._user import (
    get_user_by_email, get_user_by_id, create_user, update_user_profile,
    update_user_last_seen, delete_user, follow_user, unfollow_user,
    get_followers, get_following, get_user_graph_counts
)
from ._community import (
    create_community_db, get_community_by_id, get_communities_db, get_community_counts,
    update_community_details_db, update_community_logo_path_db, get_trending_communities_db,
    get_community_details_db, delete_community_db, join_community_db, leave_community_db,
    add_post_to_community_db, remove_post_from_community_db
)
from ._post import (
    create_post_db, get_post_by_id, get_post_counts, get_posts_db, delete_post_db
)
from ._reply import (
    create_reply_db, get_reply_by_id, get_reply_counts, get_replies_for_post_db, delete_reply_db
)
from ._event import ( # Assuming _event.py was created similarly
    create_event_db, get_event_by_id, get_event_participant_count, get_event_details_db,
    get_events_for_community_db, update_event_db, delete_event_db, join_event_db, leave_event_db
)
# Assuming _chat.py exists or will be created for chat persistence if needed beyond relational
# from ._chat import ...

# --- NEW Imports for Vote and Favorite ---
from ._vote import (
    cast_vote_db,
    remove_vote_db
)
from ._favorite import (
    add_favorite_db,
    remove_favorite_db
)

from ._chat import (
    create_chat_message_db,
    get_chat_messages_db
)
# --- END NEW Imports ---

# You can also define shared helper functions here if necessary,
# but utils.py is generally better for that.
