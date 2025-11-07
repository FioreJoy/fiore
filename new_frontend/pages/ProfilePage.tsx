import React, { useState, useEffect, useCallback, Fragment } from 'react';
import { useParams } from 'react-router-dom';
import { User, Post } from '../types';
import { api } from '../services/api';
import Spinner from '../components/Spinner';
import PostCard from '../components/PostCard';
import { useAuth } from '../hooks/useAuth';
import { Menu, Transition } from '@headlessui/react';
import { EllipsisHorizontalIcon, BlockIcon, PencilIcon } from '../components/icons';
import EditProfileModal from '../components/EditProfileModal';

const ProfilePage: React.FC = () => {
  const { userId } = useParams<{ userId: string }>();
  const [profile, setProfile] = useState<User | null>(null);
  const [posts, setPosts] = useState<Post[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isBlocked, setIsBlocked] = useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const { user: currentUser, setUser: setCurrentUser } = useAuth();

  const userIdNum = Number(userId);

  const fetchData = useCallback(async () => {
    if (!userIdNum) return;
    setIsLoading(true);
    try {
      const [profileData, postsData, blockedUsersData] = await Promise.all([
        api.getUserProfile(userIdNum),
        api.request<Post[]>(`/posts?user_id=${userIdNum}`),
        currentUser && currentUser.id !== userIdNum ? api.getBlockedUsers() : Promise.resolve([]),
      ]);
      setProfile(profileData);
      setPosts(postsData);
      if (blockedUsersData) {
        setIsBlocked(blockedUsersData.some(u => u.blocked_id === userIdNum));
      }
      setError(null);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch profile details.');
    } finally {
      setIsLoading(false);
    }
  }, [userIdNum, currentUser]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleFollowToggle = async () => {
    if (!profile) return;
    const originalProfile = { ...profile };
    const isFollowing = profile.is_following;
    setProfile(p => p ? { ...p, is_following: !isFollowing, followers_count: isFollowing ? p.followers_count - 1 : p.followers_count + 1 } : null);

    try {
        if (isFollowing) {
            await api.unfollowUser(profile.id);
        } else {
            await api.followUser(profile.id);
        }
    } catch (error) {
        console.error("Failed to follow/unfollow", error);
        setProfile(originalProfile);
    }
  };

  const handleBlockToggle = async () => {
    if (!profile) return;
    const originalIsBlocked = isBlocked;
    setIsBlocked(!originalIsBlocked);

    try {
      if(originalIsBlocked) {
        await api.unblockUser(profile.id);
      } else {
        await api.blockUser(profile.id);
        // If we block someone, we should unfollow them.
        if (profile.is_following) {
          handleFollowToggle();
        }
      }
    } catch (error) {
      console.error("Failed to block/unblock user", error);
      setIsBlocked(originalIsBlocked);
    }
  };

  const handleProfileUpdate = (updatedUser: User) => {
    setProfile(updatedUser); // Update local profile state
    setCurrentUser(updatedUser); // Update global auth context state
  }


  if (isLoading) return <Spinner />;
  if (error) return <div className="text-center text-red-400 p-4">{error}</div>;
  if (!profile) return <div className="text-center text-text-secondary p-4">User not found.</div>;

  const isCurrentUserProfile = currentUser?.id === profile.id;

  return (
    <>
      <EditProfileModal 
        isOpen={isEditModalOpen}
        onClose={() => setIsEditModalOpen(false)}
        user={profile}
        onUpdate={handleProfileUpdate}
      />
      <div>
        <div className="bg-surface rounded-lg p-6 md:p-8 mb-6 shadow-lg">
          <div className="flex flex-col md:flex-row items-center gap-6">
            <img
              src={profile.image_url || `https://picsum.photos/seed/${profile.id}/200/200`}
              alt={profile.name}
              className="w-32 h-32 rounded-full border-4 border-primary object-cover"
            />
            <div className="flex-1 text-center md:text-left">
              <h1 className="text-3xl font-bold text-text-primary">{profile.name}</h1>
              <p className="text-text-secondary">@{profile.username}</p>
              <p className="text-text-secondary text-sm mt-2">{profile.college}</p>
              <div className="flex justify-center md:justify-start items-center gap-2 mt-3">
                  {profile.interests.map(interest => (
                      <span key={interest} className="bg-secondary/20 text-secondary text-xs font-semibold px-2 py-1 rounded-full">{interest}</span>
                  ))}
              </div>
            </div>
            <div className="flex flex-col items-center md:items-end gap-4">
               <div className="flex items-center gap-6">
                <div className="text-center">
                  <div className="font-bold text-xl">{posts.length}</div>
                  <div className="text-sm text-text-secondary">Posts</div>
                </div>
                <div className="text-center">
                  <div className="font-bold text-xl">{profile.followers_count}</div>
                  <div className="text-sm text-text-secondary">Followers</div>
                </div>
                <div className="text-center">
                  <div className="font-bold text-xl">{profile.following_count}</div>
                  <div className="text-sm text-text-secondary">Following</div>
                </div>
              </div>
              {isCurrentUserProfile ? (
                  <button onClick={() => setIsEditModalOpen(true)} className="font-bold py-2 px-6 rounded-full w-40 transition-colors bg-gray-600 hover:bg-gray-500 flex items-center justify-center gap-2">
                      <PencilIcon className="w-4 h-4" />
                      Edit Profile
                  </button>
              ) : (
                <div className="flex items-center gap-2">
                  <button onClick={handleFollowToggle} disabled={isBlocked} className={`font-bold py-2 px-6 rounded-full w-32 transition-colors ${profile.is_following ? 'bg-gray-600 hover:bg-red-600' : 'bg-primary hover:bg-indigo-700'} disabled:bg-gray-500 disabled:cursor-not-allowed`}>
                    {profile.is_following ? 'Unfollow' : 'Follow'}
                  </button>
                  <Menu as="div" className="relative inline-block text-left">
                      <Menu.Button className="p-2 rounded-full hover:bg-gray-700/50 focus:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-opacity-75">
                        <EllipsisHorizontalIcon className="h-6 w-6 text-text-secondary" />
                      </Menu.Button>
                      <Transition
                          as={Fragment}
                          enter="transition ease-out duration-100"
                          enterFrom="transform opacity-0 scale-95"
                          enterTo="transform opacity-100 scale-100"
                          leave="transition ease-in duration-75"
                          leaveFrom="transform opacity-100 scale-100"
                          leaveTo="transform opacity-0 scale-95"
                      >
                          <Menu.Items className="absolute right-0 mt-2 w-48 origin-top-right rounded-md bg-background shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none">
                              <div className="px-1 py-1 ">
                                  <Menu.Item>
                                      {({ active }) => (
                                          <button onClick={handleBlockToggle} className={`${active ? 'bg-red-600 text-white' : 'text-red-400'} group flex w-full items-center rounded-md px-2 py-2 text-sm`}>
                                              <BlockIcon className="mr-2 h-5 w-5" />
                                              {isBlocked ? 'Unblock User' : 'Block User'}
                                          </button>
                                      )}
                                  </Menu.Item>
                              </div>
                          </Menu.Items>
                      </Transition>
                  </Menu>
                </div>
              )}
            </div>
          </div>
        </div>
        
        <h2 className="text-xl font-bold mb-4">{isCurrentUserProfile ? 'Your Posts' : `${profile.name}'s Posts`}</h2>
        {isBlocked ? (
          <div className="text-center text-text-secondary bg-surface p-8 rounded-lg">
              <p className="font-semibold">You have blocked this user.</p>
              <p className="text-sm">You cannot see their posts or interact with them until you unblock them.</p>
          </div>
        ) : posts.length === 0 ? (
          <p className="text-center text-text-secondary bg-surface p-8 rounded-lg">This user hasn't posted anything yet.</p>
        ) : (
          posts.map(post => <PostCard key={post.id} post={post} />)
        )}
      </div>
    </>
  );
};

export default ProfilePage;
