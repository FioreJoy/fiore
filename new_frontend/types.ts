
export interface MediaItem {
  id: number;
  url: string;
  mime_type: string;
  file_size_bytes?: number;
  original_filename?: string;
  width?: number;
  height?: number;
}

export interface User {
  id: number;
  name: string;
  username: string;
  email: string;
  gender: string;
  college?: string;
  image_url?: string;
  created_at: string;
  last_seen?: string;
  interests: string[];
  followers_count: number;
  following_count: number;
  is_following: boolean;
}

export interface Reply {
  id: number;
  post_id: number;
  user_id: number;
  content: string;
  parent_reply_id?: number;
  created_at: string;
  author_name?: string;
  author_avatar_url?: string;
  upvotes: number;
  downvotes: number;
  media: MediaItem[];
  viewer_vote_type?: 'UP' | 'DOWN' | null;
  viewer_has_favorited: boolean;
}

export interface Post {
  id: number;
  user_id: number;
  title: string;
  content: string;
  created_at: string;
  author_name?: string;
  author_avatar_url?: string;
  upvotes: number;
  downvotes: number;
  reply_count: number;
  community_id?: number;
  community_name?: string;
  media: MediaItem[];
  viewer_vote_type?: 'UP' | 'DOWN' | null;
  viewer_has_favorited: boolean;
}

export interface Community {
  id: number;
  name: string;
  description?: string;
  created_by: number;
  created_at: string;
  interest?: string;
  logo_url?: string;
  member_count: number;
  online_count: number; // Placeholder
  is_member_by_viewer: boolean;
}

export interface Event {
    id: number;
    community_id: number;
    creator_id: number;
    title: string;
    description?: string;
    location: string;
    event_timestamp: string;
    max_participants: number;
    image_url?: string;
    created_at: string;
    participant_count: number;
    is_participating_by_viewer: boolean;
}


export interface ChatMessage {
  message_id: number;
  community_id?: number;
  event_id?: number;
  user_id: number;
  username: string;
  content: string;
  timestamp: string;
  media: MediaItem[];
}
