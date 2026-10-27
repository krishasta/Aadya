class TelemetryPoint {
  final DateTime timestamp;
  final String key;
  final double value;
  final String? unit;

  TelemetryPoint({
    required this.timestamp,
    required this.key,
    required this.value,
    this.unit,
  });
}

class TelemetrySeries {
  final String key;
  final String displayName;
  final String unit;
  final int colorValue;
  final List<TelemetryPoint> points;
  double? minValue;
  double? maxValue;
  double? latestValue;

  TelemetrySeries({
    required this.key,
    required this.displayName,
    required this.unit,
    required this.colorValue,
    List<TelemetryPoint>? points,
  }) : points = points ?? [];

  void addPoint(double value, {String? unit}) {
    final now = DateTime.now();
    points.add(TelemetryPoint(
      timestamp: now,
      key: key,
      value: value,
      unit: unit ?? this.unit,
    ));

    latestValue = value;
    if (minValue == null || value < minValue!) minValue = value;
    if (maxValue == null || value > maxValue!) maxValue = value;

    // Keep history bounded to last 60 data points for smooth performance
    if (points.length > 60) {
      points.removeAt(0);
    }
  }
}
