import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/log_message.dart';
import '../models/telemetry_point.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class TelemetryTab extends StatefulWidget {
  const TelemetryTab({super.key});

  @override
  State<TelemetryTab> createState() => _TelemetryTabState();
}

class _TelemetryTabState extends State<TelemetryTab> {
  final BleService _ble = BleService.instance;
  String? _selectedKey;
  bool _isSimulating = false;
  Timer? _simTimer;

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onBleUpdate);
    if (_ble.telemetryData.isNotEmpty) {
      _selectedKey = _ble.telemetryData.keys.first;
    }
  }

  @override
  void dispose() {
    _ble.removeListener(_onBleUpdate);
    _simTimer?.cancel();
    super.dispose();
  }

  void _onBleUpdate() {
    if (!mounted) return;
    if (_selectedKey == null && _ble.telemetryData.isNotEmpty) {
      _selectedKey = _ble.telemetryData.keys.first;
    }
    setState(() {});
  }

  void _toggleSimulation() {
    if (_isSimulating) {
      _simTimer?.cancel();
      _simTimer = null;
      setState(() => _isSimulating = false);
    } else {
      setState(() => _isSimulating = true);
      double temp = 24.0;
      double hum = 55.0;
      double volt = 3.3;
      final rnd = Random();

      _simTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        temp += (rnd.nextDouble() - 0.48) * 0.8;
        hum += (rnd.nextDouble() - 0.5) * 1.5;
        volt += (rnd.nextDouble() - 0.5) * 0.05;

        // Feed into BLE service as if received from ESP32
        _ble.addLog("TEMP:${temp.toStringAsFixed(1)} HUM:${hum.toStringAsFixed(1)} VOLT:${volt.toStringAsFixed(2)}", MessageDirection.rx);
        _ble.telemetryData.putIfAbsent(
          "TEMP",
          () => TelemetrySeries(key: "TEMP", displayName: "Temperature", unit: "°C", colorValue: 0xFF00E5FF),
        ).addPoint(double.parse(temp.toStringAsFixed(1)));

        _ble.telemetryData.putIfAbsent(
          "HUM",
          () => TelemetrySeries(key: "HUM", displayName: "Humidity", unit: "%", colorValue: 0xFF00E676),
        ).addPoint(double.parse(hum.toStringAsFixed(1)));

        _ble.telemetryData.putIfAbsent(
          "VOLT",
          () => TelemetrySeries(key: "VOLT", displayName: "Voltage", unit: "V", colorValue: 0xFFFFB300),
        ).addPoint(double.parse(volt.toStringAsFixed(2)));

        _selectedKey ??= "TEMP";
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seriesList = _ble.telemetryData.values.toList();
    final activeSeries = _selectedKey != null && _ble.telemetryData.containsKey(_selectedKey)
        ? _ble.telemetryData[_selectedKey]
        : (seriesList.isNotEmpty ? seriesList.first : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Real-time Telemetry',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Auto-parses KEY:VAL, CSV, and numbers from serial stream',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: _isSimulating ? 'Stop Simulation' : 'Simulate Sensor Data',
                    icon: Icon(
                      _isSimulating ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                      color: _isSimulating ? AppTheme.accentRed : AppTheme.primaryCyan,
                    ),
                    onPressed: _toggleSimulation,
                  ),
                  IconButton(
                    tooltip: 'Clear Data',
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textSecondary),
                    onPressed: () {
                      _ble.clearTelemetry();
                      setState(() => _selectedKey = null);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Chart
          if (activeSeries != null && activeSeries.points.isNotEmpty)
            _buildChartCard(activeSeries)
          else
            _buildEmptyChartState(),

          const SizedBox(height: 18),

          // Live Metric Cards
          if (seriesList.isNotEmpty) ...[
            Text(
              'Active Telemetry Channels (${seriesList.length})',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
              ),
              itemCount: seriesList.length,
              itemBuilder: (context, index) {
                final s = seriesList[index];
                final isSelected = s.key == _selectedKey;
                final color = Color(s.colorValue);

                return InkWell(
                  onTap: () => setState(() => _selectedKey = s.key),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.12) : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : AppTheme.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.displayName,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PLOTTED',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              s.latestValue != null ? s.latestValue!.toStringAsFixed(2) : '--',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              s.unit,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Min: ${s.minValue?.toStringAsFixed(1) ?? '--'}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted),
                            ),
                            Text(
                              'Max: ${s.maxValue?.toStringAsFixed(1) ?? '--'}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartCard(TelemetrySeries series) {
    final spots = <FlSpot>[];
    for (int i = 0; i < series.points.length; i++) {
      spots.add(FlSpot(i.toDouble(), series.points[i].value));
    }

    final color = Color(series.colorValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${series.displayName} (${series.unit})',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${series.latestValue?.toStringAsFixed(2) ?? '--'} ${series.unit}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: ((series.maxValue ?? 10) - (series.minValue ?? 0)).abs() / 4 > 0
                        ? ((series.maxValue ?? 10) - (series.minValue ?? 0)).abs() / 4
                        : 1,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: AppTheme.cardBorder,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (val, meta) => Text(
                          val.toStringAsFixed(1),
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: color,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withValues(alpha: 0.3),
                            color.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChartState() {
    return Card(
      child: Container(
        height: 220,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No Telemetry Stream Detected',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'SOLink can send format: TEMP:25.4, HUM:60, or comma-separated values',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Test with Live Simulation'),
              onPressed: _toggleSimulation,
            ),
          ],
        ),
      ),
    );
  }
}
