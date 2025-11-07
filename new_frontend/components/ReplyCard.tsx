
import React from 'react';
import { Reply } from '../types';
import { Link } from 'react-router-dom';
import { ArrowUpIcon, ArrowDownIcon, HeartIcon } from './icons';

interface ReplyCardProps {
  reply: Reply;
  onVote?: (replyId: number, voteType: boolean) => void;
  onFavorite?: (replyId: number) => void;
}

const ReplyCard: React.FC<ReplyCardProps> = ({ reply, onVote, onFavorite }) => {
  const handleVote = (voteType: boolean) => {
    if (onVote) onVote(reply.id, voteType);
  };
  
  const handleFavorite = () => {
    if(onFavorite) onFavorite(reply.id);
  }

  return (
    <div className="flex space-x-4 py-4 border-b border-gray-700">
      <div className="flex-shrink-0">
        <img
          className="h-8 w-8 rounded-full object-cover"
          src={reply.author_avatar_url || `https://picsum.photos/seed/${reply.user_id}/100/100`}
          alt={reply.author_name}
        />
      </div>
      <div className="flex-1">
        <div className="flex items-center text-sm mb-1">
          <Link to={`/profile/${reply.user_id}`} className="font-bold text-text-primary hover:underline">{reply.author_name}</Link>
          <span className="text-text-secondary mx-2">•</span>
          <span className="text-text-secondary">{new Date(reply.created_at).toLocaleString()}</span>
        </div>
        <p className="text-text-primary">{reply.content}</p>

        {reply.media && reply.media.length > 0 && (
            <div className="mt-3 rounded-lg overflow-hidden max-w-xs">
                <img src={reply.media[0].url} alt="Reply media" className="w-full h-auto object-cover" />
            </div>
        )}

        <div className="flex items-center space-x-4 text-text-secondary mt-2 text-xs">
          <div className="flex items-center">
            <button onClick={() => handleVote(true)} className={`p-1 rounded-full hover:bg-gray-700 ${reply.viewer_vote_type === 'UP' ? 'text-green-400' : ''}`}>
              <ArrowUpIcon className="h-4 w-4" />
            </button>
            <span className="font-semibold text-text-primary mx-1">{reply.upvotes - reply.downvotes}</span>
            <button onClick={() => handleVote(false)} className={`p-1 rounded-full hover:bg-gray-700 ${reply.viewer_vote_type === 'DOWN' ? 'text-red-400' : ''}`}>
              <ArrowDownIcon className="h-4 w-4" />
            </button>
          </div>
          <button onClick={handleFavorite} className={`flex items-center space-x-1 hover:text-accent ${reply.viewer_has_favorited ? 'text-accent' : ''}`}>
            <HeartIcon className={`h-4 w-4 ${reply.viewer_has_favorited ? 'fill-current' : ''}`} />
            <span>Favorite</span>
          </button>
        </div>
      </div>
    </div>
  );
};

export default ReplyCard;
