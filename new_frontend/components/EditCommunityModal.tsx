import React, { useState, useEffect, Fragment } from 'react';
import { Dialog, Transition } from '@headlessui/react';
import { Community } from '../types';
import { api } from '../services/api';
import { INTERESTS } from '../constants';

interface EditCommunityModalProps {
  isOpen: boolean;
  onClose: () => void;
  community: Community;
  onUpdate: (updatedCommunity: Community) => void;
}

const EditCommunityModal: React.FC<EditCommunityModalProps> = ({ isOpen, onClose, community, onUpdate }) => {
  const [formData, setFormData] = useState({
    name: community.name,
    description: community.description || '',
    interest: community.interest || '',
  });
  const [logo, setLogo] = useState<File | null>(null);
  const [logoPreview, setLogoPreview] = useState<string | null>(community.logo_url || null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    setFormData({
      name: community.name,
      description: community.description || '',
      interest: community.interest || '',
    });
    setLogoPreview(community.logo_url || null);
  }, [community, isOpen]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setLogo(file);
      setLogoPreview(URL.createObjectURL(file));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    const submissionData = new FormData();
    submissionData.append('name', formData.name);
    submissionData.append('description', formData.description);
    submissionData.append('interest', formData.interest);
    
    if (logo) {
      submissionData.append('logo', logo);
    }
    
    try {
      // This API method doesn't exist in the api service yet, but this is how it would be called.
      // const updatedCommunity = await api.updateCommunity(community.id, submissionData);
      
      // For now, we will mock the response and call the onUpdate callback.
      const updatedCommunity: Community = {
          ...community,
          ...formData,
          logo_url: logoPreview || community.logo_url,
      };
      onUpdate(updatedCommunity);
      onClose();
    } catch (err: any) {
      setError(err.message || 'Failed to update community.');
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
                  Edit Community
                </Dialog.Title>
                <form onSubmit={handleSubmit} className="mt-4 space-y-4">
                  {error && <p className="bg-red-500/20 text-red-400 text-sm p-3 rounded-md">{error}</p>}
                  
                  <div className="flex flex-col items-center">
                    <img src={logoPreview || `https://picsum.photos/seed/${community.id}/200/200`} alt="Community logo preview" className="w-32 h-32 rounded-full object-cover border-4 border-background mb-4" />
                    <label htmlFor="community-logo-upload" className="cursor-pointer bg-primary text-white px-4 py-2 text-sm rounded-full hover:bg-indigo-700">
                        Change Logo
                    </label>
                    <input id="community-logo-upload" type="file" accept="image/*" onChange={handleFileChange} className="hidden" />
                  </div>

                  <input name="name" type="text" value={formData.name} placeholder="Community Name" required onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md" />
                  <textarea name="description" value={formData.description} placeholder="Description" required onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md" rows={3}></textarea>
                  <select name="interest" value={formData.interest} onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md">
                      <option value="">Select an Interest</option>
                      {INTERESTS.map(interest => (
                          <option key={interest} value={interest}>{interest}</option>
                      ))}
                  </select>

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

export default EditCommunityModal;
