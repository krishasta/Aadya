import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/log_message.dart';
import '../models/telemetry_point.dart';
import 'preferences_service.dart';

// Well-known BLE Serial Service & Characteristic UUIDs
class BleUuids {
  // Nordic UART Service (Standard ESP32 BLE Serial / NUS)
  static const String nusService = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String nusRx = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // Write
  static const String nusTx = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; // Notify

  // HM-10 / AT-09 / CC2541 Serial
  static const String hm10Service = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String hm10Char = "0000ffe1-0000-1000-8000-00805f9b34fb";
}

class BleService extends ChangeNotifier {
  static final BleService instance = BleService._internal();
  BleService._internal();

  // Adapter & Scan State
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
  bool get isBluetoothOn => adapterState == BluetoothAdapterState.on;
  bool isScanning = false;
  List<ScanResult> scanResults = [];
  String? searchFilter;

  // Active Connection State
  BluetoothDevice? connectedDevice;
  BluetoothConnectionState connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> discoveredServices = [];

  // Active Serial Characteristics
  BluetoothCharacteristic? writeCharacteristic; // TX from App -> RX of ESP32
  BluetoothCharacteristic? notifyCharacteristic; // RX into App <- TX of ESP32

  // Terminal & Telemetry Data
  final List<LogMessage> logs = [];
  final Map<String, TelemetrySeries> telemetryData = {};
  String lineEnding = '\r\n';
  bool hexMode = false;
  bool autoScroll = true;

  // Stats
  int totalBytesSent = 0;
  int totalBytesReceived = 0;
  DateTime? connectedSince;

