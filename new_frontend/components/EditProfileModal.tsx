import React, { useState, useEffect, Fragment } from 'react';
import { Dialog, Transition } from '@headlessui/react';
import { User } from '../types';
import { api } from '../services/api';
import { INTERESTS } from '../constants';

interface EditProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
  user: User;
  onUpdate: (updatedUser: User) => void;
}

const EditProfileModal: React.FC<EditProfileModalProps> = ({ isOpen, onClose, user, onUpdate }) => {
  const [formData, setFormData] = useState({
    name: user.name,
    college: user.college || '',
    interests: user.interests || [],
  });
  const [image, setImage] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(user.image_url || null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    // Reset form when user prop changes (e.g., modal opens for a new user, though not applicable here)
    setFormData({
      name: user.name,
      college: user.college || '',
      interests: user.interests || [],
    });
    setImagePreview(user.image_url || null);
  }, [user, isOpen]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };
  
  const handleInterestToggle = (interest: string) => {
    setFormData(prev => ({
      ...prev,
      interests: prev.interests.includes(interest)
        ? prev.interests.filter(i => i !== interest)
        : [...prev.interests, interest]
    }));
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setImage(file);
      setImagePreview(URL.createObjectURL(file));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    const submissionData = new FormData();
    submissionData.append('name', formData.name);
    submissionData.append('college', formData.college);
    formData.interests.forEach(interest => submissionData.append('interests', interest));
    
    if (image) {
      submissionData.append('image', image);
    }
    
    try {
      const updatedUser = await api.updateProfile(submissionData);
      onUpdate(updatedUser);
      onClose();
    } catch (err: any) {
      setError(err.message || 'Failed to update profile.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Transition appear show={isOpen} as={Fragment}>
      <Dialog as="div" className="relative z-10" onClose={onClose}>
        <Transition.Child
          as={Fragment}
          enter="ease-out duration-300"
          enterFrom="opacity-0"
          enterTo="opacity-100"
          leave="ease-in duration-200"
          leaveFrom="opacity-100"
          leaveTo="opacity-0"
        >
          <div className="fixed inset-0 bg-black bg-opacity-50" />
        </Transition.Child>

        <div className="fixed inset-0 overflow-y-auto">
          <div className="flex min-h-full items-center justify-center p-4 text-center">
            <Transition.Child
              as={Fragment}
              enter="ease-out duration-300"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="ease-in duration-200"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <Dialog.Panel className="w-full max-w-md transform overflow-hidden rounded-2xl bg-surface p-6 text-left align-middle shadow-xl transition-all">
                <Dialog.Title as="h3" className="text-lg font-medium leading-6 text-text-primary">
                  Edit Profile
                </Dialog.Title>
                <form onSubmit={handleSubmit} className="mt-4 space-y-4">
                  {error && <p className="bg-red-500/20 text-red-400 text-sm p-3 rounded-md">{error}</p>}
                  
                  <div className="flex flex-col items-center">
                    <img src={imagePreview || `https://picsum.photos/seed/${user.id}/200/200`} alt="Profile preview" className="w-32 h-32 rounded-full object-cover border-4 border-background mb-4" />
                    <label htmlFor="profile-image-upload" className="cursor-pointer bg-primary text-white px-4 py-2 text-sm rounded-full hover:bg-indigo-700">
                        Change Picture
                    </label>
                    <input id="profile-image-upload" type="file" accept="image/*" onChange={handleFileChange} className="hidden" />
                  </div>

                  <input name="name" type="text" value={formData.name} placeholder="Full Name" required onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md" />
                  <input name="college" type="text" value={formData.college} placeholder="College" required onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md" />
                  
                  <div>
                    <label className="block text-sm font-medium text-text-secondary">Interests</label>
                    <div className="mt-2 flex flex-wrap gap-2">
                        {INTERESTS.map(interest => (
                            <button
                                key={interest}
                                type="button"
                                onClick={() => handleInterestToggle(interest)}
                                className={`px-3 py-1 text-sm rounded-full transition-colors ${
                                formData.interests.includes(interest)
                                    ? 'bg-primary text-white'
                                    : 'bg-background hover:bg-gray-700 border border-gray-600'
                                }`}
                            >
                                {interest}
                            </button>
                        ))}
                    </div>
                  </div>

                  <div className="mt-6 flex justify-end gap-4">
                    <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-medium text-text-secondary rounded-md hover:bg-gray-700">
                      Cancel
                    </button>
                    <button type="submit" disabled={isLoading} className="px-4 py-2 text-sm font-medium text-white bg-primary rounded-md hover:bg-indigo-700 disabled:bg-gray-500">
                      {isLoading ? 'Saving...' : 'Save Changes'}
                    </button>
                  </div>
                </form>
              </Dialog.Panel>
            </Transition.Child>
          </div>
        </div>
      </Dialog>
    </Transition>
  );
};

export default EditProfileModal;
