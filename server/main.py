import asyncio
import json
import socket
import requests
import websockets
import cv2
import numpy as np
import pickle
import time
import threading
import queue
import face_recognition
from flask import Flask, Response, jsonify, request
from threading import Lock
import firebase_admin
from firebase_admin import credentials, firestore, messaging
from google.cloud import firestore
from google.oauth2 import service_account
from google.auth.transport.requests import Request as GoogleRequest

# Configuration
ENCODINGS_FILE = "face_encodings.pkl"
PRINT_COOLDOWN = 15 * 60  # 15 minutes in seconds
PROJECT_ID = "garud-21e17"

# Initialize Firebase only once
credentials = service_account.Credentials.from_service_account_file(
    "service_account.json",
    scopes=[
        "https://www.googleapis.com/auth/datastore",
        "https://www.googleapis.com/auth/firebase.messaging"
    ]
)

# Setup Firestore client
db = firestore.Client(credentials=credentials, project=PROJECT_ID)

# Load face encodings
with open(ENCODINGS_FILE, "rb") as f:
    data = pickle.load(f)
    known_face_encodings = np.array(data["encodings"])
    known_face_names = data["names"]

# Global state
clients = {}
clients_lock = Lock()
last_print_times = {}
print_times_lock = Lock()
running = True

app = Flask(__name__)