  // Subscriptions
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  // Initialize BLE listeners
  Future<void> init() async {
    lineEnding = await PreferencesService.getLineEnding();
    hexMode = await PreferencesService.getHexMode();
    autoScroll = await PreferencesService.getAutoScroll();

    _adapterSubscription?.cancel();
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      adapterState = state;
      notifyListeners();
    });

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      scanResults = results;
      notifyListeners();
    });

    _isScanningSubscription?.cancel();
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      isScanning = scanning;
      notifyListeners();
    });
  }

  // Request Permissions on mobile platforms
  Future<bool> checkAndRequestPermissions() async {
    if (!kIsWeb && Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final allGranted = statuses.values.every(
        (status) => status.isGranted || status.isLimited,
      );

      if (!allGranted) {
        addLog(
          "Bluetooth / Location permissions not fully granted. Scanning might fail.",
          MessageDirection.error,
        );
        return false;
      }
    }
    return true;
  }

  // Request system to turn on Bluetooth
  Future<bool> turnOnBluetooth() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
        return true;
      } else {
        await openAppSettings();
        return false;
      }
    } catch (e) {
      addLog("Could not enable Bluetooth: $e", MessageDirection.error);
      try {
        await openAppSettings();
      } catch (_) {}
      return false;
    }
  }

  // Open App or Bluetooth system settings
  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }

  // Start BLE Scan
  Future<void> startScan({Duration timeout = const Duration(seconds: 12)}) async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return;

    if (adapterState != BluetoothAdapterState.on) {
      addLog("Bluetooth is not turned ON.", MessageDirection.error);
      return;
    }

    try {
      scanResults.clear();
      notifyListeners();
      await FlutterBluePlus.startScan(
        timeout: timeout,
        webOptionalServices: [
          Guid("021a9004-0382-4aea-bff4-6b3f1c5adfb4"),
          Guid("0000ffff-0000-1000-8000-00805f9b34fb"),
          Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e"),
          Guid("0000ffe0-0000-1000-8000-00805f9b34fb"),
        ],
      );
    } catch (e) {
      final errStr = e.toString();
      if (!errStr.contains('User cancelled') && !errStr.contains('NotFoundError')) {
        addLog("Failed to start scan: $e", MessageDirection.error);
      }
    }
  }

  // Stop Scan
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  // Connect to Device
  Future<bool> connect(BluetoothDevice device) async {
    await stopScan();
    addLog("Connecting to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}...", MessageDirection.system);

    try {
      connectedDevice = device;
      notifyListeners();

      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        connectionState = state;
        if (state == BluetoothConnectionState.connected) {
          connectedSince = DateTime.now();
          addLog("Connected successfully to ${device.platformName}!", MessageDirection.system);
          PreferencesService.setLastDeviceId(device.remoteId.str);
        } else if (state == BluetoothConnectionState.disconnected) {
          connectedSince = null;
          writeCharacteristic = null;
          notifyCharacteristic = null;
          addLog("Device disconnected.", MessageDirection.system);
        }
        notifyListeners();
      });

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Request MTU to 512 for higher data throughput (supported on Android/ESP32)
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await device.requestMtu(512);
        } catch (_) {}
      }

      await discoverAndConfigureServices();
      return true;
    } catch (e) {
      addLog("Connection failed: $e", MessageDirection.error);
      connectionState = BluetoothConnectionState.disconnected;
      notifyListeners();
      return false;
    }
  }

  // Disconnect from current device
  Future<void> disconnect() async {
    if (connectedDevice != null) {
      addLog("Disconnecting...", MessageDirection.system);
      try {
        await _notifySubscription?.cancel();
        _notifySubscription = null;
        await connectedDevice!.disconnect();
      } catch (e) {
        addLog("Error during disconnect: $e", MessageDirection.error);
      }
    }
    connectedDevice = null;
    discoveredServices.clear();
    writeCharacteristic = null;
    notifyCharacteristic = null;
    connectionState = BluetoothConnectionState.disconnected;
    notifyListeners();
  }

  // Auto-detect Nordic UART or generic serial characteristics
  Future<void> discoverAndConfigureServices() async {
    if (connectedDevice == null) return;

    try {
      discoveredServices = await connectedDevice!.discoverServices();
      addLog("Discovered ${discoveredServices.length} GATT services.", MessageDirection.system);

      BluetoothCharacteristic? foundWrite;
      BluetoothCharacteristic? foundNotify;

      // 1. Search for Nordic UART Service (Standard ESP32 NUS)
      for (var s in discoveredServices) {
        final sUuid = s.uuid.str128.toLowerCase();
        if (sUuid == BleUuids.nusService) {
          for (var c in s.characteristics) {
            final cUuid = c.uuid.str128.toLowerCase();
            if (cUuid == BleUuids.nusRx) {
              foundWrite = c;
            } else if (cUuid == BleUuids.nusTx) {
              foundNotify = c;
            }
          }
        }
      }

      // 2. Search for HM-10 / FFE0 Service if NUS not found
      if (foundWrite == null || foundNotify == null) {
        for (var s in discoveredServices) {
          final sUuid = s.uuid.str128.toLowerCase();
          if (sUuid.contains("ffe0")) {
            for (var c in s.characteristics) {
              final cUuid = c.uuid.str128.toLowerCase();
              if (cUuid.contains("ffe1")) {
                if (c.properties.write || c.properties.writeWithoutResponse) {
                  foundWrite ??= c;
                }
                if (c.properties.notify || c.properties.indicate) {
                  foundNotify ??= c;
                }
              }
            }
          }
        }
      }

      // 3. Fallback: Search any characteristic that supports notify and write
      if (foundWrite == null || foundNotify == null) {
        for (var s in discoveredServices) {
          // Skip standard generic access and attribute services (1800, 1801)
          if (s.uuid.str128.toLowerCase().contains("00001800") ||
              s.uuid.str128.toLowerCase().contains("00001801")) {
            continue;
          }

          for (var c in s.characteristics) {
            if (foundWrite == null &&
                (c.properties.write || c.properties.writeWithoutResponse)) {
              foundWrite = c;
            }
            if (foundNotify == null &&
                (c.properties.notify || c.properties.indicate)) {
              foundNotify = c;
            }
          }
        }
      }

      // Set active characteristics
      if (foundWrite != null) {
        writeCharacteristic = foundWrite;
        addLog(
          "Configured TX (Write) Characteristic: ${foundWrite.uuid.str128.substring(0, 8)}...",
          MessageDirection.system,
        );
      } else {
        addLog(
          "Warning: No writable characteristic detected automatically.",
          MessageDirection.error,
        );
      }

      if (foundNotify != null) {
        notifyCharacteristic = foundNotify;
        addLog(
          "Configured RX (Notify) Characteristic: ${foundNotify.uuid.str128.substring(0, 8)}...",
          MessageDirection.system,
        );
        await subscribeToNotifications(foundNotify);
      } else {
        addLog(
          "Warning: No notify/indicate characteristic detected automatically.",
          MessageDirection.error,
        );
      }

      notifyListeners();
    } catch (e) {
      addLog("Failed to discover services: $e", MessageDirection.error);
    }
  }

  // Subscribe to Notify characteristic
  Future<void> subscribeToNotifications(BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
      _notifySubscription?.cancel();
      _notifySubscription = characteristic.onValueReceived.listen((data) {
        if (data.isEmpty) return;
        totalBytesReceived += data.length;

        final text = utf8.decode(data, allowMalformed: true);
        addLog(text, MessageDirection.rx, rawBytes: data);
        _parseTelemetry(text);
        notifyListeners();
      });
      addLog("Subscribed to live RX notifications.", MessageDirection.system);
    } catch (e) {
      addLog("Failed to subscribe notifications: $e", MessageDirection.error);
    }
  }

  // Parse incoming text for IoT telemetry patterns
  void _parseTelemetry(String rawText) {
    // Clean string
    final text = rawText.trim();
    if (text.isEmpty) return;

    // Pattern 1: KEY:VALUE or KEY=VALUE (e.g., TEMP:24.5, HUM=60.2, POT:512)
    final kvRegex = RegExp(r'([A-Za-z0-9_\-\s]+)[:=]\s*([0-9\.\-]+)');
    final matches = kvRegex.allMatches(text);

    if (matches.isNotEmpty) {
      for (final match in matches) {
        final key = match.group(1)?.trim().toUpperCase() ?? 'VAL';
        final valStr = match.group(2)?.trim() ?? '0';
        final val = double.tryParse(valStr);
        if (val != null) {
          _recordTelemetryPoint(key, val);
        }
      }
      return;
    }

    // Pattern 2: Single pure numeric string (e.g. "24.5")
    final numVal = double.tryParse(text);
    if (numVal != null) {
      _recordTelemetryPoint("SENSOR", numVal);
      return;
    }

    // Pattern 3: CSV numeric stream (e.g., "24.5,60.2,1013")
    if (text.contains(',')) {
      final parts = text.split(',');
      for (int i = 0; i < parts.length; i++) {
        final pVal = double.tryParse(parts[i].trim());
        if (pVal != null) {
          _recordTelemetryPoint("CH_${i + 1}", pVal);
        }
      }
    }
  }

  void _recordTelemetryPoint(String key, double value) {
    if (!telemetryData.containsKey(key)) {
      // Pick a distinctive color based on key
      final colors = [
        0xFF00E5FF, // Cyan
        0xFF00E676, // Emerald
        0xFFFFB300, // Amber
        0xFFB388FF, // Purple
        0xFFFF3D71, // Crimson
        0xFF2979FF, // Royal Blue
      ];
      final color = colors[telemetryData.length % colors.length];

      String unit = '';
      if (key.contains("TEMP")) unit = '°C';
      if (key.contains("HUM")) unit = '%';
      if (key.contains("VOLT") || key.contains("V")) unit = 'V';
      if (key.contains("AMP") || key.contains("CUR")) unit = 'A';
      if (key.contains("PRESS") || key.contains("BAR")) unit = 'hPa';
      if (key.contains("RPM")) unit = 'RPM';

      telemetryData[key] = TelemetrySeries(
        key: key,
        displayName: key,
        unit: unit,
        colorValue: color,
      );
    }

    telemetryData[key]!.addPoint(value);
  }

  // Send Command to ESP32
  Future<bool> sendCommand(String rawCommand) async {
    if (writeCharacteristic == null) {
      addLog("Cannot send: No write characteristic connected.", MessageDirection.error);
      return false;
    }

    try {
      final formattedString = rawCommand + lineEnding;
      final bytes = utf8.encode(formattedString);

      final withoutResponse = writeCharacteristic!.properties.writeWithoutResponse;
      await writeCharacteristic!.write(bytes, withoutResponse: withoutResponse);

      totalBytesSent += bytes.length;
      addLog(rawCommand, MessageDirection.tx, rawBytes: bytes);
      notifyListeners();
      return true;
    } catch (e) {
      addLog("Send error: $e", MessageDirection.error);
      return false;
    }
  }

  // Send Raw Bytes (for hex sending)
  Future<bool> sendBytes(List<int> bytes) async {
    if (writeCharacteristic == null) {
      addLog("Cannot send: No write characteristic connected.", MessageDirection.error);
      return false;
    }

    try {
      final withoutResponse = writeCharacteristic!.properties.writeWithoutResponse;
      await writeCharacteristic!.write(bytes, withoutResponse: withoutResponse);

      totalBytesSent += bytes.length;
      addLog("HEX[${bytes.length}]", MessageDirection.tx, rawBytes: bytes);
      notifyListeners();
      return true;
    } catch (e) {
      addLog("Send error: $e", MessageDirection.error);
      return false;
    }
  }

  // Manual characteristic override
  void setManualCharacteristics({
    BluetoothCharacteristic? write,
    BluetoothCharacteristic? notify,
  }) {
    if (write != null) writeCharacteristic = write;
    if (notify != null) {
      notifyCharacteristic = notify;
      subscribeToNotifications(notify);
    }
    notifyListeners();
  }

  // Add Log Message
  void addLog(String text, MessageDirection direction, {List<int>? rawBytes}) {
    final msg = LogMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      direction: direction,
      text: text,
      rawBytes: rawBytes,
    );

    logs.add(msg);
    // Limit memory log buffer to 1000 items
    if (logs.length > 1000) {
      logs.removeAt(0);
    }
    notifyListeners();
  }

  // Clear Logs
  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  // Clear Telemetry Points
  void clearTelemetry() {
    telemetryData.clear();
    notifyListeners();
  }

  // Export Logs to Text
  String exportLogsAsText() {
    final buffer = StringBuffer();
    buffer.writeln("=== SOLink BLE SERIAL LOG EXPORT ===");
    buffer.writeln("Export Time: ${DateTime.now()}");
    buffer.writeln("Device: ${connectedDevice?.platformName ?? 'Unknown'} (${connectedDevice?.remoteId})");
    buffer.writeln("Total TX Bytes: $totalBytesSent, Total RX Bytes: $totalBytesReceived");
    buffer.writeln("---------------------------------------------");
    for (var msg in logs) {
      final dirStr = msg.direction == MessageDirection.tx
          ? "TX ->"
          : msg.direction == MessageDirection.rx
              ? "RX <-"
              : msg.direction == MessageDirection.system
                  ? "SYS "
                  : "ERR ";
      buffer.writeln("[${msg.formattedTime}] $dirStr ${msg.text.replaceAll('\r', '').replaceAll('\n', '')}");
    }
    return buffer.toString();
  }

  // Set Line Ending
  Future<void> updateLineEnding(String ending) async {
    lineEnding = ending;
    await PreferencesService.setLineEnding(ending);
    notifyListeners();
  }

  // Toggle Hex Mode
  Future<void> toggleHexMode(bool enabled) async {
    hexMode = enabled;
    await PreferencesService.setHexMode(enabled);
    notifyListeners();
  }

  // Toggle Auto Scroll
  Future<void> toggleAutoScroll(bool enabled) async {
    autoScroll = enabled;
    await PreferencesService.setAutoScroll(enabled);
    notifyListeners();
  }

  @override
  void dispose() {
    _adapterSubscription?.cancel();
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notifySubscription?.cancel();
    super.dispose();
  }
}
