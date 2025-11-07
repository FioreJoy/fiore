
import React, { useState, useEffect, useCallback } from 'react';
import { Post } from '../types';
import { api } from '../services/api';
import PostCard from '../components/PostCard';
import Spinner from '../components/Spinner';

const HomePage: React.FC = () => {
  const [posts, setPosts] = useState<Post[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchPosts = useCallback(async () => {
    setIsLoading(true);
    try {
      const fetchedPosts = await api.getDiscoverFeed();
      setPosts(fetchedPosts);
      setError(null);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch posts.');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchPosts();
  }, [fetchPosts]);

  const handleVote = async (postId: number, voteType: boolean) => {
    // Optimistic UI update
    const originalPosts = [...posts];
    setPosts(posts.map(p => {
        if (p.id === postId) {
            const currentVote = p.viewer_vote_type;
            let newUpvotes = p.upvotes;
            let newDownvotes = p.downvotes;
            
            if (currentVote === 'UP') newUpvotes--;
            if (currentVote === 'DOWN') newDownvotes--;

            if (currentVote === 'UP' && voteType === true) { // Un-upvote
                return { ...p, upvotes: newUpvotes, viewer_vote_type: null };
            }
            if (currentVote === 'DOWN' && voteType === false) { // Un-downvote
                return { ...p, downvotes: newDownvotes, viewer_vote_type: null };
            }

            // New vote or changed vote
            if (voteType === true) newUpvotes++;
            if (voteType === false) newDownvotes++;
            
            return { ...p, upvotes: newUpvotes, downvotes: newDownvotes, viewer_vote_type: voteType ? 'UP' : 'DOWN' };
        }
        return p;
    }));

    try {
        await api.vote(postId, null, voteType);
    } catch (error) {
        console.error("Failed to vote", error);
        setPosts(originalPosts); // Revert on error
    }
  };

  const handleFavorite = async (postId: number) => {
    const originalPosts = [...posts];
    const post = posts.find(p => p.id === postId);
    if (!post) return;

    const isFavorited = post.viewer_has_favorited;

    setPosts(posts.map(p => p.id === postId ? { ...p, viewer_has_favorited: !isFavorited } : p));
    
    try {
        if (isFavorited) {
            await api.unfavorite(postId, null);
        } else {
            await api.favorite(postId, null);
        }
    } catch (error) {
        console.error("Failed to update favorite", error);
        setPosts(originalPosts);
    }
  };


  if (isLoading) {
    return <Spinner />;
  }

  if (error) {
    return <div className="text-center text-red-400">{error}</div>;
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6 text-text-primary">Discover Feed</h1>
      {posts.length === 0 ? (
        <p className="text-center text-text-secondary">No posts found.</p>
      ) : (
        posts.map(post => (
          <PostCard key={post.id} post={post} onVote={handleVote} onFavorite={handleFavorite} />
        ))
      )}
    </div>
  );
};

export default HomePage;