def process_frames(input_queue, output_queue, client_id):
    global running, known_face_encodings, known_face_names
    frame_count = 0
    recognized_names = []
    prev_num_faces = 0

    print(f"Processor started for {client_id}")
    try:
        # Fetch UID from garudIDMap
        doc_ref = db.collection("garudIdMap").document(client_id)
        doc = doc_ref.get()
        if doc.exists:
            uid = doc.to_dict().get("uid")
            # Assuming user's FCM token is stored in collection "users" as "fcm_token"
            user_doc = db.collection("users").document(uid).get()
            fcm_token = user_doc.to_dict().get("token")
        else:
            print(f"No UID mapping found for client_id {client_id}")
            fcm_token = None
        print(f"UID: {uid}, FCM Token: {fcm_token}")
    except Exception as e:
        print(f"Error retrieving UID/FCM token: {e}")
        fcm_token = None
    
    try:
        while running:
            # Check client status
            with clients_lock:
                if client_id not in clients or not clients[client_id]['running']:
                    break

            # Get frame with timeout
            try:
                frame = input_queue.get(timeout=0.5)
            except queue.Empty:
                continue

            current_time = time.time()
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            small_rgb_frame = cv2.resize(rgb_frame, (0, 0), fx=0.25, fy=0.25)

            # Face detection
            face_locations_small = face_recognition.face_locations(small_rgb_frame, model="hog")
            current_face_locations = [(top*4, right*4, bottom*4, left*4) 
                                    for (top, right, bottom, left) in face_locations_small]

            num_faces = len(current_face_locations)
            force_encode = num_faces != prev_num_faces
            prev_num_faces = num_faces

            # Face recognition
            if frame_count % 10 == 0 or force_encode:
                current_face_encodings = face_recognition.face_encodings(
                    rgb_frame, current_face_locations, model="small"
                )
                current_names = []
                for encoding in current_face_encodings:
                    if encoding.size == 0:
                        current_names.append("Unknown")
                        continue
                    dists = np.linalg.norm(known_face_encodings - encoding, axis=1)
                    matches = dists <= 0.5
                    if np.any(matches):
                        first_match_index = np.argmin(dists)
                        name = known_face_names[first_match_index]
                    else:
                        name = "Unknown"
                    current_names.append(name)
                recognized_names = current_names

            # Draw annotations
            names = recognized_names if len(recognized_names) >= len(current_face_locations) else ["Unknown"]*len(current_face_locations)
            for (top, right, bottom, left), name in zip(current_face_locations, names):
                if name != "Unknown":
                    with print_times_lock:
                        last_time = last_print_times.get(name, 0)
                        if current_time - last_time >= PRINT_COOLDOWN:
                            print(f"Detected: {name}")
                            last_print_times[name] = current_time

                            # Send FCM notification
                            if fcm_token:
                                detectedData = {"name": name}
                                send_notification(uid , fcm_token, detectedData, "self")
                                send_notifications_to_guardians(uid, detectedData )

                color = (0, 255, 0) if name.endswith("G") else (0, 0, 255) if name != "Unknown" else (0, 255, 255)
                cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
                cv2.putText(frame, name, (left, top-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

            # Add client ID watermark
            cv2.putText(frame, client_id[:8], (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

            # Update output - Always put processed frame
            try:
                if output_queue.full():
                    output_queue.get_nowait()
                output_queue.put(frame)
            except:
                pass  # Queue might be closed
            frame_count += 1

    except Exception as e:
        print(f"Processor error for {client_id}: {str(e)}")
    finally:
        print(f"Closing processor for {client_id}")
        # Put sentinel value to signal end
        try:
            output_queue.put(None, block=False)
        except:
            pass

def get_access_token():
    auth_req = GoogleRequest()
    credentials.refresh(auth_req)
    return credentials.token

# Send FCM push notification
def send_notification(uid, fcm_token, detectedData, mod):
    # mod = "self" or "guardian"
    # detectedData is a dictionary containing the name and extra info about the detected person 
    url = f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"
    headers = {
        "Authorization": f"Bearer {get_access_token()}",
        "Content-Type": "application/json; UTF-8",
    }

    if mod == "self":
        title = detectedData["name"] + " was detected on your device."
    elif mod == "guardian":
        title = detectedData["name"] + " was detected on " + uid + "'s device."
    else:
        raise ValueError("Invalid mod value. Use 'self' or 'guardian'.")

    message_payload = {
        "message": {
            "token": fcm_token,
            "notification": {
                "title": title,
                "body": "",
            },
            "data": detectedData or {}
        }
    }

    response = requests.post(url, headers=headers, data=json.dumps(message_payload))
    return response.status_code, response.text

def send_notifications_to_guardians(uid, detectedData):
    try:
        user_doc = db.collection("users").document(uid).get()
        if not user_doc.exists:
            print(f"User {uid} not found.")
            return

        user_data = user_doc.to_dict()
        guardian_ids = user_data.get("guardians", [])

        print(f"Guardians for {uid}: {guardian_ids}")

        for guardian_id in guardian_ids:
            guardian_doc = db.collection("users").document(guardian_id).get()
            if guardian_doc.exists:
                guardian_data = guardian_doc.to_dict()
                fcm_token = guardian_data.get("token")
                if fcm_token:
                    status_code, response_text = send_notification(uid, fcm_token, detectedData, "guardian")
                    print(f"Sent notification to guardian: {guardian_id} | Status: {status_code}")
                else:
                    print(f"No FCM token found for guardian: {guardian_id}")
            else:
                print(f"Guardian document not found: {guardian_id}")

    except Exception as e:
        print(f"Error sending notification to guardians of {uid}: {e}")

def generate_video(client_id):
    print(f"Starting video feed for {client_id}")
    frame_timeout = 10  # seconds
    last_frame_time = time.time()
    
    while True:
        try:
            # Check if client still exists and is running
            with clients_lock:
                client_data = clients.get(client_id)
                if not client_data or not client_data['running']:
                    print(f"Client {client_id} not found or not running, stopping video feed")
                    break
                output_queue = client_data['output_queue']

            try:
                frame = output_queue.get(timeout=1)
                current_time = time.time()
                
                if frame is None:
                    print(f"Received None frame for {client_id}, ending stream")
                    break
                    
                last_frame_time = current_time
                
                # Encode and yield frame
                ret, jpeg = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 70])
                if ret:
                    yield (b'--frame\r\n'
                           b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')
                
            except queue.Empty:
                # Check if we've been waiting too long for frames
                if time.time() - last_frame_time > frame_timeout:
                    print(f"No frames received for {client_id} in {frame_timeout} seconds")
                    break
                    
                # Send keep-alive frame
                gray_frame = np.zeros((480, 640, 3), dtype=np.uint8)
                cv2.putText(gray_frame, f"Waiting for {client_id[:8]}...", (160, 220), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                cv2.putText(gray_frame, "No frames received", (180, 260), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (150, 150, 150), 1)
                
                ret, jpeg = cv2.imencode('.jpg', gray_frame)
                if ret:
                    yield (b'--frame\r\n'
                           b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')
                
        except Exception as e:
            print(f"Stream error for {client_id}: {str(e)}")
            break
    
    print(f"Video feed ended for {client_id}")

@app.route('/video_feed/<client_id>')
def video_feed(client_id):
    # Check if client exists before starting video feed
    with clients_lock:
        if client_id not in clients:
            return f"Client {client_id} not found", 404
    
    return Response(generate_video(client_id), 
                   mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/status/<client_id>')
def client_status(client_id):
    """Check if a client is connected and active"""
    with clients_lock:
        if client_id in clients and clients[client_id]['running']:
            return jsonify({"status": "active", "client_id": client_id})
        else:
            return jsonify({"status": "inactive", "client_id": client_id}), 404

def cleanup_client(client_id):
    """Properly cleanup client resources"""
    print(f"Starting cleanup for {client_id}")
    with clients_lock:
        if client_id in clients:
            client_data = clients[client_id]
            client_data['running'] = False
            
            # Clear input queue
            while not client_data['input_queue'].empty():
                try:
                    client_data['input_queue'].get_nowait()
                except queue.Empty:
                    break
            
            # Signal output queue to stop
            try:
                client_data['output_queue'].put(None, block=False)
            except queue.Full:
                pass
            
            # Wait a bit for thread to finish
            if 'thread' in client_data and client_data['thread'].is_alive():
                client_data['thread'].join(timeout=2)
            
            del clients[client_id]
            print(f"Cleanup completed for {client_id}")

async def handle_websocket(websocket):
    client_id = None
    try:
        client_id = await websocket.recv()
        print(f"New connection attempt from {client_id}")
        
        # Clean up any existing connection with same ID
        cleanup_client(client_id)
        
        input_queue = queue.Queue(maxsize=5)  # Increased queue size
        output_queue = queue.Queue(maxsize=5)

        processing_thread = threading.Thread(
            target=process_frames,
            args=(input_queue, output_queue, client_id),
            daemon=True
        )
        processing_thread.start()

        with clients_lock:
            clients[client_id] = {
                'input_queue': input_queue,
                'output_queue': output_queue,
                'running': True,
                'thread': processing_thread,
                'websocket': websocket
            }

        await websocket.send("REGISTRATION_SUCCESS")
        print(f"Client registered successfully: {client_id}")

        while True:
            message = await websocket.recv()
            if isinstance(message, str):
                if message == "PING":
                    await websocket.send("PONG")
                elif message == "DISCONNECT":
                    print(f"Client {client_id} requested disconnect")
                    break
                continue

            np_array = np.frombuffer(message, dtype=np.uint8)
            frame = cv2.imdecode(np_array, cv2.IMREAD_COLOR)
            
            if frame is not None:
                # Check if client is still active
                with clients_lock:
                    if client_id not in clients or not clients[client_id]['running']:
                        break
                        
                try:
                    if input_queue.full():
                        input_queue.get_nowait()  # Remove oldest frame
                    input_queue.put(frame, block=False)
                except queue.Full:
                    pass  # Skip frame if queue is full
            else:
                print(f"Invalid frame from {client_id}")

    except websockets.exceptions.ConnectionClosed as e:
        print(f"Client {client_id} disconnected: {e.code}")
    except Exception as e:
        print(f"WebSocket error for {client_id}: {str(e)}")
    finally:
        if client_id:
            cleanup_client(client_id)

async def main():
    local_ip = socket.gethostbyname(socket.gethostname())
    server = await websockets.serve(handle_websocket, local_ip, 8888)
    print(f"WebSocket server started on ws://{local_ip}:8888")
    await server.wait_closed()

if __name__ == "__main__":
    flask_thread = threading.Thread(
        target=lambda: app.run(host="0.0.0.0", port=5000, threaded=True, debug=False),
        daemon=True
    )
    flask_thread.start()

    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        running = False
    finally:
        running = False
        with clients_lock:
            for cid in list(clients.keys()):
                cleanup_client(cid)