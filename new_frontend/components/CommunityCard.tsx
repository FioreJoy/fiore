
import React from 'react';
import { Link } from 'react-router-dom';
import { Community } from '../types';
import { UsersIcon } from './icons';

interface CommunityCardProps {
  community: Community;
}

const CommunityCard: React.FC<CommunityCardProps> = ({ community }) => {
  return (
    <div className="bg-surface rounded-lg shadow-md overflow-hidden transition-all duration-300 hover:shadow-lg hover:shadow-primary/20">
      <div className="p-5">
        <div className="flex items-center space-x-4 mb-4">
          <img
            src={community.logo_url || `https://picsum.photos/seed/${community.id}/100/100`}
            alt={`${community.name} logo`}
            className="w-16 h-16 rounded-full object-cover border-2 border-background"
          />
          <div className="flex-1">
            <Link to={`/community/${community.id}`}>
                <h3 className="text-lg font-bold text-text-primary hover:text-primary transition-colors">{community.name}</h3>
            </Link>
            <div className="flex items-center text-sm text-text-secondary mt-1">
              <UsersIcon className="w-4 h-4 mr-1.5" />
              <span>{community.member_count} members</span>
            </div>
          </div>
        </div>
        
        <p className="text-sm text-text-secondary mb-4 line-clamp-2 h-10">
          {community.description || 'No description available.'}
        </p>

        <div className="flex items-center justify-between">
            <span className="bg-secondary/20 text-secondary text-xs font-semibold px-2 py-1 rounded-full">{community.interest}</span>
            <Link 
                to={`/community/${community.id}`}
                className="text-sm font-semibold text-primary hover:underline"
            >
                View
            </Link>
        </div>
      </div>
    </div>
  );
};

export default CommunityCard;
