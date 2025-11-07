
import React, { useState, useEffect, useCallback } from 'react';
import { useParams } from 'react-router-dom';
import { Post, Reply } from '../types';
import { api } from '../services/api';
import Spinner from '../components/Spinner';
import PostCard from '../components/PostCard';
import ReplyCard from '../components/ReplyCard';
import { useAuth } from '../hooks/useAuth';

const PostPage: React.FC = () => {
  const { postId } = useParams<{ postId: string }>();
  const [post, setPost] = useState<Post | null>(null);
  const [replies, setReplies] = useState<Reply[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [newReplyContent, setNewReplyContent] = useState('');
  const { user } = useAuth();

  const fetchData = useCallback(async () => {
    if (!postId) return;
    setIsLoading(true);
    try {
      const postData = await api.getPost(Number(postId));
      const repliesData = await api.getRepliesForPost(Number(postId));
      setPost(postData);
      setReplies(repliesData);
      setError(null);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch post details.');
    } finally {
      setIsLoading(false);
    }
  }, [postId]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);
  
  const handleReplySubmit = async (e: React.FormEvent) => {
      e.preventDefault();
      if (!newReplyContent.trim() || !postId) return;

      const formData = new FormData();
      formData.append('post_id', postId);
      formData.append('content', newReplyContent);

      try {
          const newReply = await api.createReply(formData);
          setReplies(prev => [...prev, newReply]);
          setNewReplyContent('');
      } catch (error) {
          console.error("Failed to post reply", error);
          // show error toast
      }
  }

  if (isLoading) return <Spinner />;
  if (error) return <div className="text-center text-red-400 p-4">{error}</div>;
  if (!post) return <div className="text-center text-text-secondary p-4">Post not found.</div>;

  return (
    <div>
      <PostCard post={post} />
      
      <div className="my-8 bg-surface p-6 rounded-lg">
        <h3 className="text-lg font-bold mb-4">Leave a Reply</h3>
        <form onSubmit={handleReplySubmit} className="flex flex-col gap-4">
            <div className="flex items-start gap-3">
                <img src={user?.image_url || `https://picsum.photos/seed/${user?.id}/100/100`} alt="Your avatar" className="w-10 h-10 rounded-full"/>
                <textarea 
                    value={newReplyContent}
                    onChange={(e) => setNewReplyContent(e.target.value)}
                    placeholder="What are your thoughts?"
                    className="w-full bg-background border border-gray-600 rounded-md p-3 focus:outline-none focus:ring-2 focus:ring-primary"
                    rows={3}
                />
            </div>
            <button type="submit" className="self-end bg-primary hover:bg-indigo-700 text-white font-bold py-2 px-4 rounded-full transition-colors" disabled={!newReplyContent.trim()}>
                Post Reply
            </button>
        </form>
      </div>

      <div className="mt-8">
        <h3 className="text-xl font-bold mb-4">{replies.length} Replies</h3>
        <div className="space-y-4">
          {replies.map(reply => (
            <ReplyCard key={reply.id} reply={reply} />
          ))}
        </div>
      </div>
    </div>
  );
};

export default PostPage;
