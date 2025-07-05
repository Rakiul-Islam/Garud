import asyncio
import websockets
import cv2
import numpy as np

SERVER_URI = "ws://localhost:8888/ws" 
# SERVER_URI = "ws://ws.rakiulislam.tech/ws"  # Replace <server_ip> with your actual server IP
# SERVER_URI = "ws://127.0.0.1:8888/ws" 
# SERVER_URI = "ws://ip172-18-0-21-d1j0hvc69qi000b7huhg-5000.direct.labs.play-with-docker.com/ws"
CLIENT_ID = "garud001"

async def send_frames():
    async with websockets.connect(SERVER_URI) as websocket:
        # Send client ID
        await websocket.send(CLIENT_ID)
        print(f"Sent client_id: {CLIENT_ID}")

        # Wait for server acknowledgment
        response = await websocket.recv()
        print(f"Server response: {response}")

        cap = cv2.VideoCapture(0)  # Open default webcam
        if not cap.isOpened():
            print("Cannot open camera")
            return

        try:
            while True:
                ret, frame = cap.read()
                if not ret:
                    print("Failed to grab frame")
                    break

                # Encode frame as JPEG
                _, jpeg = cv2.imencode('.jpg', frame)
                await websocket.send(jpeg.tobytes())

                # Optional: send ping every few seconds
                await asyncio.sleep(0.1)

        except KeyboardInterrupt:
            print("Client stopped")
        finally:
            cap.release()

asyncio.run(send_frames())
