import React, { useState, useEffect, useCallback } from 'react';
import { useParams } from 'react-router-dom';
import { Community, Post } from '../types';
import { api } from '../services/api';
import Spinner from '../components/Spinner';
import PostCard from '../components/PostCard';
import { useAuth } from '../hooks/useAuth';

const CommunityPage: React.FC = () => {
  const { communityId } = useParams<{ communityId: string }>();
  const communityIdNum = Number(communityId);
  const { user } = useAuth();

  const [community, setCommunity] = useState<Community | null>(null);
  const [posts, setPosts] = useState<Post[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    if (!communityIdNum) return;
    setIsLoading(true);
    try {
      // In a real app, these would be separate, dedicated API calls in the api service.
      // e.g., api.getCommunity(communityIdNum)
      const communityData = await api.request<Community>(`/communities/${communityIdNum}`);
      const postsData = await api.request<Post[]>(`/posts?community_id=${communityIdNum}`);
      
      setCommunity(communityData);
      setPosts(postsData);
      setError(null);
    } catch (err: any) {
      setError(err.message || `Failed to fetch community details for ID ${communityIdNum}.`);
    } finally {
      setIsLoading(false);
    }
  }, [communityIdNum]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Placeholder handler for joining/leaving a community
  const handleJoinLeave = () => {
      if (!community) return;
      // This would typically involve an API call, e.g., api.joinCommunity(community.id)
      // For this placeholder, we'll just do an optimistic update.
      setCommunity({
          ...community,
          is_member_by_viewer: !community.is_member_by_viewer,
          member_count: community.is_member_by_viewer ? community.member_count - 1 : community.member_count + 1,
      });
  };

  const handleCreatePost = () => {
      // This would navigate to a create post page, with the community pre-selected
      console.log('Navigate to create post for community', community?.id);
  };
  
  if (isLoading) return <Spinner />;
  if (error) return <div className="text-center text-red-400 p-4">{error}</div>;
  if (!community) return <div className="text-center text-text-secondary p-4">Community not found.</div>;

  return (
    <div>
      <div className="bg-surface rounded-lg p-6 md:p-8 mb-6 shadow-lg">
        <div className="flex flex-col md:flex-row items-center gap-6">
            <img
              src={community.logo_url || `https://picsum.photos/seed/${community.id}/200/200`}
              alt={`${community.name} logo`}
              className="w-24 h-24 rounded-full border-4 border-primary object-cover"
            />
             <div className="flex-1 text-center md:text-left">
              <h1 className="text-3xl font-bold text-text-primary">{community.name}</h1>
              <p className="text-text-secondary mt-1">{community.description}</p>
              <div className="flex justify-center md:justify-start items-center gap-4 mt-3 text-sm text-text-secondary">
                 <span><span className="font-bold text-text-primary">{community.member_count}</span> members</span>
                 <span className="bg-secondary/20 text-secondary text-xs font-semibold px-2 py-1 rounded-full">{community.interest}</span>
              </div>
            </div>
            <div className="flex flex-col items-center md:items-end gap-2">
                 <button onClick={handleJoinLeave} className={`font-bold py-2 px-6 rounded-full w-40 transition-colors ${community.is_member_by_viewer ? 'bg-gray-600 hover:bg-red-600' : 'bg-primary hover:bg-indigo-700'}`}>
                    {community.is_member_by_viewer ? 'Leave' : 'Join'}
                </button>
                <button onClick={handleCreatePost} className="font-bold py-2 px-6 rounded-full w-40 transition-colors bg-secondary hover:bg-teal-600">
                    Create Post
                </button>
            </div>
        </div>
      </div>
      
      <h2 className="text-xl font-bold mb-4">Posts in {community.name}</h2>
       {posts.length === 0 ? (
          <p className="text-center text-text-secondary bg-surface p-8 rounded-lg">No posts in this community yet.</p>
        ) : (
          posts.map(post => <PostCard key={post.id} post={post} />)
        )}
    </div>
  );
};

export default CommunityPage;
