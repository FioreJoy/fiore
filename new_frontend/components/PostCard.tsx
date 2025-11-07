
import React from 'react';
import { Post } from '../types';
import { Link } from 'react-router-dom';
import { ArrowUpIcon, ArrowDownIcon, ChatBubbleIcon, HeartIcon } from './icons';
import { api } from '../services/api';

interface PostCardProps {
  post: Post;
  onVote?: (postId: number, voteType: boolean) => void;
  onFavorite?: (postId: number) => void;
}

const PostCard: React.FC<PostCardProps> = ({ post, onVote, onFavorite }) => {
  
  const handleVote = (voteType: boolean) => {
    if (onVote) onVote(post.id, voteType);
  };
  
  const handleFavorite = () => {
    if(onFavorite) onFavorite(post.id);
  }

  return (
    <div className="bg-surface rounded-lg shadow-md overflow-hidden transition-all duration-300 hover:shadow-lg hover:shadow-primary/20 mb-6">
      <div className="p-6">
        <div className="flex items-start space-x-4">
          {/* Vote Section */}
          <div className="flex flex-col items-center space-y-1 text-text-secondary">
            <button onClick={() => handleVote(true)} className={`p-2 rounded-full hover:bg-gray-700 ${post.viewer_vote_type === 'UP' ? 'text-green-400' : ''}`}>
              <ArrowUpIcon className="h-5 w-5" />
            </button>
            <span className="font-bold text-sm text-text-primary">{post.upvotes - post.downvotes}</span>
            <button onClick={() => handleVote(false)} className={`p-2 rounded-full hover:bg-gray-700 ${post.viewer_vote_type === 'DOWN' ? 'text-red-400' : ''}`}>
              <ArrowDownIcon className="h-5 w-5" />
            </button>
          </div>
          
          {/* Main Content */}
          <div className="flex-1">
            <div className="text-xs text-text-secondary mb-2 flex items-center">
              {post.community_name && (
                <>
                  <Link to={`/community/${post.community_id}`} className="font-bold hover:underline">{post.community_name}</Link>
                  <span className="mx-2">•</span>
                </>
              )}
              <span>Posted by </span>
              <Link to={`/profile/${post.user_id}`} className="font-semibold text-text-primary ml-1 hover:underline">{post.author_name}</Link>
              <span className="ml-2">{new Date(post.created_at).toLocaleDateString()}</span>
            </div>
            
            <Link to={`/post/${post.id}`} className="block">
              <h2 className="text-xl font-bold text-text-primary mb-2 hover:text-primary transition-colors">{post.title}</h2>
              <p className="text-text-secondary text-sm max-h-48 overflow-hidden line-clamp-4">{post.content}</p>
            </Link>

            {post.media && post.media.length > 0 && (
                <div className="mt-4 rounded-lg overflow-hidden">
                    <img src={post.media[0].url} alt="Post media" className="w-full h-auto object-cover max-h-96" />
                </div>
            )}

            {/* Actions */}
            <div className="flex items-center space-x-6 text-text-secondary mt-4 pt-4 border-t border-gray-700">
              <Link to={`/post/${post.id}`} className="flex items-center space-x-2 hover:text-primary">
                <ChatBubbleIcon className="h-5 w-5" />
                <span className="text-sm font-medium">{post.reply_count} Comments</span>
              </Link>
              <button onClick={handleFavorite} className={`flex items-center space-x-2 hover:text-accent ${post.viewer_has_favorited ? 'text-accent' : ''}`}>
                <HeartIcon className={`h-5 w-5 ${post.viewer_has_favorited ? 'fill-current' : ''}`}/>
                <span className="text-sm font-medium">Favorite</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PostCard;
