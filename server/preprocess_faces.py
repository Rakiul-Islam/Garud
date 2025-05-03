import face_recognition
import os
import pickle

KNOWN_FACES_DIR = "resources"
ENCODINGS_FILE = "face_encodings.pkl"

known_face_encodings = []
known_face_names = []

print("Processing known faces...")

for filename in os.listdir(KNOWN_FACES_DIR):
    img_path = os.path.join(KNOWN_FACES_DIR, filename)
    img = face_recognition.load_image_file(img_path)
    encoding = face_recognition.face_encodings(img)

    if encoding:
        known_face_encodings.append(encoding[0])
        known_face_names.append(os.path.splitext(filename)[0])
    else:
        print(f"Warning: No face found in {filename}")

with open(ENCODINGS_FILE, "wb") as f:
    pickle.dump({"encodings": known_face_encodings, "names": known_face_names}, f)

print(f"Encodings saved to {ENCODINGS_FILE}")
