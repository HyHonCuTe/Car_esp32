#include <WiFi.h>
#include <WebSocketsServer.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// WiFi settings (Access Point)
const char *ssid = "ESP32_Mecanum_Car";
const char *password = "12345678";

// BLE Server settings - Using standard UART UUIDs for better compatibility
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_TX_UUID "6E400002-B5A3-F393-E0A9-E50E24DCCA9E" // Write to this (from phone to ESP32)
#define CHARACTERISTIC_RX_UUID "6E400003-B5A3-F393-E0A9-E50E24DCCA9E" // Read from this (ESP32 to phone)

// Motor pins configuration
#define M2_ENA  32  // Motor 2 PWM (Front Right)
#define M2_IN1  33  // Motor 2 Direction 1
#define M2_IN2  25  // Motor 2 Direction 2

#define M1_ENA  14  // Motor 1 PWM (Front Left)
#define M1_IN1  26  // Motor 1 Direction 1
#define M1_IN2  27  // Motor 1 Direction 2

#define M4_ENA  22  // Motor 4 PWM (Back Right)
#define M4_IN1  16  // Motor 4 Direction 1
#define M4_IN2  17  // Motor 4 Direction 2

#define M3_ENA  23  // Motor 3 PWM (Back Left)
#define M3_IN1  18  // Motor 3 Direction 1
#define M3_IN2  19  // Motor 3 Direction 2

// Function declarations
void controlMotor(int ena, int in1, int in2, int speed);
void moveMecanum(int fl, int fr, int bl, int br);
void stopMotors();
void moveForward(int speed = 200);
void moveBackward(int speed = 200);
void moveSidewaysRight(int speed = 200);
void moveSidewaysLeft(int speed = 200);
void moveDiagonalRight(int speed = 200);
void moveDiagonalLeft(int speed = 200);
void moveDiagonalBackRight(int speed = 200);
void moveDiagonalBackLeft(int speed = 200);
void rotateAroundRightCorner(int speed = 200);
void rotateAroundLeftCorner(int speed = 200);
void rotateInPlaceCounterClockwise(int speed = 200);
void rotateInPlaceClockwise(int speed = 200);
void processCommand(const char* cmd);

// Communication servers
WebSocketsServer webSocket = WebSocketsServer(81);
BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic = NULL;
BLECharacteristic *pRxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
uint8_t bleConnectRetry = 0;

// Status tracking variables
unsigned long lastStatusUpdate = 0;
const unsigned long STATUS_UPDATE_INTERVAL = 2000; // 2 seconds
int currentSpeed = 0;
String currentCommand = "STOP";

// Server callbacks with improved connection handling
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      bleConnectRetry = 0;
      Serial.println("BLE Client connected");
      
      // Send a welcome message via the RX characteristic (to phone)
      pRxCharacteristic->setValue("ESP32_Mecanum_Car connected");
      pRxCharacteristic->notify();
    }

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("BLE Client disconnected");
      processCommand("STOP:0");
      
      // Start advertising again to allow reconnection
      if (bleConnectRetry < 3) {
        Serial.println("Restarting BLE advertising");
        delay(500);
        pServer->startAdvertising();
        bleConnectRetry++;
      }
    }
};

// Characteristic callbacks with improved error handling
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      try {
        uint8_t* data = pCharacteristic->getData();
        size_t length = pCharacteristic->getLength();
        
        if (length > 0) {
          char tempBuffer[100];
          size_t copyLength = length < 99 ? length : 99;
          memcpy(tempBuffer, data, copyLength);
          tempBuffer[copyLength] = '\0';
          
          Serial.print("BLE Received: ");
          Serial.println(tempBuffer);
          
          processCommand(tempBuffer);
          
          // Echo back confirmation through RX characteristic
          String confirmation = "OK:" + String(tempBuffer);
          pRxCharacteristic->setValue(confirmation.c_str());
          pRxCharacteristic->notify();
        }
      } catch (std::exception &e) {
        Serial.print("BLE write error: ");
        Serial.println(e.what());
      }
    }
};

