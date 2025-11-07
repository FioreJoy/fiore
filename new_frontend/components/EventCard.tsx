import React from 'react';
import { Event } from '../types';
import { Link } from 'react-router-dom';
import { UsersIcon, CalendarIcon } from './icons';

interface EventCardProps {
  event: Event;
}

const EventCard: React.FC<EventCardProps> = ({ event }) => {
  return (
    <div className="bg-surface rounded-lg shadow-md overflow-hidden transition-all duration-300 hover:shadow-lg hover:shadow-primary/20 mb-6">
      <div className="p-6">
        <div className="flex flex-col md:flex-row md:items-start md:space-x-6">
          <div className="flex-shrink-0 w-full md:w-48 h-32 mb-4 md:mb-0 rounded-lg overflow-hidden">
            <img 
              src={event.image_url || `https://picsum.photos/seed/${event.id}/400/300`} 
              alt={event.title} 
              className="w-full h-full object-cover" 
            />
          </div>
          
          <div className="flex-1">
            <p className="text-sm text-primary font-bold mb-1">
              {new Date(event.event_timestamp).toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
            </p>
            <h2 className="text-xl font-bold text-text-primary mb-2 hover:text-primary transition-colors">
              {event.title}
            </h2>
            <p className="text-text-secondary text-sm mb-4">{event.location}</p>

            <div className="flex items-center space-x-4 text-text-secondary text-sm border-t border-gray-700 pt-3">
              <span className="flex items-center gap-1">
                <UsersIcon className="h-4 w-4" /> 
                {event.participant_count} / {event.max_participants}
              </span>
              <Link to={`/community/${event.community_id}`} className="text-secondary font-semibold hover:underline">
                View Community
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default EventCard;
