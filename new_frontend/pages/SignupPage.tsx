import React, { useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { api } from '../services/api';
import { Link, useNavigate } from 'react-router-dom';
import { INTERESTS } from '../constants';

const SignupPage: React.FC = () => {
  const [formData, setFormData] = useState({
    name: '',
    username: '',
    email: '',
    password: '',
    gender: 'Others',
    college: '',
    interests: [] as string[],
  });
  const [image, setImage] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
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
      setImage(e.target.files[0]);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    if (formData.interests.length === 0) {
      setError("Please select at least one interest.");
      setIsLoading(false);
      return;
    }

    const submissionData = new FormData();
    // Append all fields except interests
    (Object.keys(formData) as Array<keyof typeof formData>).forEach(key => {
        if (key !== 'interests') {
            submissionData.append(key, formData[key]);
        }
    });

    // Append each interest separately
    formData.interests.forEach(interest => {
        submissionData.append('interests', interest);
    });

    if (image) {
      submissionData.append('image', image);
    }
    
    try {
      const { token } = await api.signup(submissionData);
      await login(token);
      navigate('/');
    } catch (err: any) {
      setError(err.message || 'Failed to sign up. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="w-full max-w-md">
        <div className="bg-surface p-8 rounded-2xl shadow-lg">
          <h1 className="text-3xl font-bold text-center text-primary mb-2">Create Account</h1>
          <p className="text-center text-text-secondary mb-8">Join Fiore today</p>
          {error && <p className="bg-red-500/20 text-red-400 text-sm p-3 rounded-md mb-4">{error}</p>}
          <form onSubmit={handleSubmit} className="space-y-4">
            
            <input name="name" type="text" placeholder="Full Name" required onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md" />
            <input name="username" type="text" placeholder="Username" required onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md" />
            <input name="email" type="email" placeholder="Email" required onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md" />
            <input name="password" type="password" placeholder="Password" required onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md" />
            <select name="gender" value={formData.gender} onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md">
                <option>Male</option>
                <option>Female</option>
                <option>Others</option>
            </select>
            <input name="college" type="text" placeholder="College" required onChange={handleChange} className="block w-full px-4 py-3 bg-background border border-gray-700 rounded-md" />
            
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
            
            <div>
              <label className="block text-sm font-medium text-text-secondary">Profile Picture (Optional)</label>
              <input type="file" accept="image/*" onChange={handleFileChange} className="mt-1 block w-full text-sm text-text-secondary file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-primary file:text-white hover:file:bg-indigo-700"/>
            </div>

            <div>
              <button type="submit" disabled={isLoading} className="w-full flex justify-center py-3 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-primary hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary disabled:bg-gray-500">
                {isLoading ? 'Creating Account...' : 'Sign up'}
              </button>
            </div>
          </form>
           <p className="mt-6 text-center text-sm text-text-secondary">
            Already have an account?{' '}
            <Link to="/login" className="font-medium text-primary hover:text-indigo-400">
              Sign in
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
};

export default SignupPage;
