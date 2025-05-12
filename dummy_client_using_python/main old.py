import cv2
import asyncio
import websockets
import time
import traceback

async def send_frames():
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    
    if not cap.isOpened():
        print("Error: Webcam not accessible")
        return

    server_ip = "192.168.225.131"  # Update with your server IP
    websocket_url = f"ws://{server_ip}:8888"
    CLIENT_ID = "garudid001"  
    frame_count = 0

    while True:
        try:
            async with websockets.connect(websocket_url) as ws:
                # Send desired client ID first
                await ws.send(CLIENT_ID)
                
                # Wait for registration confirmation
                response = await ws.recv()
                if response != "REGISTRATION_SUCCESS":
                    print(f"Registration failed: {response}")
                    continue
                
                print(f"Connected as {CLIENT_ID}")
                print(f"Stream URL: http://{server_ip}:5000/video_feed/{CLIENT_ID}")

                while cap.isOpened():
                    start_time = time.time()
                    ret, frame = cap.read()
                    if not ret:
                        print("Frame capture error")
                        break

                    # Add client ID watermark
                    cv2.putText(frame, CLIENT_ID[:8], (10, 30), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
                    
                    _, jpeg = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
                    await ws.send(jpeg.tobytes())

                    # Maintain ~15 FPS
                    elapsed = time.time() - start_time
                    await asyncio.sleep(max(0, 0.066 - elapsed))  # 15 FPS
                    
                    # Send ping every 2 seconds
                    if frame_count % 30 == 0:
                        await ws.send("PING")
                        pong = await asyncio.wait_for(ws.recv(), timeout=1)
                        print(f"Server alive: {pong}")
                    
                    frame_count += 1

        except Exception as e:
            print(f"Connection error: {str(e)}")
            traceback.print_exc()
            await asyncio.sleep(1)
        finally:
            if cap.isOpened():
                cap.release()
            await asyncio.sleep(1)
            cap = cv2.VideoCapture(0)

if __name__ == "__main__":
    try:
        asyncio.get_event_loop().run_until_complete(send_frames())
    except KeyboardInterrupt:
        print("Client stopped")