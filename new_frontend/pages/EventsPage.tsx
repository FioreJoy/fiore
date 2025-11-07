import React, { useState, useEffect, useCallback } from 'react';
import { Event } from '../types';
import { api } from '../services/api';
import Spinner from '../components/Spinner';
import EventCard from '../components/EventCard';

const EventsPage: React.FC = () => {
  const [events, setEvents] = useState<Event[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchEvents = useCallback(async () => {
    setIsLoading(true);
    try {
      const fetchedEvents = await api.getMyEvents();
      // Sort events by date, upcoming first
      fetchedEvents.sort((a, b) => new Date(a.event_timestamp).getTime() - new Date(b.event_timestamp).getTime());
      setEvents(fetchedEvents);
      setError(null);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch your events.');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchEvents();
  }, [fetchEvents]);

  if (isLoading) {
    return <Spinner />;
  }

  if (error) {
    return <div className="text-center text-red-400">{error}</div>;
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6 text-text-primary">Your Events</h1>
      {events.length === 0 ? (
        <div className="text-center text-text-secondary bg-surface p-10 rounded-lg">
            <h3 className="text-lg font-semibold text-text-primary">No Upcoming Events</h3>
            <p className="mt-2">You haven't joined any events yet. Explore communities to find events to join!</p>
        </div>
      ) : (
        <div className="space-y-4">
          {events.map(event => (
            <EventCard key={event.id} event={event} />
          ))}
        </div>
      )}
    </div>
  );
};

export default EventsPage;
