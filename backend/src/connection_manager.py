# backend/src/connection_manager.py
from typing import Dict, Set, Tuple, Optional
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        # Structure: { "room_key": {websocket: user_id} }
        self.active_connections: Dict[str, Dict[WebSocket, Optional[int]]] = {}
        # Alternatively { "room_key": Set[Tuple[WebSocket, Optional[int]]]}

    async def connect(self, websocket: WebSocket, room_key: str, user_id: Optional[int]): # Add user_id
        await websocket.accept()
        if room_key not in self.active_connections:
            self.active_connections[room_key] = {}
        self.active_connections[room_key][websocket] = user_id # Store user_id
        count = len(self.active_connections[room_key])
        print(f"WebSocket connected for User {user_id} to room: {room_key}. Total in room: {count}")

    def disconnect(self, websocket: WebSocket, room_key: str):
        if room_key in self.active_connections:
            if websocket in self.active_connections[room_key]:
                user_id = self.active_connections[room_key].get(websocket, 'Unknown')
                del self.active_connections[room_key][websocket]
                count = len(self.active_connections[room_key])
                print(f"WebSocket disconnected for User {user_id} from room: {room_key}. Remaining: {count}")
                if not self.active_connections[room_key]:
                    del self.active_connections[room_key] # Clean up empty room
            else:
                print(f"WebSocket disconnect: Socket not found in room {room_key}.")
        else:
            print(f"WebSocket disconnect: Room {room_key} not found.")


    def get_user_id(self, websocket: WebSocket, room_key: str) -> Optional[int]:
        """ Helper to get user_id associated with a websocket in a room """
        if room_key in self.active_connections:
            return self.active_connections[room_key].get(websocket)
        return None

    async def broadcast(self, message: str, room_key: str):
        if room_key in self.active_connections:
            # Use list comprehension to avoid modifying dict during iteration
            current_connections = list(self.active_connections[room_key].keys())
            print(f"Broadcasting to {len(current_connections)} connections in room {room_key}: {message[:50]}...") # Log truncated message

            disconnected_websockets = []
            for connection in current_connections:
                try:
                    await connection.send_text(message)
                except Exception as e:
                    print(f"Error sending message to a websocket in room {room_key}: {e} - marking for disconnection")
                    disconnected_websockets.append(connection)

            # Remove disconnected sockets after iterating
            for ws in disconnected_websockets:
                # Pass room_key to disconnect method
                self.disconnect(ws, room_key)

# Instantiate a single manager for the application
manager = ConnectionManager()