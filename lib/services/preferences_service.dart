import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quick_command.dart';

class PreferencesService {
  static const String _keyQuickCommands = 'quick_commands_v1';
  static const String _keyLastDeviceId = 'last_device_id';
  static const String _keyLineEnding = 'line_ending';
  static const String _keyHexMode = 'hex_mode';
  static const String _keyAutoScroll = 'auto_scroll';

  static final List<QuickCommand> defaultCommands = [
    const QuickCommand(
      id: 'cmd_1',
      title: 'LED ON',
      command: 'LED:1',
      colorValue: 0xFF00E676,
      description: 'Turn built-in/pin 2 LED ON',
    ),
    const QuickCommand(
      id: 'cmd_2',
      title: 'LED OFF',
      command: 'LED:0',
      colorValue: 0xFFFF3D71,
      description: 'Turn built-in/pin 2 LED OFF',
    ),
    const QuickCommand(
      id: 'cmd_3',
      title: 'STATUS',
      command: 'STATUS',
      colorValue: 0xFF00E5FF,
      description: 'Request device status & sensors',
    ),
    const QuickCommand(
      id: 'cmd_4',
      title: 'PING',
      command: 'PING',
      colorValue: 0xFFFFB300,
      description: 'Heartbeat echo test',
    ),
    const QuickCommand(
      id: 'cmd_5',
      title: 'REBOOT',
      command: 'REBOOT',
      colorValue: 0xFFB388FF,
      description: 'Software restart SOLink',
    ),
  ];

  static Future<List<QuickCommand>> loadQuickCommands() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyQuickCommands);
    if (jsonString == null || jsonString.isEmpty) {
      return List.from(defaultCommands);
    }
    try {
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((item) => QuickCommand.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return List.from(defaultCommands);
    }
  }

  static Future<void> saveQuickCommands(List<QuickCommand> commands) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(commands.map((c) => c.toJson()).toList());
    await prefs.setString(_keyQuickCommands, jsonString);
  }

  static Future<String?> getLastDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastDeviceId);
  }

  static Future<void> setLastDeviceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastDeviceId, id);
  }

  static Future<String> getLineEnding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLineEnding) ?? '\r\n';
  }

  static Future<void> setLineEnding(String ending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLineEnding, ending);
  }

  static Future<bool> getHexMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHexMode) ?? false;
  }

  static Future<void> setHexMode(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHexMode, val);
  }

  static Future<bool> getAutoScroll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoScroll) ?? true;
  }

  static Future<void> setAutoScroll(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoScroll, val);
  }
}
