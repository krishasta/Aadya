/*
  =============================================================================
  Arduino ESP32 BLE Wi-Fi Provisioning Sketch
  Compatible with com.espressif.provble and this Flutter App
  =============================================================================
  Uses official ESP32 Arduino Core "WiFiProv.h"
  Board: ESP32 Dev Module, ESP32-S3, ESP32-C3
  =============================================================================
*/

#include "WiFiProv.h"
#include "WiFi.h"

// Proof of Possession (Password entered in the App)
const char *pop = "abcd1234";

// Service name prefix advertised by BLE
const char *service_name = "PROV_ESP32_IOT";

// Callback when Wi-Fi Provisioning events occur
void SysProvEvent(arduino_event_t *sys_event) {
    switch (sys_event->event_id) {
        case ARDUINO_EVENT_WIFI_STA_GOT_IP:
            Serial.print("\n[PROV] Connected! IPv4 Address: ");
            Serial.println(IPAddress(sys_event->event_info.got_ip.ip_info.ip.addr));
            break;
        case ARDUINO_EVENT_WIFI_PROV_START:
            Serial.println("\n[PROV] BLE Provisioning started");
            break;
        case ARDUINO_EVENT_WIFI_PROV_CRED_RECV:
            Serial.println("[PROV] Wi-Fi credentials received from Flutter App");
            break;
        case ARDUINO_EVENT_WIFI_PROV_CRED_FAIL:
            Serial.println("[PROV] Wi-Fi credentials failed! Check password.");
            break;
        case ARDUINO_EVENT_WIFI_PROV_CRED_SUCCESS:
            Serial.println("[PROV] Wi-Fi credentials successfully applied!");
            break;
        case ARDUINO_EVENT_WIFI_PROV_END:
            Serial.println("[PROV] Provisioning session ended.");
            break;
        default:
            break;
    }
}

void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n--- ESP32 Arduino BLE Provisioning ---");

    WiFi.onEvent(SysProvEvent);

    // Initialize BLE Provisioning with Security 1 (PoP)
    // WiFiProv.beginProvision(scheme, security, pop, service_name, service_key);
    WiFiProv.beginProvision(WIFI_PROV_SCHEME_BLE, WIFI_PROV_SECURITY_1, pop, service_name);

    Serial.print("BLE Advertising as: ");
    Serial.println(service_name);
    Serial.print("Proof of Possession (PoP): ");
    Serial.println(pop);
}

void loop() {
    // Normal operational code runs once provisioned
    if (WiFi.status() == WL_CONNECTED) {
        // Blink LED or run IoT sensors
    }
    delay(1000);
}
