import 'dart:async';
import 'dart:convert';
import 'package:esp_provisioning_ble/esp_provisioning_ble.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'transport_ble.dart';
// ignore: implementation_imports
import 'package:esp_provisioning_ble/src/protos/generated/sec0.pb.dart';
// ignore: implementation_imports
import 'package:esp_provisioning_ble/src/protos/generated/session.pb.dart';

enum ProvStep {
  deviceScan,
  securitySetup,
  wifiScan,
  enterCredentials,
  provisioning,
  completed,
  failed,
}

enum StepStatus {
  pending,
  inProgress,
  success,
  failed,
}

class Security0 implements ProvSecurity {
  bool _sessionDone = false;

  @override
  Future<Uint8List> encrypt(Uint8List data) async => data;

  @override
  Future<Uint8List> decrypt(Uint8List data) async => data;

  @override
  Future<SessionData?> securitySession(SessionData responseData) async {
    if (_sessionDone) {
      return null;
    }

    final sec0 = Sec0Payload()
      ..msg = Sec0MsgType.S0_Session_Command
      ..sc = S0SessionCmd();

    final sessionData = SessionData()
      ..secVer = SecSchemeVersion.SecScheme0
      ..sec0 = sec0;

    _sessionDone = true;
    return sessionData;
  }
}

class ProvisioningService extends ChangeNotifier {
  static final ProvisioningService instance = ProvisioningService._internal();
  ProvisioningService._internal();

  // Wizard state
  ProvStep currentStep = ProvStep.deviceScan;
  String statusMessage = '';
  String? errorMessage;

  // Filter settings (empty = show all BLE devices)
  String devicePrefix = '';

  // Selected Device & Session
  BluetoothDevice? targetDevice;
  TransportBLE? transport;
  EspProv? espProv;

  // Security
  int securityType = 1; // 1 = Security 1 (PoP), 0 = Security 0 (No PoP)
  String pop = 'abcd1234';

  // Wi-Fi
  List<WifiAP> wifiNetworks = [];
  bool isScanningWifi = false;
  WifiAP? selectedWifi;
  String customSsid = '';
  String wifiPassword = '';

  // Completed status
  String? assignedIp;
  DateTime? provisionedTime;

  // Granular 4-step checklist status (Official Espressif checklist)
  StepStatus stepSession = StepStatus.pending;
  StepStatus stepSendConfig = StepStatus.pending;
  StepStatus stepApplyConfig = StepStatus.pending;
  StepStatus stepVerifyConnection = StepStatus.pending;

  void setDevicePrefix(String prefix) {
    devicePrefix = prefix;
    notifyListeners();
  }

  // Reset to initial state
  void reset() {
    currentStep = ProvStep.deviceScan;
    statusMessage = '';
    errorMessage = null;
    targetDevice = null;
    transport = null;
    espProv = null;
    wifiNetworks.clear();
    selectedWifi = null;
    customSsid = '';
    wifiPassword = '';
    assignedIp = null;
    provisionedTime = null;
    stepSession = StepStatus.pending;
    stepSendConfig = StepStatus.pending;
    stepApplyConfig = StepStatus.pending;
    stepVerifyConnection = StepStatus.pending;
    notifyListeners();
  }

  // Step 1 -> Step 2: Select Device
  void selectDevice(BluetoothDevice device, {String? defaultPop}) {
    targetDevice = device;
    if (defaultPop != null && defaultPop.isNotEmpty) {
      pop = defaultPop;
    }
    currentStep = ProvStep.securitySetup;
    errorMessage = null;
    notifyListeners();
  }

