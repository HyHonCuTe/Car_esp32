#include <ESP8266WiFi.h>
#include <WebSocketsServer.h>
#include <Servo.h>

// WiFi AP Configuration
const char* ssid = "ESP8266_CAR";
const char* password = "12345678";

// WebSocket Server
WebSocketsServer webSocket = WebSocketsServer(81);

// Motor Pins
const int ENA = D5;
const int IN1 = D6;
const int IN2 = D7;

// Steering Servo
Servo servoBanhLai;
const int servoPin = D4;

// Servo Control Variables - Adjusted for limited pulse range
const int centerPosition = 110;  // Center position
const int leftTurnAngle = 125;   // Maximum left angle (limited by pulse)
const int rightTurnAngle = 95;   // Minimum right angle (limited by pulse)
const int tocDo = 180;           // Motor PWM (0-255)

void setup() {
    Serial.begin(115200);
    
    Serial.println("\n\n=== ESP8266 Car Controller ===");
    Serial.println("User: HiepvHo");
    Serial.println("Last updated: 2025-04-03 08:50:40");
    
    // Setup WiFi AP
    WiFi.softAP(ssid, password);
    Serial.print("WiFi AP: ");
    Serial.println(WiFi.softAPIP());

    // Initialize motor
    pinMode(ENA, OUTPUT);
    pinMode(IN1, OUTPUT);
    pinMode(IN2, OUTPUT);
    digitalWrite(IN1, LOW);
    digitalWrite(IN2, LOW);
    analogWrite(ENA, tocDo);

    // Initialize servo to center position
    servoBanhLai.attach(servoPin,500,2500);
    servoBanhLai.write(centerPosition);
    Serial.println("Servo initialized to center position: " + String(centerPosition));

    // Start WebSocket Server
    webSocket.begin();
    webSocket.onEvent(webSocketEvent);
    
    Serial.println("System Ready");
}

void loop() {
    webSocket.loop();
}

// WebSocket Event Handler
void webSocketEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
    if (type == WStype_TEXT) {
        String data = String((char*)payload);
        Serial.println("Received: " + data);

        if (data == "FORWARD") {
            digitalWrite(IN1, HIGH);
            digitalWrite(IN2, LOW);
        } 
        else if (data == "BACKWARD") {
            digitalWrite(IN1, LOW);
            digitalWrite(IN2, HIGH);
        } 
        else if (data == "STOP") {
            digitalWrite(IN1, LOW);
            digitalWrite(IN2, LOW);
        } 
        else if (data == "LEFT") {
            servoBanhLai.write(leftTurnAngle);
            Serial.println("Turning left: " + String(leftTurnAngle));
        } 
        else if (data == "RIGHT") {
            servoBanhLai.write(rightTurnAngle);
            Serial.println("Turning right: " + String(rightTurnAngle));
        } 
        else if (data == "CENTER") {
            servoBanhLai.write(centerPosition);
            Serial.println("Centering: " + String(centerPosition));
        }

        webSocket.sendTXT(num, "OK");
    }
}