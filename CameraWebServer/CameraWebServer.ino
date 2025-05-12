#include "esp_camera.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoWebsockets.h>
#include "config.h"

// WiFi credentials
const char* ssid = WIFI_SSID; // your wifi name from the config header file
const char* password = WIFI_PASSWORD; // password of your wifi from the config header file

const char* garudID = "V2ur6DpdX9BCA5KS2NH6"; // garudID for rakiulmalda96@gmail.com

// TODO: Implement loading WiFi data from a file on the SD card

// WebSocket server details
const char* websocket_server_host = "192.168.151.131"; // ip of the running python backend server
const int websocket_server_port = 8888;

// Camera configuration
#define CAMERA_MODEL_AI_THINKER
#include "camera_pins.h"

using namespace websockets;
WebsocketsClient client;
bool connected = false;

// Frame rate control
unsigned long previousFrameTime = 0;
const int frameInterval = 100; // 10 FPS (adjust as needed)

void setup() {
  Serial.begin(115200);
  Serial.println("\nESP32-CAM WebSocket Client");

  // Camera config
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 15000000;  // Set XCLK to 15 MHz
  config.pixel_format = PIXFORMAT_JPEG;

  if(psramFound()){
    config.frame_size = FRAMESIZE_VGA;  // Set resolution to 800x600
    config.jpeg_quality = 10; // 0-63 lower means higher quality
    config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_VGA;  // Set resolution to 800x600
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }

  // Initialize camera
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }

  // Optimize camera settings
  sensor_t * s = esp_camera_sensor_get();
  s->set_framesize(s, FRAMESIZE_VGA);  // Set resolution to 800x600
  s->set_quality(s, 10);
  s->set_gainceiling(s, GAINCEILING_32X);  // Set gain ceiling to 32x

  // WiFi connection
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi...");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // WebSocket event handlers
  client.onMessage([&](WebsocketsMessage message) {
    // Handle incoming messages if needed
    Serial.println("Got Message: " + message.data());
  });

  // Connect to WebSocket server
  connectToWebSocket();
}


void connectToWebSocket() {
  String websocket_url = "ws://" + String(websocket_server_host) + ":" + String(websocket_server_port) + "/ws";
  Serial.print("Connecting to WebSocket server: ");
  Serial.println(websocket_url);
  
  connected = client.connect(websocket_url);
  
  if(connected) {
    Serial.println("Connected to WebSocket server!");
    // Send a hello message
    client.send(garudID);
  } else {
    Serial.println("Failed to connect to WebSocket server!");
  }
}

void loop() {
  // Check if connection is still alive
  if(client.available()) {
    client.poll();
  } else if(connected) {
    Serial.println("WebSocket disconnected!");
    connected = false;
    delay(1000);
    connectToWebSocket();
    return;
  }
  
  // If not connected, try reconnecting
  if(!connected) {
    Serial.println("Trying to reconnect...");
    connectToWebSocket();
    delay(1000);
    return;
  }

  // Maintain WiFi connection
  if(WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected! Reconnecting...");
    WiFi.reconnect();
    delay(5000);
    return;
  }
  
  // Control frame rate
  unsigned long currentTime = millis();
  if(currentTime - previousFrameTime < frameInterval) {
    return;
  }
  previousFrameTime = currentTime;
  
  // Capture frame
  camera_fb_t *fb = esp_camera_fb_get();
  if(!fb) {
    Serial.println("Camera capture failed");
    delay(1000);
    return;
  }
  
  // Send the frame via WebSocket if connected
  if(connected && client.available()) {
    Serial.printf("Sending %u bytes\n", fb->len);
    client.sendBinary((const char*)fb->buf, fb->len);
  }
  
  // Return frame buffer to be reused
  esp_camera_fb_return(fb);
}