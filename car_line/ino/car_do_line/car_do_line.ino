#include <ESP8266WiFi.h>
#include <SoftwareSerial.h>

// Software serial for external BLE module
SoftwareSerial bleSerial(4, 5); // RX, TX

const int MAX_NETWORKS = 10;
unsigned long lastScanTime = 0;
const unsigned long SCAN_INTERVAL = 10000; // 10 seconds

void setup() {
  Serial.begin(115200);
  bleSerial.begin(9600);
  
  Serial.println("\n\nESP8266 WiFi & Bluetooth Network Monitor");
  Serial.println("For educational purposes in laboratory environments only");
  
  // Set WiFi to station mode
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
}

void loop() {
  // Perform WiFi scan periodically
  if (millis() - lastScanTime > SCAN_INTERVAL) {
    scanWiFiNetworks();
    checkBluetoothDevices();
    lastScanTime = millis();
  }
  
  // Process any commands from serial
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    processCommand(command);
  }
  
  // Check for BLE module responses
  while (bleSerial.available()) {
    Serial.write(bleSerial.read());
  }
}

void scanWiFiNetworks() {
  Serial.println("\n------ WiFi Networks ------");
  
  int n = WiFi.scanNetworks();
  
  if (n == 0) {
    Serial.println("No networks found");
  } else {
    Serial.printf("Found %d networks:\n", n);
    
    for (int i = 0; i < min(n, MAX_NETWORKS); ++i) {
      // Print details for each network
      Serial.printf("%2d: %-32s | Ch: %2d | %4d dBm | %s\n", 
                    i + 1, 
                    WiFi.SSID(i).c_str(), 
                    WiFi.channel(i),
                    WiFi.RSSI(i),
                    (WiFi.encryptionType(i) == ENC_TYPE_NONE) ? "Open" : "Secured");
    }
  }
}

void checkBluetoothDevices() {
  Serial.println("\n------ Bluetooth Scan ------");
  // Send scan command to BLE module
  bleSerial.println("AT+SCAN");
}

void processCommand(String command) {
  if (command.startsWith("WIFI_SCAN")) {
    scanWiFiNetworks();
  } 
  else if (command.startsWith("BT_SCAN")) {
    checkBluetoothDevices();
  }
  else if (command.startsWith("HELP")) {
    Serial.println("\nAvailable commands:");
    Serial.println("WIFI_SCAN - Scan for WiFi networks");
    Serial.println("BT_SCAN - Scan for Bluetooth devices");
    Serial.println("HELP - Show this help message");
  }
}