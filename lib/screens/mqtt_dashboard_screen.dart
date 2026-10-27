import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/mqtt_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aadhya_animated_logo.dart';
import '../widgets/theme_toggle_button.dart';

class MqttDashboardScreen extends StatefulWidget {
  final bool autoConnect;

  const MqttDashboardScreen({
    super.key,
    this.autoConnect = true,
  });

  @override
  State<MqttDashboardScreen> createState() => _MqttDashboardScreenState();
}

class _MqttDashboardScreenState extends State<MqttDashboardScreen> with SingleTickerProviderStateMixin {
  final MqttService _mqtt = MqttService.instance;
  late TabController _tabController;
  Timer? _simulationTimer;
  bool _isSimulating = false;
  int _graphMetricIndex = 0; // 0: Temp & Humidity, 1: Particulate Matter (PM)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _mqtt.addListener(_onMqttUpdated);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _mqtt.init();
      if (widget.autoConnect && _mqtt.status == MqttStatus.disconnected) {
        _mqtt.connect();
      }
    });
  }

  void _onMqttUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _tabController.dispose();
    _mqtt.removeListener(_onMqttUpdated);
    super.dispose();
  }

  void _toggleSimulation() {
    setState(() {
      _isSimulating = !_isSimulating;
    });

    if (_isSimulating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live simulation mode activated with Sen62 sensor data!'),
          backgroundColor: AppTheme.primaryBlue,
          duration: Duration(seconds: 2),
        ),
      );
      _simulationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!_isSimulating) return;
        final now = DateTime.now();
        final ts = now.millisecondsSinceEpoch ~/ 1000;
        final variation = (now.second % 10) - 5;

        final simJson = {
          "timestamp": ts,
          "sensor": {
            "environment": "production",
            "plant": "unit1",
            "stage": "stage1",
            "deviceId": "DEV-0001",
          },
          "measurements": {
            "PM1": (35.7 + variation * 0.4).clamp(10.0, 100.0),
            "PM2_5": (40.5 + variation * 0.6).clamp(10.0, 150.0),
            "PM4": (43.1 + variation * 0.5).clamp(10.0, 150.0),
            "PM10": (44.4 + variation * 0.7).clamp(10.0, 200.0),
            "humidity": (65.8 + variation * 0.8).clamp(30.0, 95.0),
            "temperature": (28.6 + variation * 0.3).clamp(15.0, 45.0),
          }
        };

        _mqtt.injectReading(simJson, 'Sen62/Device0');
      });
    } else {
      _simulationTimer?.cancel();
      _simulationTimer = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Simulation mode stopped.'),
          backgroundColor: AppTheme.textSecondary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showBrokerConfigDialog() {
    final ipCtrl = TextEditingController(text: _mqtt.brokerIp);
    final portCtrl = TextEditingController(text: _mqtt.brokerPort.toString());
    final topicCtrl = TextEditingController(text: _mqtt.topic);
    final cmdTopicCtrl = TextEditingController(text: _mqtt.cmdTopic);
    final clientCtrl = TextEditingController(text: _mqtt.clientId);
    final userCtrl = TextEditingController(text: _mqtt.username);
    final passCtrl = TextEditingController(text: _mqtt.password);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.getSurface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.getPrimarySoft(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.settings_input_antenna_rounded, color: AppTheme.getPrimary(context), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Broker & Server Setup',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextPrimary(context),
                                ),
                              ),
                              Text(
                                'Configure server IP, telemetry & command topics',
                                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.getTextSecondary(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppTheme.getTextSecondary(context)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Host IP & Port
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: ipCtrl,
                          style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context)),
                          decoration: InputDecoration(
                            labelText: 'Broker Host / IP',
                            hintText: '98.130.58.226',
                            prefixIcon: const Icon(Icons.dns_rounded, size: 20),
                            suffixIcon: IconButton(
                              tooltip: 'Reset to Default (98.130.58.226)',
                              icon: const Icon(Icons.restore_rounded, size: 18),
                              onPressed: () => setModalState(() => ipCtrl.text = '98.130.58.226'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: portCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context)),
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '1883',
                            prefixIcon: Icon(Icons.tag_rounded, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Topic field
                  TextField(
                    controller: topicCtrl,
                    style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context)),
                    decoration: const InputDecoration(
                      labelText: 'Subscribe Topic (Telemetry)',
                      hintText: 'Sen62/#',
                      prefixIcon: Icon(Icons.topic_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Topic Preset Chips
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Sen62/# (All Sensors)'),
                        onPressed: () => setModalState(() => topicCtrl.text = 'Sen62/#'),
                      ),
                      ActionChip(
                        label: const Text('Sen62/Device0'),
                        onPressed: () => setModalState(() => topicCtrl.text = 'Sen62/Device0'),
                      ),
                      ActionChip(
                        label: const Text('solve/#'),
                        onPressed: () => setModalState(() => topicCtrl.text = 'solve/#'),
                      ),
                      ActionChip(
                        label: const Text('# (Wildcard)'),
                        onPressed: () => setModalState(() => topicCtrl.text = '#'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Command (Reset) Topic Field
                  TextField(
                    controller: cmdTopicCtrl,
                    style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Controller Command Topic (for Reset)',
                      hintText: 'Sen62/Device0/cmd',
                      prefixIcon: const Icon(Icons.send_rounded, size: 20),
                      suffixIcon: IconButton(
                        tooltip: 'Reset to default (Sen62/Device0/cmd)',
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        onPressed: () => setModalState(() => cmdTopicCtrl.text = 'Sen62/Device0/cmd'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Optional Auth Toggle / Fields
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Optional Authentication & Client ID',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getTextSecondary(context)),
                    ),
                    children: [
                      TextField(
                        controller: clientCtrl,
                        style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context)),
                        decoration: const InputDecoration(
                          labelText: 'Client ID',
                          prefixIcon: Icon(Icons.fingerprint_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: userCtrl,
                              style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context)),
                              decoration: const InputDecoration(
                                labelText: 'Username (Optional)',
                                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: passCtrl,
                              obscureText: true,
                              style: GoogleFonts.outfit(color: AppTheme.getTextPrimary(context)),
                              decoration: const InputDecoration(
                                labelText: 'Password (Optional)',
                                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(color: AppTheme.getBorder(context)),
                            foregroundColor: AppTheme.getTextPrimary(context),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.getPrimary(context),
                            foregroundColor: AppTheme.isDark(context) ? AppTheme.darkBg : Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: const Text('Save & Connect'),
                          onPressed: () async {
                            final ip = ipCtrl.text.trim();
                            final port = int.tryParse(portCtrl.text.trim()) ?? 1883;
                            final top = topicCtrl.text.trim();
                            final cmdTop = cmdTopicCtrl.text.trim();
                            final cl = clientCtrl.text.trim();
                            final u = userCtrl.text.trim();
                            final p = passCtrl.text.trim();

                            if (ip.isEmpty || top.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid IP address and topic.')),
                              );
                              return;
                            }

                            Navigator.pop(ctx);
                            await _mqtt.saveSettings(
                              ip: ip,
                              port: port,
                              newTopic: top,
                              newCmdTopic: cmdTop,
                              newClientId: cl,
                              user: u,
                              pass: p,
                            );
                            _mqtt.connect();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isResetting = false;

  Future<void> _handleResetDevice() async {
    if (_isResetting) return;

    final isConnected = _mqtt.status == MqttStatus.connected;
    if (!isConnected && !_isSimulating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot reset: Broker is not connected!'),
          backgroundColor: AppTheme.errorRed,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isResetting = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('Resetting device...'),
          ],
        ),
        duration: Duration(milliseconds: 700),
      ),
    );

    final sent = await _mqtt.sendResetDeviceCommand(
      command: 'RESET_WIFI',
      isSimulating: _isSimulating,
    );

    if (mounted) {
      setState(() => _isResetting = false);

      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Device reset successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reset device. Check broker connection.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _mqtt.status == MqttStatus.connected;
    final isConnecting = _mqtt.status == MqttStatus.connecting || _mqtt.status == MqttStatus.subscribing;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.getSurface(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.getPrimaryBorder(context), width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: const AadhyaAnimatedLogo(
                size: 28,
                duration: Duration(seconds: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SOLink Device Dashboard',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.getTextPrimary(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Host: ${_mqtt.brokerIp}:${_mqtt.brokerPort}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.getPrimary(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: _isSimulating ? 'Stop Simulation' : 'Start Simulation',
            icon: Icon(
              _isSimulating ? Icons.smart_toy_rounded : Icons.smart_toy_outlined,
              color: _isSimulating ? AppTheme.warningAmber : AppTheme.getTextSecondary(context),
            ),
            onPressed: _toggleSimulation,
          ),
          IconButton(
            tooltip: 'Configure Broker',
            icon: Icon(Icons.tune_rounded, color: AppTheme.getPrimary(context)),
            onPressed: _showBrokerConfigDialog,
          ),
          // Reset Button at Top
          Tooltip(
            message: 'Reset Controller',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _handleResetDevice,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isResetting) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.errorRed),
                      ),
                      const SizedBox(width: 4),
                    ] else ...[
                      const Icon(Icons.restart_alt_rounded, color: AppTheme.errorRed, size: 16),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _isResetting ? 'Resetting...' : 'Reset',
                      style: GoogleFonts.outfit(
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.getPrimary(context),
          indicatorWeight: 3,
          labelColor: AppTheme.getPrimary(context),
          unselectedLabelColor: AppTheme.getTextSecondary(context),
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 20), text: 'Sensors & Charts'),
            Tab(icon: Icon(Icons.terminal_rounded, size: 20), text: 'Live Feed & Logs'),
          ],
        ),
      ),
      body: AadhyaAnimatedBackground(
        child: Column(
          children: [
            _buildConnectionStatusBar(isConnected, isConnecting),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSensorsAndChartsTab(),
                  _buildMqttExplorerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusBar(bool isConnected, bool isConnecting) {
    Color bg;
    Color border;
    Color dotColor;
    String statusLabel;
    IconData icon;
    final isDark = AppTheme.isDark(context);

    if (isConnected) {
      bg = isDark ? const Color(0xFF062820) : const Color(0xFFECFDF5);
      border = isDark ? const Color(0xFF0D5E4D) : const Color(0xFFA7F3D0);
      dotColor = AppTheme.successGreen;
      statusLabel = 'Connected & Streaming';
      icon = Icons.wifi_tethering_rounded;
    } else if (isConnecting) {
      bg = isDark ? const Color(0xFF2D2005) : const Color(0xFFFFFBEB);
      border = isDark ? const Color(0xFF6B4E08) : const Color(0xFFFDE68A);
      dotColor = AppTheme.warningAmber;
      statusLabel = 'Connecting to ${_mqtt.brokerIp}...';
      icon = Icons.sync_rounded;
    } else if (_mqtt.status == MqttStatus.error) {
      bg = isDark ? const Color(0xFF2C0F13) : const Color(0xFFFEF2F2);
      border = isDark ? const Color(0xFF6B1D25) : const Color(0xFFFECACA);
      dotColor = AppTheme.errorRed;
      statusLabel = 'Connection Failed';
      icon = Icons.error_outline_rounded;
    } else {
      bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
      border = isDark ? const Color(0xFF223554) : const Color(0xFFCBD5E1);
      dotColor = isDark ? AppTheme.darkTextMuted : AppTheme.textMuted;
      statusLabel = 'Disconnected';
      icon = Icons.wifi_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: dotColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusLabel,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  kIsWeb
                      ? 'Web (Chrome) blocks raw TCP. Run on Android APK or Windows'
                      : 'Topic: ${_mqtt.topic} • ${_mqtt.messageCount} packets received',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.getTextSecondary(context)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isConnected) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.6), width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: _isResetting
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.errorRed),
                    )
                  : const Icon(Icons.restart_alt_rounded, size: 15),
              label: Text(_isResetting ? 'Resetting...' : 'Reset', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _isResetting ? null : _handleResetDevice,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.power_settings_new_rounded, size: 16),
              label: const Text('Disconnect', style: TextStyle(fontSize: 12)),
              onPressed: () => _mqtt.disconnect(),
            ),
          ]
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.getPrimary(context),
                foregroundColor: AppTheme.isDark(context) ? AppTheme.darkBg : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: isConnecting
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bolt_rounded, size: 16),
              label: Text(isConnecting ? 'Connecting' : 'Connect', style: const TextStyle(fontSize: 12)),
              onPressed: isConnecting ? null : () => _mqtt.connect(),
            ),
        ],
      ),
    );
  }

  Widget _buildSensorsAndChartsTab() {
    final data = _mqtt.currentData;

    return RefreshIndicator(
      onRefresh: () async {
        if (_mqtt.status == MqttStatus.disconnected) {
          await _mqtt.connect();
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // If no data received yet
          if (data == null)
            _buildEmptyDataPrompt()
          else ...[
            // 1. Device Metadata Bar (plant, stage, deviceId, env)
            _buildDeviceMetadataCard(data),
            const SizedBox(height: 16),

            // 2. Primary Gauges: Temperature & Humidity
            Row(
              children: [
                Expanded(
                  child: _buildMetricGauge(
                    title: 'Temperature',
                    value: '${data.temperature.toStringAsFixed(1)}°C',
                    subValue: 'Target: 20-30°C',
                    icon: Icons.thermostat_rounded,
                    gradientColors: [const Color(0xFFF97316), const Color(0xFFFB923C)],
                    badge: _getTemperatureStatus(data.temperature),
                    badgeColor: const Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricGauge(
                    title: 'Humidity',
                    value: '${data.humidity.toStringAsFixed(1)}%',
                    subValue: 'Optimal: 40-70%',
                    icon: Icons.water_drop_rounded,
                    gradientColors: [AppTheme.getPrimary(context), AppTheme.getPrimaryLight(context)],
                    badge: _getHumidityStatus(data.humidity),
                    badgeColor: AppTheme.getPrimary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Particulate Matter (PM) Grid (PM1, PM2.5, PM4, PM10)
            _buildSectionHeader('Particulate Matter (Sen62)', Icons.grain_rounded),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.22,
              children: [
                _buildPmCard('PM 1.0', data.pm1, 'Ultra-fine Dust', const Color(0xFF6366F1)),
                _buildPmCard('PM 2.5', data.pm25, 'Fine Particles', const Color(0xFF0284C7)),
                _buildPmCard('PM 4.0', data.pm4, 'Respirable Dust', const Color(0xFF0D9488)),
                _buildPmCard('PM 10', data.pm10, 'Coarse Dust', const Color(0xFFD97706)),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Interactive Live Charts
            _buildLiveChartCard(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyDataPrompt() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getCard(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.getBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.isDark(context) ? const Color(0x33000000) : const Color(0x0A000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.getPrimarySoft(context),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sensors_rounded, color: AppTheme.getPrimary(context), size: 48),
          ),
          const SizedBox(height: 18),
          Text(
            'Waiting for Sensor Data',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connected to ${_mqtt.brokerIp}:${_mqtt.brokerPort}.\nWaiting for publisher on topic "${_mqtt.topic}"...',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.getTextSecondary(context), height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Edit IP / Topic'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.getTextPrimary(context),
                  side: BorderSide(color: AppTheme.getBorder(context)),
                ),
                onPressed: _showBrokerConfigDialog,
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.getPrimary(context),
                  foregroundColor: AppTheme.isDark(context) ? AppTheme.darkBg : Colors.white,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Simulate Data'),
                onPressed: _toggleSimulation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceMetadataCard(MqttSensorData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.isDark(context) ? const Color(0x33000000) : const Color(0x080284C7),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.getPrimarySoft(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.memory_rounded, color: AppTheme.getPrimary(context), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensor: ${data.deviceId}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      'Topic: ${data.topic}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.getTextSecondary(context)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_mqtt.deviceStatus == 'resetting_wifi'
                          ? AppTheme.warningAmber
                          : (_isSimulating
                              ? AppTheme.warningAmber
                              : (_mqtt.isLiveData ? AppTheme.successGreen : AppTheme.getTextSecondary(context))))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_mqtt.deviceStatus == 'resetting_wifi'
                            ? AppTheme.warningAmber
                            : (_isSimulating
                                ? AppTheme.warningAmber
                                : (_mqtt.isLiveData ? AppTheme.successGreen : AppTheme.getTextSecondary(context))))
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _mqtt.deviceStatus == 'resetting_wifi'
                          ? Icons.restart_alt_rounded
                          : (_isSimulating
                              ? Icons.smart_toy_rounded
                              : (_mqtt.isLiveData ? Icons.wifi_tethering_rounded : Icons.sensors_off_rounded)),
                      color: _mqtt.deviceStatus == 'resetting_wifi'
                          ? AppTheme.warningAmber
                          : (_isSimulating
                              ? AppTheme.warningAmber
                              : (_mqtt.isLiveData ? AppTheme.successGreen : AppTheme.getTextSecondary(context))),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _mqtt.deviceStatus == 'resetting_wifi'
                          ? 'RESETTING WIFI'
                          : (_isSimulating
                              ? 'DEMO SIMULATION'
                              : (_mqtt.isLiveData ? 'LIVE BROKER DATA' : 'WAITING')),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _mqtt.deviceStatus == 'resetting_wifi'
                            ? AppTheme.warningAmber
                            : (_isSimulating
                                ? AppTheme.warningAmber
                                : (_mqtt.isLiveData ? AppTheme.successGreen : AppTheme.getTextSecondary(context))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 22, color: AppTheme.getBorder(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetaItem('Plant', data.plant, Icons.factory_outlined),
              _buildMetaItem('Stage', data.stage, Icons.layers_outlined),
              _buildMetaItem(
                'Last Sync',
                data.formattedTime.split(' ').length > 1
                    ? data.formattedTime.split(' ').sublist(1).join(' ')
                    : data.formattedTime,
                Icons.access_time_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.getTextMuted(context)),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.getTextMuted(context)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGauge({
    required String title,
    required String value,
    required String subValue,
    required IconData icon,
    required List<Color> gradientColors,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCard(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.getBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.isDark(context) ? const Color(0x33000000) : const Color(0x0A000000),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.getTextSecondary(context))),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(subValue, style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.getTextMuted(context))),
        ],
      ),
    );
  }

  Widget _buildPmCard(String label, double value, String desc, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.isDark(context) ? const Color(0x33000000) : const Color(0x06000000),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: accent),
              ),
              Text(
                'µg/m³',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.getTextMuted(context)),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context)),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 150.0).clamp(0.05, 1.0),
              backgroundColor: accent.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 5,
            ),
          ),
          Text(
            desc,
            style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.getTextMuted(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveChartCard() {
    final history = _mqtt.history;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCard(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.getBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.isDark(context) ? const Color(0x33000000) : const Color(0x0A000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart_rounded, color: AppTheme.getPrimary(context), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Real-time Trend',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Temp / Hum', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 1, label: Text('PM Levels', style: TextStyle(fontSize: 11))),
                ],
                selected: {_graphMetricIndex},
                onSelectionChanged: (set) => setState(() => _graphMetricIndex = set.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (history.length < 2)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'Collecting data points for graph...\n(${history.length}/2 received)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppTheme.getTextMuted(context), fontSize: 13),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _graphMetricIndex == 0 ? 10 : 25,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.getBorder(context).withValues(alpha: 0.7),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (val, _) => Text(
                          val.toInt().toString(),
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.getTextMuted(context)),
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: _graphMetricIndex == 0
                      ? [
                          // Temperature line (orange)
                          LineChartBarData(
                            spots: history
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value.temperature))
                                .toList(),
                            isCurved: true,
                            color: const Color(0xFFF97316),
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFFF97316).withValues(alpha: 0.1),
                            ),
                          ),
                          // Humidity line (primary)
                          LineChartBarData(
                            spots: history
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value.humidity))
                                .toList(),
                            isCurved: true,
                            color: AppTheme.getPrimary(context),
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.getPrimary(context).withValues(alpha: 0.1),
                            ),
                          ),
                        ]
                      : [
                          // PM2.5 line (primary)
                          LineChartBarData(
                            spots: history
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value.pm25))
                                .toList(),
                            isCurved: true,
                            color: AppTheme.getPrimary(context),
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                          // PM10 line (amber)
                          LineChartBarData(
                            spots: history
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value.pm10))
                                .toList(),
                            isCurved: true,
                            color: const Color(0xFFD97706),
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _graphMetricIndex == 0
                ? [
                    _buildLegendDot(const Color(0xFFF97316), 'Temperature (°C)'),
                    const SizedBox(width: 16),
                    _buildLegendDot(AppTheme.getPrimary(context), 'Humidity (%)'),
                  ]
                : [
                    _buildLegendDot(AppTheme.getPrimary(context), 'PM 2.5 (µg/m³)'),
                    const SizedBox(width: 16),
                    _buildLegendDot(const Color(0xFFD97706), 'PM 10 (µg/m³)'),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.getTextSecondary(context))),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.getPrimary(context)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context)),
        ),
      ],
    );
  }

  Widget _buildMqttExplorerTab() {
    final logs = _mqtt.logs;
    final current = _mqtt.currentData;

    final isDark = AppTheme.isDark(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Raw Payload Inspector (Current Message)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkConsoleBg : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.code_rounded, color: AppTheme.getPrimary(context), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Latest JSON Payload',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFFF8FAFC),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (current != null)
                    IconButton(
                      tooltip: 'Copy JSON',
                      icon: const Icon(Icons.copy_rounded, color: Color(0xFF94A3B8), size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: current.rawJson));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Raw JSON copied to clipboard!')),
                        );
                      },
                    ),
                ],
              ),
              const Divider(color: Color(0xFF1E293B), height: 16),
              if (current == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No payload received yet from ${_mqtt.topic}',
                      style: GoogleFonts.jetBrainsMono(color: const Color(0xFF64748B), fontSize: 12),
                    ),
                  ),
                )
              else
                SelectableText(
                  _prettyFormatJson(current.rawJson),
                  style: GoogleFonts.jetBrainsMono(
                    color: isDark ? AppTheme.darkPrimary : const Color(0xFF38BDF8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Controller Command Quick Action Card (MQTT Explorer Publish Bar)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.getCard(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restart_alt_rounded, color: AppTheme.errorRed, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Controller Command (RESET_WIFI)',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.getTextPrimary(context)),
                    ),
                    Text(
                      'Target: ${_mqtt.getEffectiveCmdTopic()}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.getTextSecondary(context)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Reset Device', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _handleResetDevice,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Packet History list
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Packet Log History (${logs.length})',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppTheme.getPrimary(context)),
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear Log', style: TextStyle(fontSize: 12)),
              onPressed: () => _mqtt.clearLogs(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (logs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.getCard(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Center(
              child: Text(
                'No packets logged yet.',
                style: GoogleFonts.outfit(color: AppTheme.getTextMuted(context)),
              ),
            ),
          )
        else
          ...logs.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.getCard(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: entry.isError ? AppTheme.errorRed.withValues(alpha: 0.3) : AppTheme.getBorder(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: entry.isError ? AppTheme.errorRed.withValues(alpha: 0.1) : AppTheme.getPrimarySoft(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.topic,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: entry.isError ? AppTheme.errorRed : AppTheme.getPrimary(context),
                          ),
                        ),
                      ),
                      Text(
                        entry.formattedTime,
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.getTextMuted(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.payload,
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.getTextSecondary(context)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _getTemperatureStatus(double temp) {
    if (temp < 18.0) return 'COOL';
    if (temp <= 28.0) return 'NORMAL';
    if (temp <= 34.0) return 'WARM';
    return 'HOT';
  }

  String _getHumidityStatus(double hum) {
    if (hum < 30.0) return 'DRY';
    if (hum <= 65.0) return 'COMFORT';
    return 'HUMID';
  }

  String _prettyFormatJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return jsonStr;
    }
  }
}
