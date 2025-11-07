import React, { useState, useEffect, useCallback } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { Community } from '../types';
import { api } from '../services/api';
import Spinner from '../components/Spinner';
import ChatWindow from '../components/ChatWindow';

const ChatPage: React.FC = () => {
  const { communityId } = useParams<{ communityId: string }>();
  const [myCommunities, setMyCommunities] = useState<Community[]>([]);
  const [selectedCommunityId, setSelectedCommunityId] = useState<number | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  useEffect(() => {
    if (communityId) {
      setSelectedCommunityId(Number(communityId));
    }
  }, [communityId]);

  const fetchMyCommunities = useCallback(async () => {
    setIsLoading(true);
    try {
      const communities = await api.getMyCommunities();
      setMyCommunities(communities);
      if (!communityId && communities.length > 0) {
        // If no community is selected via URL, default to the first one in the list
        navigate(`/chat/${communities[0].id}`, { replace: true });
      }
    } catch (err: any) {
      setError(err.message || 'Failed to fetch your communities.');
    } finally {
      setIsLoading(false);
    }
  }, [communityId, navigate]);

  useEffect(() => {
    fetchMyCommunities();
  }, [fetchMyCommunities]);

  return (
    <div className="flex h-[calc(100vh-100px)] bg-surface rounded-lg overflow-hidden">
      {/* Left Sidebar: Community List */}
      <aside className="w-1/3 md:w-1/4 bg-background border-r border-gray-800 flex flex-col">
        <div className="p-4 border-b border-gray-700">
          <h2 className="text-xl font-bold text-text-primary">Messages</h2>
        </div>
        <div className="flex-1 overflow-y-auto">
          {isLoading ? (
            <Spinner />
          ) : error ? (
            <p className="p-4 text-sm text-red-400">{error}</p>
          ) : (
            <nav className="p-2">
              {myCommunities.length > 0 ? (
                myCommunities.map(community => (
                  <Link
                    key={community.id}
                    to={`/chat/${community.id}`}
                    className={`flex items-center gap-3 p-3 rounded-lg transition-colors w-full text-left ${
                      selectedCommunityId === community.id
                        ? 'bg-primary/20 text-text-primary'
                        : 'hover:bg-gray-700/50 text-text-secondary'
                    }`}
                  >
                    <img src={community.logo_url || `https://picsum.photos/seed/${community.id}/40/40`} alt={community.name} className="w-10 h-10 rounded-full object-cover" />
                    <div className="flex-1 overflow-hidden">
                        <p className="font-semibold truncate text-text-primary">{community.name}</p>
                        <p className="text-xs truncate">{community.interest}</p>
                    </div>
                  </Link>
                ))
              ) : (
                <p className="p-4 text-sm text-text-secondary">Join a community to start chatting.</p>
              )}
            </nav>
          )}
        </div>
      </aside>

      {/* Main Content: Chat Window */}
      <main className="flex-1 flex flex-col">
        {selectedCommunityId ? (
          <ChatWindow key={selectedCommunityId} roomType="community" roomId={selectedCommunityId} />
        ) : (
          <div className="flex-1 flex items-center justify-center text-center text-text-secondary">
            {isLoading ? <Spinner /> : 
              <div>
                <h3 className="text-lg font-semibold">Select a chat</h3>
                <p>Choose a community from the list to view messages.</p>
              </div>
            }
          </div>
        )}
      </main>
    </div>
  );
};

export default ChatPage;
