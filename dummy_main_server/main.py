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
from flask import Flask, Response, render_template_string
from threading import Lock

# Configuration
ENCODINGS_FILE = "face_encodings.pkl"
PRINT_COOLDOWN = 15 * 60  # 15 minutes in seconds

# Load face encodings
try:
    with open(ENCODINGS_FILE, "rb") as f:
        data = pickle.load(f)
        known_face_encodings = np.array(data["encodings"])
        known_face_names = data["names"]
    print(f"Loaded {len(known_face_names)} face encodings")
except Exception as e:
    print(f"Error loading face encodings: {str(e)}")
    known_face_encodings = np.array([])
    known_face_names = []

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
    processed_count = 0
    start_time = time.time()

    print(f"Processor started for {client_id}")
    
    try:
        while running:
            # Check client status
            with clients_lock:
                if client_id not in clients or not clients[client_id]['running']:
                    break

            # Get frame with timeout
            try:
                frame = input_queue.get(timeout=0.5)
                if frame is None:  # Sentinel value for shutdown
                    break
            except queue.Empty:
                continue

            # Process every frame but only do recognition periodically to reduce CPU load
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

            # Face recognition - limit frequency to reduce CPU usage
            if frame_count % 10 == 0 or force_encode:
                if len(current_face_locations) > 0 and len(known_face_encodings) > 0:
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
                else:
                    recognized_names = ["Unknown"] * len(current_face_locations)

            # Draw annotations
            names = recognized_names[:len(current_face_locations)] if len(recognized_names) >= len(current_face_locations) else ["Unknown"]*len(current_face_locations)
            for (top, right, bottom, left), name in zip(current_face_locations, names):
                if name != "Unknown":
                    with print_times_lock:
                        last_time = last_print_times.get(name, 0)
                        if current_time - last_time >= PRINT_COOLDOWN:
                            print(f"Client {client_id}: Detected {name}")
                            last_print_times[name] = current_time

                color = (0, 255, 0) if name.endswith("G") else (0, 0, 255) if name != "Unknown" else (0, 255, 255)
                cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
                cv2.putText(frame, name, (left, top-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

            # Add client ID and stats watermark
            processed_count += 1
            elapsed = current_time - start_time
            fps = processed_count / elapsed if elapsed > 0 else 0
            
            cv2.putText(frame, f"Client: {client_id[:8]}", (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
            cv2.putText(frame, f"FPS: {fps:.1f}", (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
            cv2.putText(frame, f"Faces: {len(current_face_locations)}", (10, 75), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)

            # Update output
            try:
                if output_queue.full():
                    try:
                        output_queue.get_nowait()
                    except queue.Empty:
                        pass
                output_queue.put(frame, block=False)
            except queue.Full:
                pass  # Skip frame if queue is full
                
            frame_count += 1

    except Exception as e:
        print(f"Processor error for {client_id}: {str(e)}")
    finally:
        print(f"Closing processor for {client_id}")
        try:
            output_queue.put(None, block=False)  # Signal to stop streaming
        except queue.Full:
            pass

def generate_video(client_id):
    try:
        while True:
            try:
                with clients_lock:
                    client_data = clients.get(client_id)
                    if not client_data or not client_data['running']:
                        break

                # Use a local reference to avoid locks during get operation
                output_queue = client_data['output_queue']
                frame = output_queue.get(timeout=1)
                
                if frame is None:
                    print(f"Stream ended for {client_id}")
                    break

                ret, jpeg = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 70])
                if ret:
                    yield (b'--frame\r\n'
                        b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')
                    
            except queue.Empty:
                # Send keep-alive frame
                gray_frame = np.zeros((480, 640, 3), dtype=np.uint8)
                cv2.putText(gray_frame, f"Waiting for frames from {client_id}...", (120, 240), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                ret, jpeg = cv2.imencode('.jpg', gray_frame)
                if ret:
                    yield (b'--frame\r\n'
                        b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')
    except Exception as e:
        print(f"Stream generation error for {client_id}: {str(e)}")
    finally:
        print(f"Stream generation ended for {client_id}")

@app.route('/')
def index():
    html = '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Face Recognition Streams</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            h1 { color: #333; }
            .streams { display: flex; flex-wrap: wrap; gap: 20px; }
            .stream-container { margin-bottom: 20px; }
            .stream { border: 1px solid #ddd; padding: 10px; }
            img { max-width: 640px; height: auto; }
        </style>
        <script>
            function refreshClients() {
                fetch('/clients')
                    .then(response => response.json())
                    .then(data => {
                        const streamsDiv = document.getElementById('streams');
                        streamsDiv.innerHTML = '';
                        
                        if (data.clients.length === 0) {
                            streamsDiv.innerHTML = '<p>No active clients</p>';
                            return;
                        }
                        
                        data.clients.forEach(client => {
                            const container = document.createElement('div');
                            container.className = 'stream-container';
                            
                            const title = document.createElement('h3');
                            title.textContent = `Client: ${client}`;
                            
                            const img = document.createElement('img');
                            img.src = `/video_feed/${client}`;
                            img.alt = `Stream from ${client}`;
                            
                            const streamDiv = document.createElement('div');
                            streamDiv.className = 'stream';
                            streamDiv.appendChild(img);
                            
                            container.appendChild(title);
                            container.appendChild(streamDiv);
                            streamsDiv.appendChild(container);
                        });
                    });
            }
            
            // Refresh client list every 5 seconds
            setInterval(refreshClients, 5000);
            
            // Initial load
            document.addEventListener('DOMContentLoaded', refreshClients);
        </script>
    </head>
    <body>
        <h1>Face Recognition Streams</h1>
        <div id="streams" class="streams">
            <p>Loading clients...</p>
        </div>
    </body>
    </html>
    '''
    return render_template_string(html)

@app.route('/clients')
def get_clients():
    with clients_lock:
        client_list = list(clients.keys())
    return {'clients': client_list}

@app.route('/video_feed/<client_id>')
def video_feed(client_id):
    return Response(generate_video(client_id), 
                   mimetype='multipart/x-mixed-replace; boundary=frame')

async def handle_websocket(websocket):
    client_id = None
    input_queue = None
    output_queue = None
    processing_thread = None
    
    try:
        client_id = await websocket.recv()
        
        # Check if client already exists and clean up if needed
        with clients_lock:
            if client_id in clients:
                old_client = clients[client_id]
                old_client['running'] = False
                try:
                    old_client['input_queue'].put(None, block=False)  # Signal to stop
                except queue.Full:
                    pass
                print(f"Terminating previous session for client {client_id}")
        
        # Create new queues with reasonable buffer sizes
        input_queue = queue.Queue(maxsize=3)
        output_queue = queue.Queue(maxsize=3)

        # Start processing thread for this client
        processing_thread = threading.Thread(
            target=process_frames,
            args=(input_queue, output_queue, client_id),
            daemon=True
        )
        processing_thread.start()

        # Register the client
        with clients_lock:
            clients[client_id] = {
                'input_queue': input_queue,
                'output_queue': output_queue,
                'running': True,
                'thread': processing_thread,
                'last_active': time.time()
            }

        await websocket.send("REGISTRATION_SUCCESS")
        print(f"New client connected: {client_id}")

        ping_timeout = time.time()
        
        while True:
            # Check for client timeout (no data for 30 seconds)
            current_time = time.time()
            if current_time - ping_timeout > 30:
                await websocket.send("PING")
                ping_timeout = current_time

            # Wait for next message with timeout
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=1.0)
            except asyncio.TimeoutError:
                # Check if client is still running
                with clients_lock:
                    if client_id not in clients or not clients[client_id]['running']:
                        break
                continue
            
            # Update last active timestamp
            with clients_lock:
                if client_id in clients:
                    clients[client_id]['last_active'] = time.time()
            
            # Process message
            if isinstance(message, str):
                if message == "PING":
                    await websocket.send("PONG")
                continue

            # Process frame data
            np_array = np.frombuffer(message, dtype=np.uint8)
            frame = cv2.imdecode(np_array, cv2.IMREAD_COLOR)
            
            if frame is not None:
                try:
                    if input_queue.full():
                        try:
                            input_queue.get_nowait()  # Make room for new frame
                        except queue.Empty:
                            pass
                    input_queue.put(frame, block=False)
                except queue.Full:
                    pass  # Skip frame if queue is full
            else:
                print(f"Invalid frame from {client_id}")

    except websockets.exceptions.ConnectionClosed as e:
        print(f"Client {client_id} disconnected: {e.code}")
    except Exception as e:
        print(f"Error in websocket handler: {str(e)}")
    finally:
        # Clean up client resources
        if client_id:
            with clients_lock:
                if client_id in clients:
                    print(f"Cleaning up {client_id}")
                    clients[client_id]['running'] = False
                    
                    # Try to drain input queue
                    if input_queue:
                        while not input_queue.empty():
                            try:
                                input_queue.get_nowait()
                            except queue.Empty:
                                break
                        try:
                            input_queue.put(None, block=False)  # Signal processor to stop
                        except queue.Full:
                            pass
                    
                    # Wait a moment for thread to clean up
                    time.sleep(0.5)
                    del clients[client_id]

# Periodically clean up inactive clients
async def cleanup_inactive_clients():
    while running:
        inactive_clients = []
        current_time = time.time()
        
        # Find inactive clients
        with clients_lock:
            for cid, client_data in clients.items():
                if current_time - client_data.get('last_active', 0) > 60:  # 60 seconds timeout
                    inactive_clients.append(cid)
        
        # Clean up inactive clients
        for cid in inactive_clients:
            with clients_lock:
                if cid in clients:
                    print(f"Removing inactive client: {cid}")
                    clients[cid]['running'] = False
                    try:
                        clients[cid]['input_queue'].put(None, block=False)
                    except queue.Full:
                        pass
                    del clients[cid]
        
        # Sleep before next check
        await asyncio.sleep(30)

async def main():
    local_ip = socket.gethostbyname(socket.gethostname())
    server = await websockets.serve(
        handle_websocket, 
        local_ip, 
        8888,
        ping_timeout=60,  # Increased timeout
        max_size=10 * 1024 * 1024  # 10MB max message size for large frames
    )
    print(f"WebSocket server started on ws://{local_ip}:8888")
    print(f"Web interface available at http://{local_ip}:5000")
    
    # Start client cleanup task
    cleanup_task = asyncio.create_task(cleanup_inactive_clients())
    
    try:
        await server.wait_closed()
    finally:
        cleanup_task.cancel()
        try:
            await cleanup_task
        except asyncio.CancelledError:
            pass

if __name__ == "__main__":
    flask_thread = threading.Thread(
        target=lambda: app.run(host="0.0.0.0", port=5000, threaded=True),
        daemon=True
    )
    flask_thread.start()
    print("Flask server started on port 5000")

    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Shutting down server...")
    finally:
        running = False
        with clients_lock:
            for cid in list(clients.keys()):
                clients[cid]['running'] = False
                try:
                    clients[cid]['input_queue'].put(None, block=False)
                except queue.Full:
                    pass
        time.sleep(1)  # Give threads time to clean up
        print("Server shutdown complete")