# backend/src/graphql/resolvers/mutation.py
import strawberry
from typing import Optional, List, Dict, Any # Keep basic type hints
# Correct paths for importing actual resolver functions
from .mutations.common import _get_authenticated_user_id
from .mutations.post import (
    create_post_resolver,
    update_post_resolver,
    delete_post_resolver
)
from .mutations.reply import (
    create_reply_resolver,
    delete_reply_resolver
)
from .mutations.community import (
    create_community_resolver,
    join_community_resolver,
    leave_community_resolver,
)
from .mutations.event import (
    create_event_resolver,
    join_event_resolver,
    leave_event_resolver,
)
from .mutations.user import (
    follow_user_resolver,
    unfollow_user_resolver
)
from .mutations.interaction import (
    cast_vote_resolver,
    remove_vote_resolver,
    add_favorite_resolver,
    remove_favorite_resolver
)

# --- GQL Type Imports (from where GQL types like PostType, UserType are defined) ---
# This path assumes types.py is in src/graphql/types.py
from ..types import (
    UserType, CommunityType, PostType, ReplyType, EventType, # Base Output Types
    PostCreateInput, PostUpdateInput, ReplyCreateInput,
    CommunityCreateInput, EventCreateInput, VoteInput # Input Types
)

@strawberry.type
class Mutation:
    # --- Post Mutations ---
    create_post: PostType = strawberry.mutation(
        resolver=create_post_resolver,
        description="Create a new post."
    )
    update_post: Optional[PostType] = strawberry.mutation(
        resolver=update_post_resolver,
        description="Update an existing post (must be owner)."
    )
    delete_post: bool = strawberry.mutation(
        resolver=delete_post_resolver,
        description="Delete a post (must be owner)."
    )

    # --- Reply Mutations ---
    create_reply: ReplyType = strawberry.mutation(
        resolver=create_reply_resolver,
        description="Create a new reply to a post or another reply."
    )
    delete_reply: bool = strawberry.mutation(
        resolver=delete_reply_resolver,
        description="Delete a reply (must be owner)."
    )

    # --- Community Mutations ---
    create_community: CommunityType = strawberry.mutation(
        resolver=create_community_resolver,
        description="Create a new community."
    )
    join_community: bool = strawberry.mutation(
        resolver=join_community_resolver,
        description="Join a community."
    )
    leave_community: bool = strawberry.mutation(
        resolver=leave_community_resolver,
        description="Leave a community."
    )

    # --- Event Mutations ---
    create_event: EventType = strawberry.mutation(
        resolver=create_event_resolver,
        description="Create a new event within a community."
    )
    join_event: bool = strawberry.mutation(
        resolver=join_event_resolver,
        description="Join an event."
    )
    leave_event: bool = strawberry.mutation(
        resolver=leave_event_resolver,
        description="Leave an event."
    )

    # --- User Interaction Mutations ---
    follow_user: bool = strawberry.mutation(
        resolver=follow_user_resolver,
        description="Follow another user."
    )
    unfollow_user: bool = strawberry.mutation(
        resolver=unfollow_user_resolver,
        description="Unfollow another user."
    )

    # --- Vote/Favorite Mutations ---
    cast_vote: bool = strawberry.mutation(
        resolver=cast_vote_resolver,
        description="Cast or update a vote on a post or reply."
    )
    remove_vote: bool = strawberry.mutation(
        resolver=remove_vote_resolver,
        description="Remove a vote from a post or reply."
    )
    add_favorite: bool = strawberry.mutation(
        resolver=add_favorite_resolver,
        description="Add a post or reply to favorites."
    )
    remove_favorite: bool = strawberry.mutation(
        resolver=remove_favorite_resolver,
        description="Remove a post or reply from favorites."
    )