# ⚡ ESP BLE Provisioning (Flutter)
### Identical to Espressif's Official Android App (`com.espressif.provble`)

This Flutter application reproduces the exact user experience, styling, branding, and Unified Provisioning protocol of Espressif's official **ESP BLE Provisioning** app ([Google Play Store](https://play.google.com/store/apps/details?id=com.espressif.provble)).

---

## 📱 Exact App Pages & Provisioning Workflow

The app is focused exclusively on the official Espressif BLE provisioning workflow:

```
[ ESP Microcontroller ] <========== BLE (Protocomm Protobufs) ==========> [ Mobile App ]
          │                                                                      │
          ├────────── 1. Device Discovery (Prefix Filter: PROV_*) ───────────────┤
          ├────────── 2. Security Handshake (Curve25519 PoP Authentication) ─────┤
          ├────────── 3. Wi-Fi AP Scan (Triggered on ESP Hardware) ──────────────┤
          ├────────── 4. Transmit Network Passphrase (prov-config) ──────────────┤
          ├────────── 5. Apply Config & Connect to Local Wi-Fi Router ───────────┤
          └────────── 6. Query Connection Status & Assigned IPv4 Address ────────┘
```

---

### Step-by-Step UI Screens (Matching `com.espressif.provble`):

1. **Screen 1: BLE Device Discovery (Home)**
   - **Header:** Espressif Red branding (`#E73525`) with chip icon, title *ESP BLE Provisioning*, QR Scanner action, Prefix settings, and Refresh button.
   - **Prefix Filter Banner:** Displays active filter (e.g., `PROV_`) with tap-to-edit modal (leave blank for all BLE devices).
   - **Discovered Device List:** Shows device name (e.g. `PROV_ESP32_IOT`), MAC address, live RSSI dBm signal strength gauge, and *Pair* action button.
   - **QR Code Integration:** Quick modal to scan or paste QR JSON payloads (`{"ver":"v1","name":"PROV_xxx","pop":"abcd1234","transport":"ble"}`) for auto-discovery and auto-pairing.

2. **Screen 2: Security & Proof of Possession (PoP)**
   - Displays target device name and MAC address.
   - **Security Protocol Selector:**
     - **Security 1** (Encrypted with Proof of Possession - default standard).
     - **Security 0** (Open development).
   - **Proof of Possession (PoP) Input:** Secure PIN/password field with visibility eye toggle (default: `abcd1234` matching firmware).
   - Establishes encrypted session over GATT `prov-session` endpoint using Curve25519 key exchange.

3. **Screen 3: Wi-Fi Network Selection**
   - Commands the ESP chip via `prov-scan` to scan physical 2.4 GHz channels.
   - Populates detected SSIDs with:
     - Wi-Fi signal strength gauge (color-coded by dBm).
     - Lock icon for secured (WPA2/WPA3) vs open networks.
   - *Join Other / Hidden Network* button for manual SSID configuration.
   - Re-scan button to refresh nearby networks.

4. **Screen 4: Wi-Fi Credentials**
   - Shows chosen network SSID name with option to switch networks.
   - Password input field with show/hide eye toggle and clear button.
   - *Provision Device* button to securely encode and transmit credentials to the ESP module via `prov-config`.

5. **Screen 5: Provisioning Status & Verification (Official Checklist)**
   - Real-time 4-step sequential checklist with animated indicators:
     1. Establish Session with Device
     2. Send Wi-Fi Credentials
     3. Apply Wi-Fi Configuration
     4. Verify Connection & Get IP Address
   - **Success Outcome:**
     - Large green confirmation badge (*Provisioning Successful!*).
     - Connected SSID summary.
     - Assigned IPv4 address (e.g., `192.168.1.105`).
     - *Done / Provision Another Device* button to cleanly reset.
   - **Failure Outcome:**
     - Red warning badge (*Provisioning Failed*).
     - Clear diagnostic message (e.g., *Authentication failed / Wrong password*, *Network not found*, *Timeout*).
     - *Try Again* button (preserving password for quick correction) and *Back to Device List*.

---

## 🛠️ Arduino / ESP-IDF Firmware Compatibility

A ready-to-flash Arduino sketch using the official ESP32 Arduino Core `WiFiProv.h` is provided in:
`firmware/arduino_ble_provisioning.ino`

- **BLE Service Name:** `PROV_ESP32_IOT`
- **Proof of Possession (PoP):** `abcd1234`
- **Scheme:** `WIFI_PROV_SCHEME_BLE`
- **Security:** `WIFI_PROV_SECURITY_1`
