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
from firebase_admin import credentials, firestore, messaging
from google.cloud import firestore
from google.oauth2 import service_account
from google.auth.transport.requests import Request as GoogleRequest

# Configuration
ENCODINGS_FILE = "face_encodings.pkl"
PRINT_COOLDOWN = 5 * 60  # 5 minutes in seconds
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
            client_uid = doc.to_dict().get("uid")
            user_doc = db.collection("users").document(client_uid).get()
            user_doc = user_doc.to_dict()
            fcm_token = user_doc.get("token")
            client_name = user_doc.get("name")
            client_gairdians = user_doc.get("guardians", [])
        else:
            print(f"No UID mapping found for client_id {client_id}")
            fcm_token = None
        print(f"UID: {client_uid}, FCM Token: {fcm_token}")
    except Exception as e:
        print(f"Error retrieving UID/FCM token: {e}")
        fcm_token = None

    try:
        while running:
            # Check client status
            with clients_lock:
                if client_id not in clients or not clients[client_id]['running']:
                    print(f"Processor stopping: client {client_id} not active")
                    break

            try:
                frame = input_queue.get(timeout=0.5)
                if frame is None or frame.size == 0:
                    continue
            except queue.Empty:
                continue

            # Validate frame properties
            if frame.dtype != np.uint8:
                print(f"Invalid frame dtype: {frame.dtype}")
                continue
                
            if frame.ndim not in (2, 3):
                print(f"Invalid frame dimensions: {frame.ndim}")
                continue

            current_time = time.time()

            # Robust color conversion
            try:
                if frame.ndim == 2:  # Grayscale
                    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2RGB)
                elif frame.shape[2] == 4:  # BGRA format
                    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2RGB)
                else:  # Assume BGR
                    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            except Exception as e:
                print(f"Frame conversion error: {e}")
                continue

            # Create resized copy for face detection
            try:
                small_rgb_frame = cv2.resize(rgb_frame, (0, 0), fx=0.25, fy=0.25)
                if small_rgb_frame.size == 0:
                    print("Resized frame is empty")
                    continue
            except Exception as e:
                print(f"Resize error: {e}")
                continue

            # Face detection
            try:
                face_locations_small = face_recognition.face_locations(small_rgb_frame, model="hog")
                current_face_locations = [(top*4, right*4, bottom*4, left*4)
                                        for (top, right, bottom, left) in face_locations_small]
            except Exception as e:
                print(f"Face location error: {e}")
                current_face_locations = []
                
            num_faces = len(current_face_locations)
            force_encode = num_faces != prev_num_faces
            prev_num_faces = num_faces

            # Face recognition
            if frame_count % 10 == 0 or force_encode:
                current_face_encodings = []
                if current_face_locations:
                    try:
                        current_face_encodings = face_recognition.face_encodings(
                            rgb_frame, current_face_locations, model="small"
                        )
                    except Exception as e:
                        print(f"Encoding error: {e}")
                        current_face_encodings = []

                current_names = []
                for encoding in current_face_encodings:
                    if encoding.size == 0:
                        current_names.append("Unknown")
                        continue
                    try:
                        dists = np.linalg.norm(known_face_encodings - encoding, axis=1)
                        matches = dists <= 0.5
                        if np.any(matches):
                            first_match_index = np.argmin(dists)
                            name = known_face_names[first_match_index]
                        else:
                            name = "Unknown"
                    except Exception as e:
                        print(f"Recognition error: {e}")
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

                            if fcm_token:
                                handle_known_face_detection(name, fcm_token, client_uid, client_id, client_name, client_gairdians)  
                                
                color = (0, 255, 0) if name.endswith("G") else (0, 0, 255) if name != "Unknown" else (0, 255, 255)
                cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
                cv2.putText(frame, name, (left, top - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

            # Add client ID watermark
            cv2.putText(frame, client_id[:8], (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

            try:
                if not output_queue.full():
                    output_queue.put(frame)
            except:
                pass  # Queue might be closed
            frame_count += 1

    except Exception as e:
        print(f"Processor error for {client_id}: {str(e)}")
    finally:
        print(f"Closing processor for {client_id}")
        try:
            output_queue.put(None, block=False)
        except:
            pass

def handle_known_face_detection(criminal_name: str, fcm_token: str, client_uid: str, client_id: str, client_name: str, client_gaurdians: list):
    try:
        print(f"[INFO] Starting handle_known_face_detection for {criminal_name} on device {client_id}")

        # Get criminal data
        print(f"[INFO] Fetching criminal document: {criminal_name}")
        criminal_doc = db.collection("criminals").document(criminal_name).get()
        if not criminal_doc.exists:
            print(f"[WARN] Criminal document not found: {criminal_name}")
            return

        criminal_data = criminal_doc.to_dict()
        full_name = criminal_data.get("full_name", criminal_name)
        threat_level = criminal_data.get("threat_level", "Unknown")
        print(f"[INFO] Retrieved criminal data: full_name={full_name}, threat_level={threat_level}")

        # Prepare detected data
        detectedData = {
            "criminal_id": criminal_name,
            "criminal_name": full_name,
            "threat_level": threat_level,
            "timestamp": time.time(),
            "location": {
                "latitude": 0.0,  # Optional: update with actual coordinates
                "longitude": 0.0
            }
        }
        print(f"[INFO] Constructed detectedData: {detectedData}")

        # Send notification to user
        if fcm_token:
            print(f"[INFO] Sending notification to user {client_uid}")
            response_code, response_text = send_notification(fcm_token, client_name, detectedData, "self")
            if response_code == 200:
                print(f"[INFO] Notification sent successfully to user {client_uid}: {response_text}")
            else:
                print(f"[ERROR] Failed to send notification to user {client_uid}: {response_text}")
        else:
            print(f"[INFO] No FCM token for user {client_uid}, skipping notification")

        # Store detection for user
        print(f"[INFO] Storing detection for user {client_uid}")
        db.collection("users").document(client_uid).collection("notifications").add({
            **detectedData,
            "detected_on_self": True,
            "read": False
        })
        print(f"[INFO] Detection stored for user {client_uid}")

        # Notify and store for guardians
        print(f"[INFO] Notifying guardians of user {client_uid}")
        for guardian in client_gaurdians:
            guardian_uid = guardian.get("uid")
            if not guardian_uid:
                print(f"[WARN] Guardian entry missing 'uid', skipping: {guardian}")
                continue

            print(f"[INFO] Fetching guardian document: {guardian_uid}")
            guardian_doc = db.collection("users").document(guardian_uid).get()
            if guardian_doc.exists:
                guardian_data = guardian_doc.to_dict()
                guardian_token = guardian_data.get("token")
                if guardian_token:
                    print(f"[INFO] Sending notification to guardian {guardian_uid}")
                    send_notification(guardian_token, client_name, detectedData, "guardian")
                else:
                    print(f"[WARN] No FCM token for guardian {guardian_uid}, skipping notification")

                print(f"[INFO] Storing detection for guardian {guardian_uid}")
                db.collection("users").document(guardian_uid).collection("notifications").add({
                    **detectedData,
                    "detected_on_self": False,
                    "detected_on_protege_s_uid": client_uid,
                    "detected_on_protege_s_name": client_name,
                    "read": False
                })
                print(f"[INFO] Detection stored for guardian {guardian_uid}")
            else:
                print(f"[WARN] Guardian document not found: {guardian_uid}")

        print(f"[INFO] Finished handle_known_face_detection for {criminal_name} on device {client_id}")

    except Exception as e:
        print(f"[ERROR] handle_known_face_detection for {client_id}: {e}")


def get_access_token():
    auth_req = GoogleRequest()
    credentials.refresh(auth_req)
    return credentials.token

# Send FCM push notification
def send_notification(fcm_token, client_name, detectedData, mode):
    # mod = "self" or "guardian"
    # detectedData is a dictionary containing the name and extra info about the detected person 
    url = f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"
    headers = {
        "Authorization": f"Bearer {get_access_token()}",
        "Content-Type": "application/json; UTF-8",
    }

    if mode == "self":
        title = f"{detectedData['criminal_name']} was detected on your device."
    elif mode == "guardian":
        title = f"{detectedData['criminal_name']} was detected on {client_name}'s device."
    else:
        raise ValueError("Invalid mod value. Use 'self' or 'guardian'.")

    message_payload = {
        "message": {
            "token": fcm_token,
            "notification": {
                "title": title,
                "body": "Threat level: " + detectedData["threat_level"],
            },
            "data": {
                "type": "threat_related",
            }
        }
    }

    try:
        response = requests.post(url, headers=headers, data=json.dumps(message_payload))
        print(f"Notification sent to {fcm_token} with response code {response.text}")
        return response.status_code, response.text
    except Exception as e:
        print(f"Notification send error: {e}")
        return 500, str(e)

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

@app.route('/')
def index():
    return "Hello from Garud"

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
        
        input_queue = queue.Queue(maxsize=5)
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

            # Validate frame data
            if len(message) < 100:  # Minimum valid frame size
                print(f"Received suspiciously small frame ({len(message)} bytes)")
                continue

            try:
                np_array = np.frombuffer(message, dtype=np.uint8)
                frame = cv2.imdecode(np_array, cv2.IMREAD_COLOR)
                
                if frame is None or frame.size == 0:
                    print(f"Invalid frame from {client_id}")
                    continue
                    
                # Check if client is still active
                with clients_lock:
                    if client_id not in clients or not clients[client_id]['running']:
                        break
                        
                try:
                    if not input_queue.full():
                        input_queue.put(frame, block=False)
                except queue.Full:
                    pass  # Skip frame if queue is full
            except Exception as e:
                print(f"Frame processing error: {str(e)}")

    except websockets.exceptions.ConnectionClosed as e:
        print(f"Client {client_id} disconnected: {e.code}")
    except Exception as e:
        print(f"WebSocket error for {client_id}: {str(e)}")
    finally:
        if client_id:
            cleanup_client(client_id)

async def main():
    local_ip = "0.0.0.0"  # Run on localhost
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