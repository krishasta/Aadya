/*
  =============================================================================
  ESP32 BLE IoT Firmware - Nordic UART Service (NUS)
  Designed for Flutter ESP32 BLE Controller App
  =============================================================================
  Features:
  - BLE Low Energy Serial communication using Nordic UART Service (NUS)
  - Bi-directional Command Processing (LED, Relays, PWM, Ping, Reboot)
  - Automatic Telemetry Streaming (Temperature, Humidity, Voltage)
  - Plug-and-play with the Flutter application
  =============================================================================
*/

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Standard Nordic UART Service (NUS) UUIDs
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E" // App writes into ESP32
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E" // ESP32 notifies App

#define DEVICE_NAME "ESP32_IoT_Device"

// Hardware Pin Assignments
#define LED_PIN 2       // Onboard LED
#define RELAY1_PIN 18   // Relay Channel 1
#define RELAY2_PIN 19   // Relay Channel 2
#define RELAY3_PIN 21   // Relay Channel 3
#define RELAY4_PIN 22   // Relay Channel 4
#define PWM_PIN    23   // PWM Output (LED / Motor / Servo)

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
unsigned long lastTelemetryTime = 0;

// BLE Server Callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("[BLE] Client device connected!");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("[BLE] Client device disconnected.");
    }
};

// Transmit serial response back to Flutter App
void sendBleResponse(String message) {
  if (deviceConnected && pTxCharacteristic != NULL) {
    message += "\r\n";
    pTxCharacteristic->setValue((uint8_t*)message.c_str(), message.length());
    pTxCharacteristic->notify();
    Serial.print("[BLE TX] ");
    Serial.print(message);
  }
}

// Characteristic Write Callback (Handles incoming commands from App)
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue();

      if (rxValue.length() > 0) {
        rxValue.trim(); // Remove whitespace and line breaks
        Serial.print("[BLE RX] ");
        Serial.println(rxValue);

        // Command: LED:1 or LED:0
        if (rxValue.startsWith("LED:1")) {
          digitalWrite(LED_PIN, HIGH);
          sendBleResponse("OK: LED IS ON");
        } 
        else if (rxValue.startsWith("LED:0")) {
          digitalWrite(LED_PIN, LOW);
          sendBleResponse("OK: LED IS OFF");
        }
        // Command: RELAY:<channel>:<state> (e.g. RELAY:1:1)
        else if (rxValue.startsWith("RELAY:")) {
          int firstColon = rxValue.indexOf(':');
          int secondColon = rxValue.indexOf(':', firstColon + 1);
          if (secondColon != -1) {
            int relayNum = rxValue.substring(firstColon + 1, secondColon).toInt();
            int state = rxValue.substring(secondColon + 1).toInt();
            int targetPin = (relayNum == 1) ? RELAY1_PIN :
                            (relayNum == 2) ? RELAY2_PIN :
                            (relayNum == 3) ? RELAY3_PIN : RELAY4_PIN;
            digitalWrite(targetPin, state ? HIGH : LOW);
            sendBleResponse("OK: RELAY " + String(relayNum) + (state ? " ON" : " OFF"));
          }
        }
        // Command: PWM:<value> (0-255)
        else if (rxValue.startsWith("PWM:")) {
          int val = rxValue.substring(4).toInt();
          ledcWrite(0, constrain(val, 0, 255));
          sendBleResponse("OK: PWM SET TO " + String(val));
        }
        // Command: PING
        else if (rxValue.equalsIgnoreCase("PING")) {
          sendBleResponse("PONG");
        }
        // Command: STATUS
        else if (rxValue.equalsIgnoreCase("STATUS")) {
          String status = "STATUS: UPTIME=" + String(millis() / 1000) + "s, LED=" + String(digitalRead(LED_PIN));
          sendBleResponse(status);
        }
        // Command: REBOOT
        else if (rxValue.equalsIgnoreCase("REBOOT")) {
          sendBleResponse("SYSTEM RESTARTING...");
          delay(500);
          ESP.restart();
        }
        else {
          // Echo back generic command
          sendBleResponse("ECHO: " + rxValue);
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  Serial.println("\n--- ESP32 BLE IoT Initializing ---");

  // Initialize GPIO pins
  pinMode(LED_PIN, OUTPUT);
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);
  pinMode(RELAY3_PIN, OUTPUT);
  pinMode(RELAY4_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Initialize PWM channel 0 at 5 kHz, 8-bit resolution
  ledcAttach(PWM_PIN, 5000, 8);
  ledcWrite(0, 0);

  // Initialize BLE Device
  BLEDevice::init(DEVICE_NAME);

  // Create BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create Nordic UART Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create TX Characteristic (Notify to App)
  pTxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID_TX,
                        BLECharacteristic::PROPERTY_NOTIFY
                      );
  pTxCharacteristic->addDescriptor(new BLE2902());

  // Create RX Characteristic (Write from App)
  BLECharacteristic *pRxCharacteristic = pService->createCharacteristic(
                                           CHARACTERISTIC_UUID_RX,
                                           BLECharacteristic::PROPERTY_WRITE |
                                           BLECharacteristic::PROPERTY_WRITE_NR
                                         );
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  // Start BLE Service
  pService->start();

  // Start Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("BLE Ready! Advertising as: " DEVICE_NAME);
}

void loop() {
  // Handle disconnection & restart advertising
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("[BLE] Restarted advertising");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  // Periodic Telemetry Stream (Every 2 seconds)
  if (deviceConnected && (millis() - lastTelemetryTime > 2000)) {
    lastTelemetryTime = millis();

    // Generate sensor data (replace with actual analogRead or DHT sensor)
    float temp = 24.5 + (random(-15, 15) / 10.0);
    float hum = 58.0 + (random(-30, 30) / 10.0);
    float volt = 3.28 + (random(-5, 5) / 100.0);

    // Stream key-value format automatically parsed by the Flutter app
    String telemetry = "TEMP:" + String(temp, 1) + " HUM:" + String(hum, 1) + " VOLT:" + String(volt, 2);
    sendBleResponse(telemetry);
  }

  delay(20);
}
