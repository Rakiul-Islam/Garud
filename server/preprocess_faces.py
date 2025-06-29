import face_recognition
import os
import pickle
import cv2
import numpy as np

KNOWN_FACES_DIR = "resources"
ENCODINGS_FILE = "face_encodings.pkl"

known_face_encodings = []
known_face_names = []

print("Processing known faces...")

for filename in os.listdir(KNOWN_FACES_DIR):
    img_path = os.path.join(KNOWN_FACES_DIR, filename)
    
    bgr_img = cv2.imread(img_path)
    if bgr_img is None:
        print(f"Error reading image: {filename}")
        continue

    rgb_img = cv2.cvtColor(bgr_img, cv2.COLOR_BGR2RGB)

    encoding = face_recognition.face_encodings(rgb_img)
    if encoding:
        known_face_encodings.append(encoding[0])
        known_face_names.append(os.path.splitext(filename)[0])
        print(f"Encoded: {filename}")
    else:
        print(f"Warning: No face found in {filename}")

with open(ENCODINGS_FILE, "wb") as f:
    pickle.dump({"encodings": known_face_encodings, "names": known_face_names}, f)

print(f"Encodings saved to {ENCODINGS_FILE}")