// Parse command string with speed information
// Format: COMMAND:SPEED (e.g., "FORWARD:200")
void processCommand(const char* cmdString) {
  char cmdBuffer[50];
  strncpy(cmdBuffer, cmdString, sizeof(cmdBuffer) - 1);
  cmdBuffer[sizeof(cmdBuffer) - 1] = '\0';
  
  // Find delimiter
  char* speedStr = strchr(cmdBuffer, ':');
  int speed = 200; // Default speed
  
  if (speedStr) {
    *speedStr = '\0'; // Null-terminate command portion
    speedStr++; // Point to speed portion
    speed = atoi(speedStr); // Convert speed to integer
  }
  
  // Extract command (now null-terminated)
  const char* cmd = cmdBuffer;
  
  Serial.printf("Command: %s, Speed: %d\n", cmd, speed);
  currentCommand = String(cmd);
  currentSpeed = speed;
  
  // Process the command with extracted speed
  if (strcmp(cmd, "FORWARD") == 0) moveForward(speed);
  else if (strcmp(cmd, "BACKWARD") == 0) moveBackward(speed);
  else if (strcmp(cmd, "SIDEWAYS_RIGHT") == 0) moveSidewaysRight(speed);
  else if (strcmp(cmd, "SIDEWAYS_LEFT") == 0) moveSidewaysLeft(speed);
  else if (strcmp(cmd, "DIAGONAL_RIGHT") == 0) moveDiagonalRight(speed);
  else if (strcmp(cmd, "DIAGONAL_LEFT") == 0) moveDiagonalLeft(speed);
  else if (strcmp(cmd, "DIAGONAL_BACK_RIGHT") == 0) moveDiagonalBackRight(speed);
  else if (strcmp(cmd, "DIAGONAL_BACK_LEFT") == 0) moveDiagonalBackLeft(speed);
  else if (strcmp(cmd, "ROTATE_LEFT_CORNER") == 0) rotateAroundLeftCorner(speed);
  else if (strcmp(cmd, "ROTATE_RIGHT_CORNER") == 0) rotateAroundRightCorner(speed);
  else if (strcmp(cmd, "ROTATE_CENTER_CCW") == 0) rotateInPlaceCounterClockwise(speed);
  else if (strcmp(cmd, "ROTATE_CENTER_CW") == 0) rotateInPlaceClockwise(speed);
  else if (strcmp(cmd, "STOP") == 0) stopMotors();
  else stopMotors(); // Stop for unrecognized commands
}

void setupWiFi() {
  WiFi.softAP(ssid, password);
  Serial.print("WiFi AP: ");
  Serial.println(ssid);
  Serial.print("IP: ");
  Serial.println(WiFi.softAPIP());
}

void setupBLE() {
  // Initialize BLE
  BLEDevice::init("ESP32_Mecanum_Car");
  
  // Set transmit power to maximum for better connection range
  esp_ble_tx_power_set(ESP_BLE_PWR_TYPE_DEFAULT, ESP_PWR_LVL_P9);
  esp_ble_tx_power_set(ESP_BLE_PWR_TYPE_ADV, ESP_PWR_LVL_P9);
  esp_ble_tx_power_set(ESP_BLE_PWR_TYPE_SCAN, ESP_PWR_LVL_P9);
  
  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  // Create the BLE Service with proper UUID
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Create BLE Characteristics with proper permissions
  pTxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_TX_UUID,
                        BLECharacteristic::PROPERTY_WRITE |
                        BLECharacteristic::PROPERTY_WRITE_NR
                      );
  
  pRxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_RX_UUID,
                        BLECharacteristic::PROPERTY_NOTIFY
                      );
  
  // Add a descriptor to the characteristic
  pRxCharacteristic->addDescriptor(new BLE2902());
  
  // Set callback for the TX characteristic
  pTxCharacteristic->setCallbacks(new MyCallbacks());
  
  // Start the service
  pService->start();
  
  // Setup advertising with appropriate data
  BLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMaxPreferred(0x12);
  
  // Start advertising
  pAdvertising->start();
  
  Serial.println("BLE server ready and advertising");
}

void webSocketEvent(uint8_t num, WStype_t type, uint8_t *payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED:
      Serial.printf("[WebSocket %u] Connected!\n", num);
      break;
    case WStype_DISCONNECTED:
      Serial.printf("[WebSocket %u] Disconnected! Stopping motors...\n", num);
      processCommand("STOP:0");
      break;
    case WStype_TEXT: {
      char cmd[length + 1];
      memcpy(cmd, payload, length);
      cmd[length] = '\0';
      Serial.printf("WebSocket command: %s\n", cmd);
      processCommand(cmd);
      break;
    }
    default:
      break;
  }
}

// Motor control functions using standard analogWrite
void controlMotor(int ena, int in1, int in2, int speed) {
  speed = constrain(speed, -255, 255);
  if (speed > 0) {
    digitalWrite(in1, HIGH);
    digitalWrite(in2, LOW);
  } else if (speed < 0) {
    digitalWrite(in1, LOW);
    digitalWrite(in2, HIGH);
  } else {
    digitalWrite(in1, LOW);
    digitalWrite(in2, LOW);
  }
  // Use standard analogWrite for PWM
  analogWrite(ena, abs(speed));
}

