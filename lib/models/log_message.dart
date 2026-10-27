import 'package:intl/intl.dart';

enum MessageDirection {
  tx, // Transmitted (App -> ESP32)
  rx, // Received (ESP32 -> App)
  system, // Internal system status (Connected, Disconnected, etc.)
  error, // Communication errors
}

class LogMessage {
  final String id;
  final DateTime timestamp;
  final MessageDirection direction;
  final String text;
  final List<int>? rawBytes;

  LogMessage({
    required this.id,
    required this.timestamp,
    required this.direction,
    required this.text,
    this.rawBytes,
  });

  String get formattedTime {
    return DateFormat('HH:mm:ss.SSS').format(timestamp);
  }

  String get hexString {
    if (rawBytes == null || rawBytes!.isEmpty) {
      return text.codeUnits
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
    }
    return rawBytes!
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }
}