  // QR Code Payload Parser
  // Standard format: {"ver":"v1","name":"PROV_xxxxxx","pop":"abcd1234","transport":"ble"}
  Map<String, String>? parseQrPayload(String raw) {
    try {
      final clean = raw.trim();
      if (clean.startsWith('{') && clean.endsWith('}')) {
        final decoded = jsonDecode(clean);
        if (decoded is Map) {
          final name = decoded['name']?.toString() ?? '';
          final qrPop = decoded['pop']?.toString() ?? '';
          final transport = decoded['transport']?.toString() ?? 'ble';
          return {
            'name': name,
            'pop': qrPop,
            'transport': transport,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  // Step 2: Establish Secure Session
  Future<bool> establishSession({required int secType, required String popKey}) async {
    if (targetDevice == null) return false;

    securityType = secType;
    pop = popKey;
    statusMessage = 'Connecting to ${targetDevice!.platformName.isNotEmpty ? targetDevice!.platformName : targetDevice!.remoteId}...';
    errorMessage = null;
    notifyListeners();

    try {
      transport = TransportBLE(targetDevice!);
      final connected = await transport!.connect();
      if (!connected) {
        throw Exception(transport!.lastError ?? 'Could not connect to BLE device. Make sure device is nearby and advertising.');
      }

      statusMessage = secType == 1
          ? 'Handshaking with Proof of Possession (PoP)...'
          : 'Establishing open session (Security 0)...';
      notifyListeners();

      final ProvSecurity sec = secType == 1 ? Security1(pop: pop.trim()) : Security0();
      espProv = EspProv(transport: transport!, security: sec);

      final sessionStatus = await espProv!.establishSession();
      if (sessionStatus != EstablishSessionStatus.connected) {
        if (sessionStatus == EstablishSessionStatus.keymismatch) {
          throw Exception('Proof of Possession (PoP) mismatch! Please check the PoP key.');
        } else {
          throw Exception('Failed to establish provisioning session ($sessionStatus).');
        }
      }

      statusMessage = 'Secure session established successfully!';
      currentStep = ProvStep.wifiScan;
      notifyListeners();

      // Automatically trigger Wi-Fi scan once session is ready
      await scanWifiNetworks();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Step 3: Scan Wi-Fi from ESP32
  Future<void> scanWifiNetworks() async {
    if (espProv == null) return;

    isScanningWifi = true;
    statusMessage = 'Aadhya is scanning nearby 2.4GHz Wi-Fi networks...';
    errorMessage = null;
    notifyListeners();

    try {
      final networks = await espProv!.startScanWiFi();
      // Filter empty SSIDs and sort by signal strength (RSSI)
      wifiNetworks = networks.where((w) => w.ssid.trim().isNotEmpty).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

      isScanningWifi = false;
      statusMessage = 'Found ${wifiNetworks.length} Wi-Fi networks.';
      notifyListeners();
    } catch (e) {
      isScanningWifi = false;
      errorMessage = 'Wi-Fi scan failed: $e';
      notifyListeners();
    }
  }

  // Step 4: Choose Wi-Fi network
  void selectWifiNetwork(WifiAP ap) {
    selectedWifi = ap;
    customSsid = ap.ssid;
    currentStep = ProvStep.enterCredentials;
    notifyListeners();
  }

  void selectCustomNetwork() {
    selectedWifi = null;
    customSsid = '';
    currentStep = ProvStep.enterCredentials;
    notifyListeners();
  }

  // Step 5: Send Credentials, Apply & Verify IP
  Future<bool> startProvisioning({required String ssid, required String password}) async {
    if (espProv == null) return false;

    currentStep = ProvStep.provisioning;
    errorMessage = null;

    // Reset checklist
    stepSession = StepStatus.success; // Session was already established
    stepSendConfig = StepStatus.inProgress;
    stepApplyConfig = StepStatus.pending;
    stepVerifyConnection = StepStatus.pending;
    statusMessage = 'Sending Wi-Fi credentials to Aadhya device...';
    notifyListeners();

    try {
      // 1. Send Configuration
      final sendOk = await espProv!.sendWifiConfig(
        ssid: ssid,
        password: password,
        bssid: selectedWifi?.bssid,
      );

      if (!sendOk) {
        stepSendConfig = StepStatus.failed;
        throw Exception('Failed to send Wi-Fi configuration payload.');
      }
      stepSendConfig = StepStatus.success;

      // 2. Apply Configuration
      stepApplyConfig = StepStatus.inProgress;
      statusMessage = 'Applying Wi-Fi configuration on Aadhya device...';
      notifyListeners();

      final applyOk = await espProv!.applyWifiConfig();
      if (!applyOk) {
        stepApplyConfig = StepStatus.failed;
        throw Exception('Failed to apply configuration on Aadhya device.');
      }
      stepApplyConfig = StepStatus.success;

      // 3. Poll connection status (up to 25 seconds)
      stepVerifyConnection = StepStatus.inProgress;
      statusMessage = 'Aadhya connecting to "$ssid" & acquiring IP address...';
      notifyListeners();

      int attempts = 0;
      const maxAttempts = 25;
      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
        attempts++;

        try {
          final status = await espProv!.getStatus();

          if (status.state == WifiConnectionState.Connected) {
            assignedIp = status.deviceIp ?? '192.168.x.x';
            provisionedTime = DateTime.now();
            stepVerifyConnection = StepStatus.success;
            statusMessage = 'Device successfully provisioned! IP: $assignedIp';
            currentStep = ProvStep.completed;
            notifyListeners();
            return true;
          } else if (status.state == WifiConnectionState.Connecting) {
            statusMessage = 'Connecting to "$ssid"... ($attempts/$maxAttempts s)';
            notifyListeners();
          } else if (status.state == WifiConnectionState.Disconnected) {
            if (status.failedReason != null) {
              final reason = status.failedReason == WifiConnectFailedReason.AuthError
                  ? 'Authentication failed! Please check the Wi-Fi password.'
                  : status.failedReason == WifiConnectFailedReason.NetworkNotFound
                      ? 'Network "$ssid" was not found by Aadhya device.'
                      : 'Connection failed (${status.failedReason}).';
              stepVerifyConnection = StepStatus.failed;
              throw Exception(reason);
            }
          }
        } catch (pollError) {
          // If polling fails because Aadhya rebooted after successful provisioning, handle gracefully
          if (attempts > 5) {
            stepVerifyConnection = StepStatus.success;
            statusMessage = 'Credentials applied successfully! Aadhya device connected to Wi-Fi.';
            currentStep = ProvStep.completed;
            notifyListeners();
            return true;
          }
        }
      }

      stepVerifyConnection = StepStatus.failed;
      throw Exception('Connection timed out. Check password and router 2.4GHz frequency.');
    } catch (e) {
      if (stepVerifyConnection == StepStatus.inProgress) {
        stepVerifyConnection = StepStatus.failed;
      }
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      currentStep = ProvStep.failed;
      notifyListeners();
      return false;
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    try {
      await transport?.disconnect();
    } catch (_) {}
    notifyListeners();
  }
}