void moveMecanum(int fl, int fr, int bl, int br) {
  Serial.printf("Moving: FL=%d, FR=%d, BL=%d, BR=%d\n", fl, fr, bl, br);
  controlMotor(M1_ENA, M1_IN1, M1_IN2, fl); // Front Left
  controlMotor(M2_ENA, M2_IN1, M2_IN2, fr); // Front Right
  controlMotor(M3_ENA, M3_IN1, M3_IN2, bl); // Back Left
  controlMotor(M4_ENA, M4_IN1, M4_IN2, br); // Back Right
}

// All movement functions
void stopMotors() {
  moveMecanum(0, 0, 0, 0);
}

void moveForward(int speed) { 
  moveMecanum(speed, speed, speed, speed);
}

void moveBackward(int speed) { 
  moveMecanum(-speed, -speed, -speed, -speed); 
}

void moveSidewaysRight(int speed) { 
  moveMecanum(speed, -speed, speed, -speed);
}

void moveSidewaysLeft(int speed) { 
  moveMecanum(-speed, speed, -speed, speed);
}

void moveDiagonalLeft(int speed) { 
  moveMecanum(0, speed, 0, speed); 
}

void moveDiagonalRight(int speed) { 
  moveMecanum(speed, 0, speed, 0); 
}

void moveDiagonalBackLeft(int speed) { 
  moveMecanum(-speed, 0, -speed, 0); 
}

void moveDiagonalBackRight(int speed) { 
  moveMecanum(0, -speed, 0, -speed); 
}

void rotateAroundRightCorner(int speed) { 
  moveMecanum(speed, 0, 0, speed);
}

void rotateAroundLeftCorner(int speed) { 
  moveMecanum(0, speed, speed, 0);
}

void rotateInPlaceCounterClockwise(int speed) { 
  moveMecanum(-speed, speed, speed, -speed);
}

void rotateInPlaceClockwise(int speed) { 
  moveMecanum(speed, -speed, -speed, speed);
}

void setup() {
  Serial.begin(115200);
  
  // Initialize motor control pins
  pinMode(M1_ENA, OUTPUT);
  pinMode(M1_IN1, OUTPUT); pinMode(M1_IN2, OUTPUT);
  pinMode(M2_ENA, OUTPUT);
  pinMode(M2_IN1, OUTPUT); pinMode(M2_IN2, OUTPUT);
  pinMode(M3_ENA, OUTPUT);
  pinMode(M3_IN1, OUTPUT); pinMode(M3_IN2, OUTPUT);
  pinMode(M4_ENA, OUTPUT);
  pinMode(M4_IN1, OUTPUT); pinMode(M4_IN2, OUTPUT);

  // Initialize motors to stopped state
  stopMotors();

  // Start WiFi
  setupWiFi();
  
  // Start BLE with improved implementation
  setupBLE();
  
  // Start WebSocket server
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);
  
  Serial.println("ESP32 Mecanum Car Ready - Standard PWM Mode");
}

void sendStatusUpdate() {
  if (deviceConnected && pRxCharacteristic != nullptr) {  // Fixed: using nullptr instead of null
    // Format: STATUS:command:speed
    String status = "STATUS:" + currentCommand + ":" + String(currentSpeed);
    pRxCharacteristic->setValue(status.c_str());
    pRxCharacteristic->notify();
  }
}

void loop() {
  // Handle WebSocket events
  webSocket.loop();
  
  // Handle BLE connection state changes
  if (deviceConnected != oldDeviceConnected) {
    if (deviceConnected) {
      // Connected - send welcome message
      Serial.println("BLE Connected - sending welcome message");
      delay(100); // Short delay to ensure connection is stable
      sendStatusUpdate();
    }
    oldDeviceConnected = deviceConnected;
  }
  
  // Send periodic status updates to connected clients
  unsigned long currentTime = millis();
  if (currentTime - lastStatusUpdate > STATUS_UPDATE_INTERVAL) {
    lastStatusUpdate = currentTime;
    sendStatusUpdate();
  }
  
  // Check if BLE needs to be restarted (if connection attempts failed)
  if (bleConnectRetry >= 3 && !deviceConnected) {
    Serial.println("Restarting BLE due to connection issues");
    bleConnectRetry = 0;
    
    // Restart BLE completely
    BLEDevice::deinit(true);
    delay(500);
    setupBLE();
  }
}