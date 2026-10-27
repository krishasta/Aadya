import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MqttStatus {
  disconnected,
  connecting,
  connected,
  subscribing,
  error,
}

class MqttSensorData {
  final int timestamp;
  final String formattedTime;
  final String deviceId;
  final String plant;
  final String stage;
  final String environment;
  final double temperature;
  final double humidity;
  final double pm1;
  final double pm25;
  final double pm4;
  final double pm10;
  final String topic;
  final String rawJson;

  MqttSensorData({
    required this.timestamp,
    required this.formattedTime,
    required this.deviceId,
    required this.plant,
    required this.stage,
    required this.environment,
    required this.temperature,
    required this.humidity,
    required this.pm1,
    required this.pm25,
    required this.pm4,
    required this.pm10,
    required this.topic,
    required this.rawJson,
  });

  factory MqttSensorData.fromJson(Map<String, dynamic> json, String topic, String raw) {
    // 1. Timestamp
    int ts = 0;
    if (json['timestamp'] is int) {
      ts = json['timestamp'] as int;
    } else if (json['timestamp'] is double) {
      ts = (json['timestamp'] as double).toInt();
    } else if (json['timestamp'] is String) {
      ts = int.tryParse(json['timestamp']) ?? 0;
    }
    if (ts == 0) {
      ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }

    DateTime dt;
    if (ts > 1000000000000) {
      dt = DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    }
    final formatted = DateFormat('MM/dd/yyyy hh:mm:ss a').format(dt);

    // 2. Sensor metadata
    final sensor = json['sensor'] is Map ? json['sensor'] as Map : {};
    final devId = (sensor['deviceId'] ?? json['deviceId'] ?? 'DEV-0001').toString();
    final plant = (sensor['plant'] ?? json['plant'] ?? 'unit1').toString();
    final stage = (sensor['stage'] ?? json['stage'] ?? 'stage1').toString();
    final env = (sensor['environment'] ?? json['environment'] ?? 'production').toString();

    // 3. Measurements
    final meas = json['measurements'] is Map ? json['measurements'] as Map : json;
    
    double parseNum(dynamic val, [double def = 0.0]) {
      if (val == null) return def;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? def;
      return def;
    }

    final temp = parseNum(meas['temperature'] ?? meas['temp']);
    final hum = parseNum(meas['humidity'] ?? meas['hum']);
    final p1 = parseNum(meas['PM1'] ?? meas['pm1']);
    final p25 = parseNum(meas['PM2_5'] ?? meas['PM2.5'] ?? meas['pm2_5'] ?? meas['pm25']);
    final p4 = parseNum(meas['PM4'] ?? meas['pm4']);
    final p10 = parseNum(meas['PM10'] ?? meas['pm10']);

    return MqttSensorData(
      timestamp: ts,
      formattedTime: formatted,
      deviceId: devId,
      plant: plant,
      stage: stage,
      environment: env,
      temperature: temp,
      humidity: hum,
      pm1: p1,
      pm25: p25,
      pm4: p4,
      pm10: p10,
      topic: topic,
      rawJson: raw,
    );
  }
}

class MqttLogEntry {
  final DateTime time;
  final String topic;
  final String payload;
  final bool isError;

  MqttLogEntry({
    required this.time,
    required this.topic,
    required this.payload,
    this.isError = false,
  });

  String get formattedTime => DateFormat('hh:mm:ss a').format(time);
}

class MqttService extends ChangeNotifier {
  static final MqttService instance = MqttService._internal();
  MqttService._internal();

  // Keys for SharedPreferences
  static const String _prefBrokerIp = 'mqtt_broker_ip';
  static const String _prefBrokerPort = 'mqtt_broker_port';
  static const String _prefTopic = 'mqtt_topic';
  static const String _prefCmdTopic = 'mqtt_cmd_topic';
  static const String _prefClientId = 'mqtt_client_id';
  static const String _prefUsername = 'mqtt_username';
  static const String _prefPassword = 'mqtt_password';

  // Config parameters with defaults from MQTT Explorer screenshot
  String brokerIp = '98.130.58.226';
  int brokerPort = 1883;
  String topic = 'Sen62/#';
  String cmdTopic = 'Sen62/Device0/cmd';
  String clientId = 'Aadhya_App_${DateTime.now().millisecondsSinceEpoch % 10000}';
  String username = '';
  String password = '';

  // Runtime State
  MqttServerClient? _client;
  MqttStatus status = MqttStatus.disconnected;
  String statusMessage = 'Ready to connect';
  String? lastError;
  String deviceStatus = 'offline';
  bool isLiveData = false;

