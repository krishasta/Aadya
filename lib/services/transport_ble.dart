import 'dart:async';
import 'package:esp_provisioning_ble/esp_provisioning_ble.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Production-ready BLE transport for ESP-IDF BLE Provisioning
/// Implements [ProvTransport] from esp_provisioning_ble.
class TransportBLE implements ProvTransport {
  final BluetoothDevice device;
  final String serviceUUID;
  final Map<String, String> endpointTable;

  String? lastError;

  // Cached characteristics keyed by endpoint name ('prov-session', 'prov-config', etc.)
  final Map<String, BluetoothCharacteristic> _characteristics = {};

  // Standard ESP-IDF BLE Provisioning Service UUID
  static const String defaultServiceUUID = '021a9004-0382-4aea-bff4-6b3f1c5adfb4';

  // Standard ESP-IDF endpoint short UUIDs
  static const Map<String, String> defaultEndpoints = {
    'prov-scan': 'ff50',
    'prov-session': 'ff51',
    'prov-config': 'ff52',
    'proto-ver': 'ff53',
    'custom-data': 'ff54',
  };

  TransportBLE(
    this.device, {
    this.serviceUUID = defaultServiceUUID,
    this.endpointTable = defaultEndpoints,
  });

  /// Constructs full 128-bit UUID from endpoint short UUID
  String _buildCharUUID(String endpointHex) {
    final hex = int.parse(endpointHex, radix: 16).toRadixString(16).padLeft(4, '0');
    return '${serviceUUID.substring(0, 4)}$hex${serviceUUID.substring(8)}'.toLowerCase();
  }

  @override
  Future<bool> connect() async {
    lastError = null;
    try {
      if (device.isConnected) {
        await device.disconnect();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {}

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
    } catch (e) {
      debugPrint('[TransportBLE] Connection error: $e');
      lastError = 'Connection failed: $e';
      return false;
    }

    try {
      await device.requestMtu(256);
    } catch (_) {}

    try {
      final services = await device.discoverServices();
      await _cacheCharacteristics(services);
    } catch (e) {
      debugPrint('[TransportBLE] Service discovery error: $e');
      lastError = 'Service discovery error: $e';
      return false;
    }

    if (!_characteristics.containsKey('prov-session')) {
      lastError = 'Provisioning endpoints not found on "${device.platformName.isNotEmpty ? device.platformName : "device"}". Make sure device is running Aadhya BLE Provisioning firmware.';
      debugPrint('[TransportBLE] $lastError');
      return false;
    }

    return device.isConnected;
  }

  Future<void> _cacheCharacteristics(List<BluetoothService> services) async {
    _characteristics.clear();

    final targetUUIDs = {
      for (final entry in endpointTable.entries)
        _buildCharUUID(entry.value): entry.key,
    };

    for (final service in services) {
      for (final char in service.characteristics) {
        final uuidStr = char.uuid.str128.toLowerCase();
        var endpointName = targetUUIDs[uuidStr];

        // Short hex match fallback (e.g. 'ff51', 'ff52')
        if (endpointName == null) {
          for (final entry in endpointTable.entries) {
            if (uuidStr.contains(entry.value.toLowerCase())) {
              endpointName = entry.key;
              break;
            }
          }
        }

        if (endpointName != null) {
          _characteristics[endpointName] = char;
        }
      }
    }

    // Descriptor matching fallback (0x2901 User Description)
    if (!_characteristics.containsKey('prov-session')) {
      for (final service in services) {
        for (final char in service.characteristics) {
          for (final desc in char.descriptors) {
            final descUuid = desc.uuid.str128.toLowerCase();
            if (descUuid.contains('2901')) {
              try {
                final val = await desc.read();
                final text = String.fromCharCodes(val).trim();
                if (endpointTable.containsKey(text)) {
                  _characteristics[text] = char;
                }
              } catch (_) {}
            }
          }
        }
      }
    }

    debugPrint('[TransportBLE] Cached ${_characteristics.length}/${endpointTable.length} provisioning endpoints.');
  }

  @override
  Future<Uint8List> sendReceive(String epName, Uint8List data) async {
    final char = _characteristics[epName];
    if (char == null) {
      throw StateError('Characteristic not found for endpoint: $epName. Discovered endpoints: ${_characteristics.keys.toList()}');
    }

    if (data.isNotEmpty) {
      await char.write(data.toList(), withoutResponse: false);
    }

    final response = await char.read();
    return Uint8List.fromList(response);
  }

  @override
  Future<bool> disconnect() async {
    if (device.isConnected) {
      try {
        await device.disconnect();
        return true;
      } catch (e) {
        debugPrint('[TransportBLE] Disconnect error: $e');
        return false;
      }
    }
    return true;
  }

  @override
  Future<bool> checkConnect() async {
    return device.isConnected;
  }
}
