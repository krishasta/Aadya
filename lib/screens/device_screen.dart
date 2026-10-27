import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/terminal_tab.dart';
import '../widgets/controls_tab.dart';
import '../widgets/telemetry_tab.dart';
import '../widgets/services_tab.dart';
import '../widgets/esp32_firmware_tab.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BleService _ble = BleService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _ble.addListener(_onBleUpdate);
  }

  @override
  void dispose() {
    _ble.removeListener(_onBleUpdate);
    _tabController.dispose();
    super.dispose();
  }

  void _onBleUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _ble.connectionState == BluetoothConnectionState.connected;
    final deviceName = widget.device.platformName.isNotEmpty
        ? widget.device.platformName
        : widget.device.remoteId.str;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deviceName,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnected ? AppTheme.accentGreen : AppTheme.accentRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected ? 'CONNECTED' : 'DISCONNECTED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isConnected ? AppTheme.accentGreen : AppTheme.accentRed,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.device.remoteId.str,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (isConnected)
            TextButton.icon(
              icon: const Icon(Icons.link_off_rounded, size: 18, color: AppTheme.accentRed),
              label: Text(
                'Disconnect',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentRed,
                ),
              ),
              onPressed: () async {
                await _ble.disconnect();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.primaryCyan),
              label: Text(
                'Reconnect',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryCyan,
                ),
              ),
              onPressed: () => _ble.connect(widget.device),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(
              icon: Icon(Icons.terminal_rounded, size: 20),
              text: 'Terminal',
            ),
            Tab(
              icon: Icon(Icons.toggle_on_rounded, size: 20),
              text: 'Controls',
            ),
            Tab(
              icon: Icon(Icons.show_chart_rounded, size: 20),
              text: 'Telemetry',
            ),
            Tab(
              icon: Icon(Icons.hub_rounded, size: 20),
              text: 'GATT Services',
            ),
            Tab(
              icon: Icon(Icons.code_rounded, size: 20),
              text: 'ESP32 Code',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TerminalTab(),
          ControlsTab(),
          TelemetryTab(),
          ServicesTab(),
          Esp32FirmwareTab(),
        ],
      ),
    );
  }
}
