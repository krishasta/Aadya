/*
  =============================================================================
  ESP-IDF BLE Wi-Fi Provisioning Firmware
  Compatible with com.espressif.provble and this Flutter App
  =============================================================================
  Target: ESP32 / ESP32-S2 / ESP32-S3 / ESP32-C3
  Framework: ESP-IDF (v4.4+, v5.x)
  Transport: BLE (wifi_prov_scheme_ble)
  Security: Security 1 (Curve25519 PoP) or Security 0
  =============================================================================
*/

#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "nvs_flash.h"

// Unified Provisioning Components
#include <wifi_provisioning/manager.h>
#include <wifi_provisioning/scheme_ble.h>

static const char *TAG = "app_prov";

// Event handler for Wi-Fi and Provisioning events
static void app_prov_event_handler(void* arg, esp_event_base_t event_base,
                                   int32_t event_id, void* event_data) {
    if (event_base == WIFI_PROV_EVENT) {
        switch (event_id) {
            case WIFI_PROV_START:
                ESP_LOGI(TAG, "Provisioning started");
                break;
            case WIFI_PROV_CRED_RECV: {
                wifi_sta_config_t *wifi_sta_cfg = (wifi_sta_config_t *)event_data;
                ESP_LOGI(TAG, "Received Wi-Fi credentials -> SSID: %s", (const char *)wifi_sta_cfg->ssid);
                break;
            }
            case WIFI_PROV_CRED_FAIL: {
                wifi_prov_sta_fail_reason_t *reason = (wifi_prov_sta_fail_reason_t *)event_data;
                ESP_LOGE(TAG, "Provisioning failed! Reason: %s",
                         (*reason == WIFI_PROV_STA_AUTH_ERROR) ? "Auth Error (Incorrect Password)" : "AP Not Found");
                break;
            }
            case WIFI_PROV_CRED_SUCCESS:
                ESP_LOGI(TAG, "Provisioning successful! Wi-Fi connection established.");
                break;
            case WIFI_PROV_END:
                // De-initialize manager once provisioned
                wifi_prov_mgr_deinit();
                break;
            default:
                break;
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "Connected! IPv4: " IPSTR, IP2STR(&event->ip_info.ip));
    }
}

void app_main(void) {
    // 1. Initialize NVS Flash
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    // 2. Initialize TCP/IP stack & event loop
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    // Register event handlers
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_PROV_EVENT, ESP_EVENT_ANY_ID, &app_prov_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &app_prov_event_handler, NULL));

    esp_netif_create_default_wifi_sta();
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    // 3. Configure Provisioning Manager for BLE
    wifi_prov_mgr_config_t prov_config = {
        .scheme = wifi_prov_scheme_ble,
        .scheme_event_handler = WIFI_PROV_SCHEME_BLE_EVENT_HANDLER_FREE_BTDM
    };
    ESP_ERROR_CHECK(wifi_prov_mgr_init(prov_config));

    // 4. Check if device is already provisioned
    bool provisioned = false;
    ESP_ERROR_CHECK(wifi_prov_mgr_is_provisioned(&provisioned));

    if (!provisioned) {
        ESP_LOGI(TAG, "Device not provisioned. Starting BLE Provisioning Service...");

        // Device name advertised over BLE (prefix: PROV_)
        char service_name[] = "PROV_ESP32_IOT";

        // Security 1: Requires Proof of Possession (PoP)
        wifi_prov_security_t security = WIFI_PROV_SECURITY_1;
        const char *pop = "abcd1234"; // Enter this PoP in the Flutter app

        // Start BLE Provisioning Advertising & GATT Service
        ESP_ERROR_CHECK(wifi_prov_mgr_start_provisioning(security, pop, service_name, NULL));
        ESP_LOGI(TAG, "BLE Provisioning advertising as: %s (PoP: %s)", service_name, pop);
    } else {
        ESP_LOGI(TAG, "Device already provisioned! Connecting to Wi-Fi station...");
        wifi_prov_mgr_deinit();
        ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
        ESP_ERROR_CHECK(esp_wifi_start());
    }
}
