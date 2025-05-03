import asyncio
import socket
import websockets
import cv2
import numpy as np
import pickle
import time
import threading
import queue
import face_recognition
from flask import Flask, Response
import time

# Load preprocessed face encodings
ENCODINGS_FILE = "face_encodings.pkl"
last_print_times = {}  # {name: timestamp}
PRINT_COOLDOWN = 15 * 60  # 15 minutes in seconds

with open(ENCODINGS_FILE, "rb") as f:
    data = pickle.load(f)
    known_face_encodings = np.array(data["encodings"])  # Convert to numpy array
    known_face_names = data["names"]

# Use queues with maxsize to keep only the latest frames
frame_queue_in = queue.Queue(maxsize=1)
frame_queue_out = queue.Queue(maxsize=1)
recognized_names = []
prev_num_faces = 0

ENCODE_INTERVAL = 10  # Increased interval for encoding
frame_count = 0
running = True

app = Flask(__name__)

def process_frames():
    global frame_count, running, recognized_names, prev_num_faces
    while running:
        if frame_queue_in.empty():
            time.sleep(0.01)
            continue

        frame = frame_queue_in.get()
        current_time = time.time()

        # Convert to RGB and resize for face detection
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        small_rgb_frame = cv2.resize(rgb_frame, (0, 0), fx=0.25, fy=0.25)

        # Detect faces on the small frame every frame
        face_locations_small = face_recognition.face_locations(small_rgb_frame, model="hog")
        current_face_locations = [(top * 4, right * 4, bottom * 4, left * 4) 
                                  for (top, right, bottom, left) in face_locations_small]

        num_faces = len(current_face_locations)
        force_encode = num_faces != prev_num_faces
        prev_num_faces = num_faces

        # Update encodings and names periodically or if face count changes
        if frame_count % ENCODE_INTERVAL == 0 or force_encode:
            current_face_encodings = face_recognition.face_encodings(
                rgb_frame, current_face_locations, model="small"
            )
            current_names = []
            for encoding in current_face_encodings:
                if encoding.size == 0:
                    current_names.append("Unknown")
                    continue
                dists = np.linalg.norm(known_face_encodings - encoding, axis=1)
                matches = dists <= 0.5  # Slightly increased tolerance
                if np.any(matches):
                    first_match_index = np.argmin(dists)  # Closest match
                    name = known_face_names[first_match_index]
                else:
                    name = "Unknown"
                current_names.append(name)
            recognized_names = current_names

        # Use current_names if available, else default to "Unknown"
        names = recognized_names if len(recognized_names) >= len(current_face_locations) else ["Unknown"] * len(current_face_locations)

        # Draw bounding boxes, names, and handle cooldown printing
        for (top, right, bottom, left), name in zip(current_face_locations, names):
            if name != "Unknown":
                last_time = last_print_times.get(name, 0)
                if current_time - last_time >= PRINT_COOLDOWN:
                    print(f"Detected known face: {name} , time = {time.time()}")
                    last_print_times[name] = current_time

            color = (0, 255, 0) if name.endswith("G") else (0, 0, 255) if name != "Unknown" else (0, 255, 255)
            cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
            cv2.putText(frame, name, (left, top - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        frame_count += 1

        # Maintain high FPS output
        while not frame_queue_out.empty():
            try:
                frame_queue_out.get_nowait()
            except queue.Empty:
                break
        frame_queue_out.put(frame)

def generate_video():
    while running:
        frame = frame_queue_out.get()  # Block until a frame is available
        # Lower JPEG quality for faster encoding
        ret, jpeg = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 70])
        if ret:
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')

@app.route('/video_feed')
def video_feed():
    return Response(generate_video(), mimetype='multipart/x-mixed-replace; boundary=frame')

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

async def handle_websocket(websocket):
    try:
        while running:
            message = await websocket.recv()
            if isinstance(message, bytes):
                # Keep only the latest frame in the queue
                while not frame_queue_in.empty():
                    try:
                        frame_queue_in.get_nowait()
                    except queue.Empty:
                        break
                np_array = np.frombuffer(message, dtype=np.uint8)
                frame = cv2.imdecode(np_array, cv2.IMREAD_COLOR)
                if frame is not None:
                    frame_queue_in.put(frame)
    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")

async def main():
    local_ip = get_local_ip()
    server = await websockets.serve(handle_websocket, local_ip, 8888)
    print(f"WebSocket server started on ws://{local_ip}:8888")
    try:
        while running:
            await asyncio.sleep(1)
    finally:
        server.close()
        await server.wait_closed()

if __name__ == "__main__":
    process_thread = threading.Thread(target=process_frames)
    process_thread.start()

    flask_thread = threading.Thread(target=lambda: app.run(host="0.0.0.0", port=5000, threaded=True))
    flask_thread.start()

    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        running = False
    finally:
        running = False
        process_thread.join()
        flask_thread.join()
        cv2.destroyAllWindows()