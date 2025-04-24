# backend/src/connection_manager.py
from typing import Dict, Set, Tuple, Optional
from fastapi import WebSocket
import traceback

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, Dict[WebSocket, Optional[int]]] = {}
        print("--- Manager Initialized ---") # Log initialization

    async def connect(self, websocket: WebSocket, room_key: str, user_id: Optional[int]):
        print(f"--- Manager CONNECT Start --- User {user_id} / Room {room_key}")
        try:
            # await websocket.accept() # Accept is done before calling connect

            # --- Add Detailed Check ---
            if room_key not in self.active_connections:
                print(f"--- Manager DEBUG --- Room '{room_key}' NOT found. Creating new entry.")
                self.active_connections[room_key] = {}
            else:
                print(f"--- Manager DEBUG --- Room '{room_key}' ALREADY exists. Adding user {user_id}.")
                # Log current users in room BEFORE adding new one
                current_users = list(self.active_connections[room_key].values())
                print(f"--- Manager DEBUG --- Users currently in room '{room_key}': {current_users}")
            # --- End Detailed Check ---

            # Add the new connection
            self.active_connections[room_key][websocket] = user_id

            # Log current users AFTER adding new one
            current_users_after = list(self.active_connections[room_key].values())
            count = len(self.active_connections[room_key])
            print(f"--- Manager SUCCESS --- Stored User {user_id} in '{room_key}'. Current Users: {current_users_after}. Total: {count}")

        except Exception as e:
            print(f"--- !!! Manager ERROR during connect for User {user_id} / Room {room_key} !!! ---")
            print(f"Error Type: {type(e).__name__}"); print(f"Error Details: {e}"); print("Traceback:"); print(traceback.format_exc())
            raise # Re-raise

    def disconnect(self, websocket: WebSocket, room_key: str):
        print(f"--- Manager DISCONNECT Start --- Room {room_key}")
        if room_key in self.active_connections:
            if websocket in self.active_connections[room_key]:
                user_id = self.active_connections[room_key].get(websocket, 'Unknown')
                # --- Add Logging BEFORE delete ---
                print(f"--- Manager DEBUG --- Removing User {user_id} (socket: {id(websocket)}) from room '{room_key}'.")
                # --- End Logging ---
                del self.active_connections[room_key][websocket]
                count = len(self.active_connections[room_key])
                print(f"--- Manager SUCCESS --- Removed User {user_id}. Remaining in '{room_key}': {count}")
                if not self.active_connections[room_key]:
                    del self.active_connections[room_key]
                    print(f"--- Manager DEBUG --- Room '{room_key}' deleted as empty.")
            else:
                 # Log sockets currently in the room if the target wasn't found
                 current_sockets = [id(ws) for ws in self.active_connections[room_key].keys()]
                 print(f"--- Manager WARNING --- Socket {id(websocket)} not found in room '{room_key}' during disconnect. Current sockets: {current_sockets}")
        else:
             print(f"--- Manager WARNING --- Room '{room_key}' not found during disconnect.")


    async def broadcast(self, message: str, room_key: str):
         if room_key in self.active_connections:
             current_connections = list(self.active_connections[room_key].keys()) # Get sockets
             current_user_ids = list(self.active_connections[room_key].values()) # Get user IDs
             print(f"--- Manager BROADCAST Start --- Room '{room_key}', Sending to {len(current_connections)} users: {current_user_ids}") # Log Users
             # print(f"Broadcasting Message (first 100 chars): {message[:100]}...") # Log Message

             disconnected_websockets = []
             for connection in current_connections:
                 user_id_for_conn = self.active_connections[room_key].get(connection, '?')
                 try:
                     await connection.send_text(message)
                     # print(f"  Sent to User {user_id_for_conn}") # Can be very verbose
                 except Exception as e:
                     print(f"--- Manager ERROR --- Broadcast failed for User {user_id_for_conn} in '{room_key}': {e}")
                     disconnected_websockets.append(connection)

             if disconnected_websockets:
                  print(f"--- Manager DEBUG --- Cleaning up {len(disconnected_websockets)} disconnected sockets from '{room_key}' after broadcast.")
                  for ws in disconnected_websockets:
                      self.disconnect(ws, room_key) # Ensure disconnect uses the correct room key
             print(f"--- Manager BROADCAST End --- Room '{room_key}'")
         else:
             print(f"--- Manager WARNING --- Broadcast ignored, room '{room_key}' not found.")

# Instantiate manager
manager = ConnectionManager()