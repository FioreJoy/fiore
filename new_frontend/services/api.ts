import { User, Post, Reply, Community, Event, ChatMessage } from '../types';
import { API_BASE_URL, FIORE_API_KEY } from '../constants';

class ApiService {
  private authToken: string | null = null;

  setAuthToken(token: string | null) {
    this.authToken = token;
  }

  async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      'X-API-Key': FIORE_API_KEY, // <-- CRITICAL FIX: Add API Key to all requests
      ...options.headers,
    };
    if (this.authToken) {
      headers['Authorization'] = `Bearer ${this.authToken}`;
    }
    if(options.body instanceof FormData) {
        // Let the browser set the Content-Type header for FormData
        delete (headers as any)['Content-Type'];
    }


    const response = await fetch(url, { ...options, headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ detail: 'An unknown error occurred' }));
      console.error("API Error:", response.status, errorData);
      throw new Error(errorData.detail || `HTTP error! status: ${response.status}`);
    }
    
    // For 204 No Content
    if (response.status === 204) {
        return {} as T;
    }

    return response.json();
  }
  
  // Auth
  async login(email: string, password: string): Promise<{ token: string }> {
      return this.request('/auth/login', {
          method: 'POST',
          body: JSON.stringify({ email, password }),
      });
  }

  async signup(formData: FormData): Promise<{ token: string }> {
      return this.request('/auth/signup', { // Corrected endpoint from register to signup
          method: 'POST',
          body: formData,
      });
  }

  async getMe(): Promise<User> {
      return this.request('/auth/me'); // Corrected endpoint to match backend
  }

  // User Profile
  async getUserProfile(userId: number): Promise<User> {
      return this.request(`/users/${userId}`);
  }
  
  async updateProfile(formData: FormData): Promise<User> {
      return this.request('/auth/me', { // Corrected endpoint to match backend
          method: 'PUT',
          body: formData,
      });
  }

  // Following
  async followUser(userId: number): Promise<void> {
      await this.request(`/users/${userId}/follow`, { method: 'POST' });
  }

  async unfollowUser(userId: number): Promise<void> {
      // Backend uses POST for this, not DELETE
      await this.request(`/users/${userId}/unfollow`, { method: 'POST' }); 
  }

  // Blocking
  async getBlockedUsers(): Promise<{ blocked_id: number }[]> {
      return this.request('/users/me/blocked');
  }

  async blockUser(userId: number): Promise<void> {
      await this.request(`/users/me/block/${userId}`, { method: 'POST' });
  }

  async unblockUser(userId: number): Promise<void> {
      await this.request(`/users/me/unblock/${userId}`, { method: 'DELETE' });
  }
  
  // Posts
  async getDiscoverFeed(): Promise<Post[]> {
      return this.request('/feed/discover');
  }
  
  async getPost(postId: number): Promise<Post> {
      return this.request(`/posts/${postId}`);
  }
  
  async getRepliesForPost(postId: number): Promise<Reply[]> {
      return this.request(`/replies/${postId}`);
  }
  
  async createReply(formData: FormData): Promise<Reply> {
      return this.request('/replies', {
          method: 'POST',
          body: formData
      });
  }
  
  // Voting & Favoriting
  async vote(postId: number | null, replyId: number | null, isUpvote: boolean): Promise<void> {
      await this.request('/votes', {
          method: 'POST',
          body: JSON.stringify({ post_id: postId, reply_id: replyId, vote_type: isUpvote })
      });
  }
  
  async favorite(postId: number | null, replyId: number | null): Promise<void> {
       const endpoint = postId ? `/posts/${postId}/favorite` : `/replies/${replyId}/favorite`;
       await this.request(endpoint, { method: 'POST' });
  }
  
  async unfavorite(postId: number | null, replyId: number | null): Promise<void> {
       const endpoint = postId ? `/posts/${postId}/favorite` : `/replies/${replyId}/favorite`;
       await this.request(endpoint, { method: 'DELETE' });
  }
  
  // Communities
  async getCommunities(): Promise<Community[]> {
      return this.request('/communities');
  }
  
  async getTrendingCommunities(): Promise<Community[]> {
      return this.request('/communities/trending');
  }

  async getMyCommunities(): Promise<Community[]> {
      return this.request('/users/me/communities');
  }

  async updateCommunity(communityId: number, formData: FormData): Promise<Community> {
      return this.request(`/communities/${communityId}`, { method: 'PUT', body: formData });
  }
  
  async updateCommunityLogo(communityId: number, formData: FormData): Promise<Community> {
      return this.request(`/communities/${communityId}/logo`, { method: 'POST', body: formData });
  }

  async deleteCommunity(communityId: number): Promise<void> {
      await this.request(`/communities/${communityId}`, { method: 'DELETE' });
  }


  // Events
  async getMyEvents(): Promise<Event[]> {
      return this.request('/users/me/events');
  }
  
  // Chat
  async getChatHistory(roomType: 'community' | 'event', roomId: number): Promise<ChatMessage[]> {
      return this.request(`/chat/messages?${roomType}_id=${roomId}`);
  }
}

export const api = new ApiService();