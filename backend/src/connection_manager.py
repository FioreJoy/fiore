# backend/src/connection_manager.py
from typing import Dict, Set, Tuple, Optional
from fastapi import WebSocket
import traceback # <--- Import traceback

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, Dict[WebSocket, Optional[int]]] = {}

    async def connect(self, websocket: WebSocket, room_key: str, user_id: Optional[int]):
        # --- ADD LOGGING INSIDE CONNECT ---
        print(f"--- Manager DEBUG --- Inside connect for User {user_id} / Room {room_key}")
        try:
            # await websocket.accept() # Accept is now done BEFORE calling connect
            if room_key not in self.active_connections:
                print(f"--- Manager DEBUG --- Creating new room entry for {room_key}")
                self.active_connections[room_key] = {}
            self.active_connections[room_key][websocket] = user_id
            count = len(self.active_connections[room_key])
            print(f"--- Manager SUCCESS --- WebSocket stored for User {user_id} in room {room_key}. Total: {count}")
        except Exception as e:
            print(f"--- !!! Manager ERROR during connect !!! ---")
            print(f"Error Type: {type(e).__name__}")
            print(f"Error Details: {e}")
            print("Traceback:")
            print(traceback.format_exc())
            print(f"------------------------------------------")
            # Re-raise the exception so the main endpoint handler catches it
            raise

    def disconnect(self, websocket: WebSocket, room_key: str):
        print(f"--- Manager DEBUG --- disconnect called for room {room_key}")
        if room_key in self.active_connections:
            if websocket in self.active_connections[room_key]:
                user_id = self.active_connections[room_key].get(websocket, 'Unknown')
                del self.active_connections[room_key][websocket]
                count = len(self.active_connections[room_key])
                print(f"--- Manager DEBUG --- WebSocket removed for User {user_id} from {room_key}. Remaining: {count}")
                if not self.active_connections[room_key]:
                    del self.active_connections[room_key]
                    print(f"--- Manager DEBUG --- Room {room_key} cleaned up.")
            # else: print(f"--- Manager DEBUG --- Socket not found in room {room_key} during disconnect.") # Can be noisy
        # else: print(f"--- Manager DEBUG --- Room {room_key} not found during disconnect.") # Can be noisy


    async def broadcast(self, message: str, room_key: str):
        # ...(Keep existing broadcast logic)...
        if room_key in self.active_connections:
            current_connections = list(self.active_connections[room_key].keys())
            print(f"--- Manager DEBUG --- Broadcasting to {len(current_connections)} in {room_key}...")
            disconnected_websockets = []
            for connection in current_connections:
                try: await connection.send_text(message)
                except Exception as e: print(f"WS Broadcast Error sending to one client: {e}"); disconnected_websockets.append(connection)
            for ws in disconnected_websockets: self.disconnect(ws, room_key)


manager = ConnectionManager()
