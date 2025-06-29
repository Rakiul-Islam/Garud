import cv2
import numpy as np
import face_recognition
import pickle
import time
import queue
import threading

ENCODINGS_FILE = "face_encodings.pkl"
PRINT_COOLDOWN = 15 * 60  # 15 minutes
client_id = "local_test"
running = True

# Load known encodings
with open(ENCODINGS_FILE, "rb") as f:
    data = pickle.load(f)
    known_face_encodings = np.array(data["encodings"])
    known_face_names = data["names"]

# Shared state
print_times_lock = threading.Lock()
last_print_times = {}

def process_frames(input_queue, output_queue, client_id):
    global running
    frame_count = 0
    recognized_names = []
    prev_num_faces = 0

    print(f"Processor started for {client_id}")

    try:
        while running:
            try:
                frame = input_queue.get(timeout=0.5)
                if frame is None or frame.size == 0:
                    continue
            except queue.Empty:
                continue

            if frame.dtype != np.uint8 or frame.ndim not in (2, 3):
                continue

            current_time = time.time()

            # Convert to RGB safely
            try:
                if frame.ndim == 2:
                    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2RGB)
                elif frame.shape[2] == 4:
                    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2RGB)
                else:
                    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            except Exception:
                continue

            try:
                small_rgb_frame = cv2.resize(rgb_frame, (0, 0), fx=0.25, fy=0.25)
            except Exception:
                continue

            try:
                face_locations_small = face_recognition.face_locations(small_rgb_frame, model="hog")
                current_face_locations = [(top*4, right*4, bottom*4, left*4)
                                          for (top, right, bottom, left) in face_locations_small]
            except Exception:
                current_face_locations = []

            num_faces = len(current_face_locations)
            force_encode = num_faces != prev_num_faces
            prev_num_faces = num_faces

            if frame_count % 10 == 0 or force_encode:
                current_face_encodings = []
                try:
                    current_face_encodings = face_recognition.face_encodings(
                        rgb_frame, current_face_locations, model="small"
                    )
                except Exception:
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
                    except Exception:
                        name = "Unknown"
                    current_names.append(name)

                recognized_names = current_names

            # Draw results
            names = recognized_names if len(recognized_names) >= len(current_face_locations) else ["Unknown"]*len(current_face_locations)
            for (top, right, bottom, left), name in zip(current_face_locations, names):
                if name != "Unknown":
                    with print_times_lock:
                        last_time = last_print_times.get(name, 0)
                        if current_time - last_time >= PRINT_COOLDOWN:
                            print(f"Detected: {name}")
                            last_print_times[name] = current_time

                color = (0, 255, 0) if name.endswith("G") else (0, 0, 255) if name != "Unknown" else (0, 255, 255)
                cv2.rectangle(frame, (left, top), (right, bottom), color, 2)
                cv2.putText(frame, name, (left, top - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

            cv2.putText(frame, client_id[:8], (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)

            try:
                if not output_queue.full():
                    output_queue.put(frame)
            except:
                pass

            frame_count += 1

    except Exception as e:
        print(f"Processor error: {e}")
    finally:
        print(f"Closing processor for {client_id}")
        try:
            output_queue.put(None, block=False)
        except:
            pass

# Webcam & thread setup
input_queue = queue.Queue(maxsize=5)
output_queue = queue.Queue(maxsize=5)

processor_thread = threading.Thread(target=process_frames, args=(input_queue, output_queue, client_id), daemon=True)
processor_thread.start()

cap = cv2.VideoCapture(0)
print("Press 'q' to exit.")

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        print("Failed to read frame.")
        break

    if not input_queue.full():
        input_queue.put(frame)

    try:
        processed_frame = output_queue.get(timeout=0.1)
        if processed_frame is None:
            break
        cv2.imshow("Face Recognition", processed_frame)
    except queue.Empty:
        pass

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

running = False
cap.release()
cv2.destroyAllWindows()
processor_thread.join()
