import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class Esp32FirmwareTab extends StatelessWidget {
  const Esp32FirmwareTab({super.key});

  static const String esp32ArduinoCode = '''
/*
  ESP32 BLE Serial & IoT Controller Firmware
  Compatible with standard Nordic UART Service (NUS)
  Works out-of-the-box with this Flutter App!
*/

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Standard Nordic UART Service UUIDs
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E" // Write into ESP32
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E" // Notify to Flutter App

#define DEVICE_NAME "ESP32_IoT_Device"

// Hardware Pin Definitions
#define LED_PIN 2       // Onboard LED on most ESP32 boards
#define RELAY1_PIN 18
#define RELAY2_PIN 19
#define RELAY3_PIN 21
#define RELAY4_PIN 22
#define PWM_PIN    23   // PWM / Motor / LED Brightness pin

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
unsigned long lastTelemetryTime = 0;

// Server Connection Callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("[BLE] Client connected!");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("[BLE] Client disconnected.");
    }
};

// Send text response to Flutter App
void sendBleResponse(String message) {
  if (deviceConnected && pTxCharacteristic != NULL) {
    message += "\\r\\n";
    pTxCharacteristic->setValue((uint8_t*)message.c_str(), message.length());
    pTxCharacteristic->notify();
    Serial.print("[BLE TX] ");
    Serial.print(message);
  }
}

// Characteristic Write Callback (Incoming commands from Flutter App)
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue();

      if (rxValue.length() > 0) {
        // Strip carriage return and newline
        rxValue.trim();
        Serial.print("[BLE RX] Received command: ");
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
        // Command: RELAY:1:1 or RELAY:1:0
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
  Serial.println("Starting ESP32 BLE IoT Firmware...");

  // Configure GPIO Pins
  pinMode(LED_PIN, OUTPUT);
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);
  pinMode(RELAY3_PIN, OUTPUT);
  pinMode(RELAY4_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Configure PWM (Timer channel 0, 5000Hz, 8-bit resolution)
  ledcAttach(PWM_PIN, 5000, 8);
  ledcWrite(0, 0);

  // Initialize BLE
  BLEDevice::init(DEVICE_NAME);

  // Create BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create Nordic UART Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create TX Characteristic (For Notify)
  pTxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID_TX,
                        BLECharacteristic::PROPERTY_NOTIFY
                      );
  pTxCharacteristic->addDescriptor(new BLE2902());

  // Create RX Characteristic (For Write)
  BLECharacteristic *pRxCharacteristic = pService->createCharacteristic(
                                           CHARACTERISTIC_UUID_RX,
                                           BLECharacteristic::PROPERTY_WRITE |
                                           BLECharacteristic::PROPERTY_WRITE_NR
                                         );
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  // Start Service
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
  // Restart advertising if disconnected
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

    // Read simulated or actual sensors (e.g. analogRead(34) or DHT22)
    float temp = 24.5 + (random(-15, 15) / 10.0);
    float hum = 58.0 + (random(-30, 30) / 10.0);
    float volt = 3.28 + (random(-5, 5) / 100.0);

    // Stream formatted telemetry: KEY:VALUE
    String telemetry = "TEMP:" + String(temp, 1) + " HUM:" + String(hum, 1) + " VOLT:" + String(volt, 2);
    sendBleResponse(telemetry);
  }

  delay(20);
}
''';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.memory_rounded, color: AppTheme.accentGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SOLink Arduino Firmware Code',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Ready-to-flash Nordic UART Service (NUS) C++ Sketch',
                              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'This complete firmware enables bidirectional BLE serial, handles LED/Relay commands, and streams live telemetry (temperature, humidity, voltage) directly to this app.',
                    style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Arduino C++ Code to Clipboard'),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: esp32ArduinoCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SOLink Firmware Code copied to clipboard!'),
                          backgroundColor: AppTheme.surfaceLight,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Steps Guide
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to Flash onto Your SOLink Module',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildStep(1, 'Open Arduino IDE (v2.x recommended).'),
                  _buildStep(2, 'Install the Board Package via Boards Manager: "esp32 by Espressif Systems".'),
                  _buildStep(3, 'Select your Dev Module board and USB COM port.'),
                  _buildStep(4, 'Paste this code into a new sketch and click Upload.'),
                  _buildStep(5, 'Open this app, tap Scan, and connect to "SOLink_IoT_Device"!'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Code Preview
          Text(
            'Source Code Preview',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.consoleBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Text(
              esp32ArduinoCode,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppTheme.textPrimary.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.cardBorder,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryCyan),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
