
import React, { useState, useEffect, useCallback } from 'react';
import { Community } from '../types';
import { api } from '../services/api';
import Spinner from '../components/Spinner';
import CommunityCard from '../components/CommunityCard';

const CommunitiesPage: React.FC = () => {
  const [communities, setCommunities] = useState<Community[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCommunities = useCallback(async () => {
    setIsLoading(true);
    try {
      const fetchedCommunities = await api.getCommunities();
      setCommunities(fetchedCommunities);
      setError(null);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch communities.');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchCommunities();
  }, [fetchCommunities]);

  if (isLoading) {
    return <Spinner />;
  }

  if (error) {
    return <div className="text-center text-red-400">{error}</div>;
  }

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-text-primary">Explore Communities</h1>
        {/* Future: Add a "Create Community" button here */}
      </div>
      
      {communities.length === 0 ? (
        <p className="text-center text-text-secondary">No communities found.</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {communities.map(community => (
            <CommunityCard key={community.id} community={community} />
          ))}
        </div>
      )}
    </div>
  );
};

export default CommunitiesPage;
