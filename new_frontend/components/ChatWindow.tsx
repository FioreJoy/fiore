import React, { useState, useEffect, useRef, useCallback } from 'react';
import { WEBSOCKET_URL, FIORE_API_KEY } from '../constants';
import { useAuth } from '../hooks/useAuth';
import { ChatMessage } from '../types';
import { PaperAirplaneIcon } from './icons';
import Spinner from './Spinner';
import { api } from '../services/api';

interface ChatWindowProps {
  roomType: 'community' | 'event';
  roomId: number;
}

const ChatWindow: React.FC<ChatWindowProps> = ({ roomType, roomId }) => {
  const { token, user } = useAuth();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const [isLoadingHistory, setIsLoadingHistory] = useState(true);
  const ws = useRef<WebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement | null>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);
  
  const connect = useCallback(() => {
    if (!token || !roomId) return;
    if (ws.current && ws.current.readyState === WebSocket.OPEN) return;

    const wsUrl = `${WEBSOCKET_URL}/ws/${roomType}/${roomId}?token=${token}&api_key=${FIORE_API_KEY}`;
    ws.current = new WebSocket(wsUrl);

    ws.current.onopen = () => {
      console.log(`WebSocket connected to ${roomType} ${roomId}`);
      setIsConnected(true);
    };

    ws.current.onmessage = (event) => {
      const messageData = JSON.parse(event.data) as ChatMessage;
      setMessages((prevMessages) => [...prevMessages, messageData]);
    };

    ws.current.onclose = () => {
      console.log(`WebSocket disconnected from ${roomType} ${roomId}`);
      setIsConnected(false);
      // Optional: implement reconnect logic
    };

    ws.current.onerror = (error) => {
      console.error('WebSocket error:', error);
      setIsConnected(false);
    };
  }, [token, roomType, roomId]);

  useEffect(() => {
    // Fetch history first
    const fetchHistory = async () => {
        setIsLoadingHistory(true);
        try {
            const history = await api.getChatHistory(roomType, roomId);
            setMessages(history.reverse()); // reverse to show oldest first
        } catch (error) {
            console.error('Failed to fetch chat history:', error);
        } finally {
            setIsLoadingHistory(false);
        }
    };

    fetchHistory();
    connect();

    return () => {
      ws.current?.close();
    };
  }, [roomType, roomId, connect]);

  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (newMessage.trim() && ws.current && ws.current.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify({ content: newMessage }));
      setNewMessage('');
    }
  };

  return (
    <div className="bg-surface rounded-lg h-[70vh] flex flex-col">
      <div className="p-4 border-b border-gray-700">
        <h3 className="font-bold text-lg text-text-primary capitalize">{roomType} Chat</h3>
        <span className={`text-xs ${isConnected ? 'text-green-400' : 'text-red-400'}`}>
          {isConnected ? 'Connected' : 'Disconnected'}
        </span>
      </div>
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {isLoadingHistory ? <Spinner /> : (
            messages.map((msg) => (
                <div key={msg.message_id} className={`flex items-start gap-3 ${msg.user_id === user?.id ? 'flex-row-reverse' : ''}`}>
                    <img 
                        src={`https://picsum.photos/seed/${msg.user_id}/40/40`} 
                        alt={msg.username} 
                        className="w-8 h-8 rounded-full"
                    />
                    <div className={`p-3 rounded-lg max-w-xs md:max-w-md ${msg.user_id === user?.id ? 'bg-primary text-white' : 'bg-background'}`}>
                        <p className={`font-bold text-sm ${msg.user_id === user?.id ? 'text-white' : 'text-secondary'}`}>{msg.username}</p>
                        <p className="text-sm">{msg.content}</p>
                         <p className="text-xs opacity-70 mt-1 text-right">{new Date(msg.timestamp).toLocaleTimeString()}</p>
                    </div>
                </div>
            ))
        )}
        <div ref={messagesEndRef} />
      </div>
      <div className="p-4 border-t border-gray-700">
        <form onSubmit={handleSendMessage} className="flex items-center space-x-2">
          <input
            type="text"
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            placeholder="Type a message..."
            className="flex-1 bg-background border border-gray-600 rounded-full px-4 py-2 focus:outline-none focus:ring-2 focus:ring-primary"
            disabled={!isConnected}
          />
          <button type="submit" className="bg-primary p-3 rounded-full text-white disabled:bg-gray-500" disabled={!isConnected || !newMessage.trim()}>
            <PaperAirplaneIcon className="h-5 w-5" />
          </button>
        </form>
      </div>
    </div>
  );
};

export default ChatWindow;