  // Sensor Data
  MqttSensorData? currentData;
  final List<MqttSensorData> history = [];
  final List<MqttLogEntry> logs = [];
  int messageCount = 0;
  DateTime? lastMessageTime;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      brokerIp = prefs.getString(_prefBrokerIp) ?? '98.130.58.226';
      brokerPort = prefs.getInt(_prefBrokerPort) ?? 1883;
      topic = prefs.getString(_prefTopic) ?? 'Sen62/#';
      cmdTopic = prefs.getString(_prefCmdTopic) ?? 'Sen62/Device0/cmd';
      clientId = prefs.getString(_prefClientId) ?? clientId;
      username = prefs.getString(_prefUsername) ?? '';
      password = prefs.getString(_prefPassword) ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('[MqttService] Init error: $e');
    }
  }

  Future<void> saveSettings({
    required String ip,
    required int port,
    required String newTopic,
    String? newCmdTopic,
    String? newClientId,
    String? user,
    String? pass,
  }) async {
    brokerIp = ip.trim();
    brokerPort = port;
    topic = newTopic.trim();
    if (newCmdTopic != null && newCmdTopic.trim().isNotEmpty) {
      cmdTopic = newCmdTopic.trim();
    }
    if (newClientId != null && newClientId.trim().isNotEmpty) {
      clientId = newClientId.trim();
    }
    if (user != null) username = user.trim();
    if (pass != null) password = pass.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefBrokerIp, brokerIp);
      await prefs.setInt(_prefBrokerPort, brokerPort);
      await prefs.setString(_prefTopic, topic);
      await prefs.setString(_prefCmdTopic, cmdTopic);
      await prefs.setString(_prefClientId, clientId);
      await prefs.setString(_prefUsername, username);
      await prefs.setString(_prefPassword, password);
    } catch (e) {
      debugPrint('[MqttService] Error saving settings: $e');
    }
    notifyListeners();
  }

  Future<void> connect() async {
    if (status == MqttStatus.connecting || status == MqttStatus.connected) {
      return;
    }

    disconnect();

    status = MqttStatus.connecting;
    statusMessage = 'Connecting to $brokerIp:$brokerPort...';
    lastError = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        throw Exception(
          'Web browsers block raw TCP sockets on port $brokerPort. '
          'Please run as Android APK on your phone or on Windows Desktop to connect directly to $brokerIp:$brokerPort.',
        );
      }
      _client = MqttServerClient.withPort(brokerIp, clientId, brokerPort);
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30;
      _client!.autoReconnect = true;
      _client!.resubscribeOnAutoReconnect = true;
      _client!.connectTimeoutPeriod = 8000;
      // Set MQTT 3.1 protocol compatibility required by the broker
      _client!.setProtocolV31();

      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onSubscribeFail = _onSubscribeFail;

      final connMess = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      if (username.isNotEmpty) {
        connMess.authenticateAs(username, password);
      }

      _client!.connectionMessage = connMess;

      _addLog('SYS', 'Connecting to $brokerIp:$brokerPort (MQTT 3.1)...');
      final connStatus = await _client!.connect();

      if (connStatus?.state != MqttConnectionState.connected) {
        throw Exception('Connection state: ${connStatus?.state}');
      }

      _subscribeToTopic();
    } catch (e) {
      debugPrint('[MqttService] Connection error: $e');
      status = MqttStatus.error;
      lastError = e.toString();
      statusMessage = 'Connection failed: $e';
      _addLog('ERROR', 'Connection failed: $e', isError: true);
      _client?.disconnect();
      _client = null;
      notifyListeners();
    }
  }

  void _subscribeToTopic() {
    if (_client == null || _client!.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }

    status = MqttStatus.subscribing;
    statusMessage = 'Subscribing to $topic...';
    notifyListeners();

    try {
      _client!.subscribe(topic, MqttQos.atMostOnce);
      _addLog('SYS', 'Subscribing to topic: $topic');

      _client!.updates?.listen(_onMessageReceived);
    } catch (e) {
      debugPrint('[MqttService] Subscription error: $e');
      statusMessage = 'Subscription failed: $e';
      notifyListeners();
    }
  }

  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (var msg in messages) {
      final recMess = msg.payload as MqttPublishMessage;
      final payloadString = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final receivedTopic = msg.topic;

      messageCount++;
      lastMessageTime = DateTime.now();
      isLiveData = true;

      _addLog(receivedTopic, payloadString);

      if (receivedTopic.toLowerCase().contains('status')) {
        deviceStatus = payloadString.trim().toLowerCase();
      }

      try {
        final dynamic decoded = jsonDecode(payloadString);
        if (decoded is Map<String, dynamic>) {
          final data = MqttSensorData.fromJson(decoded, receivedTopic, payloadString);
          currentData = data;
          history.add(data);
          if (history.length > 50) {
            history.removeAt(0);
          }
        }
      } catch (jsonErr) {
        debugPrint('[MqttService] JSON parsing error: $jsonErr');
      }

      notifyListeners();
    }
  }

  void _onConnected() {
    status = MqttStatus.connected;
    statusMessage = 'Connected to $brokerIp';
    _addLog('SYS', 'Successfully connected to MQTT Broker ($brokerIp:$brokerPort)');
    notifyListeners();
  }

  void _onDisconnected() {
    if (status != MqttStatus.error) {
      status = MqttStatus.disconnected;
      statusMessage = 'Disconnected';
      _addLog('SYS', 'MQTT client disconnected');
      notifyListeners();
    }
  }

  void _onSubscribed(String subTopic) {
    status = MqttStatus.connected;
    statusMessage = 'Subscribed to $subTopic';
    _addLog('SYS', 'Active subscription on $subTopic');
    notifyListeners();
  }

  void _onSubscribeFail(String subTopic) {
    statusMessage = 'Failed to subscribe to $subTopic';
    _addLog('ERROR', 'Subscription failed for $subTopic', isError: true);
    notifyListeners();
  }

  void disconnect() {
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
    status = MqttStatus.disconnected;
    statusMessage = 'Disconnected';
    notifyListeners();
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  void injectReading(Map<String, dynamic> json, String topic) {
    final raw = jsonEncode(json);
    final data = MqttSensorData.fromJson(json, topic, raw);
    isLiveData = false;
    currentData = data;
    history.add(data);
    if (history.length > 50) history.removeAt(0);
    messageCount++;
    lastMessageTime = DateTime.now();
    _addLog(topic, raw);
    notifyListeners();
  }

  void _addLog(String topic, String payload, {bool isError = false}) {
    logs.insert(0, MqttLogEntry(
      time: DateTime.now(),
      topic: topic,
      payload: payload,
      isError: isError,
    ));
    if (logs.length > 50) {
      logs.removeLast();
    }
  }

  /// Returns the configured command topic or auto-detects from active device topic
  String getEffectiveCmdTopic() {
    if (cmdTopic.trim().isNotEmpty) {
      return cmdTopic.trim();
    }
    if (currentData != null && currentData!.topic.isNotEmpty) {
      final base = currentData!.topic.replaceAll('/#', '').replaceAll('/data', '');
      return '$base/cmd';
    }
    return 'Sen62/Device0/cmd';
  }

  /// Publishes a raw message payload to a target topic
  Future<bool> publishMessage(
    String targetTopic,
    String message, {
    bool retain = false,
    MqttQos qos = MqttQos.atMostOnce,
  }) async {
    if (_client == null || _client!.connectionStatus?.state != MqttConnectionState.connected) {
      _addLog('ERROR', 'Cannot publish: MQTT broker not connected', isError: true);
      notifyListeners();
      return false;
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(targetTopic, qos, builder.payload!, retain: retain);
      _addLog(targetTopic, message);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MqttService] Publish error: $e');
      _addLog('ERROR', 'Publish failed on $targetTopic: $e', isError: true);
      notifyListeners();
      return false;
    }
  }

  /// Sends the Reset command to the controller via MQTT
  /// Default topic: Sen62/Device0/cmd
  /// Payload: {"command": "RESET_WIFI"}
  Future<bool> sendResetDeviceCommand({
    String? targetTopic,
    String command = 'RESET_WIFI',
    bool isSimulating = false,
  }) async {
    final topicToSend = (targetTopic != null && targetTopic.trim().isNotEmpty)
        ? targetTopic.trim()
        : getEffectiveCmdTopic();

    final payload = jsonEncode({'command': command});

    if (isSimulating) {
      _addLog(topicToSend, payload);
      deviceStatus = 'resetting_wifi';
      _addLog('$topicToSend/status', 'resetting_wifi');
      notifyListeners();
      return true;
    }

    final success = await publishMessage(topicToSend, payload);
    if (success) {
      deviceStatus = 'resetting_wifi';
      notifyListeners();
    }
    return success;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
