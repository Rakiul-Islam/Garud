import asyncio
import socket
import websockets
import time
import threading
import tkinter as tk

# Hardcoded list of known face names
known_face_names = ["Alice", "Bob", "Charlie", "Dave"]

last_print_times = {}  # {name: timestamp}
PRINT_COOLDOWN = 10  # 10 seconds cooldown

running = True

def simulate_face_detection(name):
    current_time = time.time()
    last_time = last_print_times.get(name, 0)
    if current_time - last_time >= PRINT_COOLDOWN:
        print(f"Simulated detection of known face: {name}, time = {current_time}")
        last_print_times[name] = current_time
    else:
        # print(f"(Cooldown) {name} recently detected, skipping print.")
        pass

def create_tkinter_ui():
    window = tk.Tk()
    window.title("Simulate Face Detection")

    label = tk.Label(window, text="Click a button to simulate face detection")
    label.pack(pady=10)

    for name in known_face_names + ["Unknown"]:
        btn = tk.Button(window, text=name, width=25, command=lambda n=name: simulate_face_detection(n))
        btn.pack(pady=5)

    window.mainloop()

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
            # In simulation mode, we don't process incoming frames
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
    # Start Tkinter UI in separate thread
    tk_thread = threading.Thread(target=create_tkinter_ui)
    tk_thread.start()

    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        running = False
    finally:
        running = False
        tk_thread.join()
