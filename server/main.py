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

            # Update output
            if output_queue.full():
                output_queue.get_nowait()
            output_queue.put(frame)
            frame_count += 1

    except Exception as e:
        print(f"Processor error for {client_id}: {str(e)}")
    finally:
        print(f"Closing processor for {client_id}")
        output_queue.put(None)

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
    while True:
        try:
            with clients_lock:
                client_data = clients.get(client_id)
                if not client_data or not client_data['running']:
                    break
                output_queue = client_data['output_queue']

            frame = output_queue.get(timeout=1)
            if frame is None:
                break

            ret, jpeg = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 70])
            if ret:
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')
                
        except queue.Empty:
            # Send keep-alive frame
            gray_frame = np.zeros((480, 640, 3), dtype=np.uint8)
            cv2.putText(gray_frame, "Waiting for frames...", (160, 240), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            ret, jpeg = cv2.imencode('.jpg', gray_frame)
            if ret:
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')
        except Exception as e:
            print(f"Stream error for {client_id}: {str(e)}")
            break

@app.route('/video_feed/<client_id>')
def video_feed(client_id):
    return Response(generate_video(client_id), 
                   mimetype='multipart/x-mixed-replace; boundary=frame')

async def handle_websocket(websocket):
    client_id = await websocket.recv()
    input_queue = queue.Queue(maxsize=2)
    output_queue = queue.Queue(maxsize=2)

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
            'thread': processing_thread
        }

    try:
        await websocket.send("REGISTRATION_SUCCESS")
        print(f"New client connected: {client_id}")

        while True:
            message = await websocket.recv()
            if isinstance(message, str):
                if message == "PING":
                    await websocket.send("PONG")
                continue

            np_array = np.frombuffer(message, dtype=np.uint8)
            frame = cv2.imdecode(np_array, cv2.IMREAD_COLOR)
            
            if frame is not None:
                if input_queue.full():
                    input_queue.get_nowait()
                input_queue.put(frame)
            else:
                print(f"Invalid frame from {client_id}")

    except websockets.exceptions.ConnectionClosed as e:
        print(f"Client {client_id} disconnected: {e.code}")
    finally:
        with clients_lock:
            if client_id in clients:
                print(f"Cleaning up {client_id}")
                clients[client_id]['running'] = False
                while not clients[client_id]['input_queue'].empty():
                    clients[client_id]['input_queue'].get()
                clients[client_id]['output_queue'].put(None)
                del clients[client_id]

async def main():
    local_ip = socket.gethostbyname(socket.gethostname())
    server = await websockets.serve(handle_websocket, local_ip, 8888)
    print(f"WebSocket server started on ws://{local_ip}:8888")
    await server.wait_closed()

if __name__ == "__main__":
    flask_thread = threading.Thread(
        target=lambda: app.run(host="0.0.0.0", port=5000, threaded=True),
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
                clients[cid]['running'] = False
                clients[cid]['output_queue'].put(None)
                del clients[cid]