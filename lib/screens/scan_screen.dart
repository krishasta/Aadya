import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ble_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aadhya_animated_logo.dart';
import '../widgets/bluetooth_status_banner.dart';
import '../widgets/theme_toggle_button.dart';
import 'device_screen.dart';
import '../widgets/esp32_firmware_tab.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final BleService _ble = BleService.instance;
  late AnimationController _radarController;
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';
  String? _lastDeviceId;
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _ble.addListener(_onBleUpdate);
    _loadLastDevice();

    // Auto start scan on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ble.startScan();
    });
  }

  Future<void> _loadLastDevice() async {
    final id = await PreferencesService.getLastDeviceId();
    if (mounted) setState(() => _lastDeviceId = id);
  }

  @override
  void dispose() {
    _radarController.dispose();
    _searchController.dispose();
    _ble.removeListener(_onBleUpdate);
    super.dispose();
  }

  void _onBleUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _handleConnect(BluetoothDevice device) async {
    setState(() => _connectingDeviceId = device.remoteId.str);

    final success = await _ble.connect(device);
    if (!mounted) return;

    setState(() => _connectingDeviceId = null);

    if (success) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeviceScreen(device: device),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId}'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter scan results
    final results = _ble.scanResults.where((r) {
      if (_searchFilter.isEmpty) return true;
      final name = r.device.platformName.toLowerCase();
      final id = r.device.remoteId.str.toLowerCase();
      final q = _searchFilter.toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bluetooth_searching_rounded, color: AppTheme.primaryCyan, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'SOLink BLE Connect',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'SOLink Firmware Code',
            icon: const Icon(Icons.code_rounded, color: AppTheme.primaryBlue),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('SOLink Firmware Code')),
                    body: const Esp32FirmwareTab(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: _ble.isScanning ? 'Stop Scan' : 'Scan for Devices',
            icon: _ble.isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryCyan),
                  )
                : const Icon(Icons.refresh_rounded, color: AppTheme.primaryCyan),
            onPressed: () {
              if (_ble.isScanning) {
                _ble.stopScan();
              } else {
                _ble.startScan();
              }
            },
          ),
        ],
      ),
      body: AadhyaAnimatedBackground(
        child: Column(
          children: [
            // Bluetooth State Alert (if off)
            const BluetoothStatusBanner(),

            // Search & Filter Bar
            _buildSearchBar(),

            // Scanning Radar Header / Device Count
            _buildScanStatusHeader(results.length),

            // Discovered Devices List
            Expanded(
              child: results.isEmpty
                  ? _buildEmptyScanState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return _buildDeviceCard(result);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryCyan,
        foregroundColor: Colors.black,
        icon: Icon(_ble.isScanning ? Icons.stop_rounded : Icons.search_rounded),
        label: Text(_ble.isScanning ? 'Stop Scan' : 'Scan BLE Devices'),
        onPressed: () {
          if (_ble.isScanning) {
            _ble.stopScan();
          } else {
            _ble.startScan();
          }
        },
      ),
    );
  }


  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppTheme.surfaceDark,
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Filter by device name (ESP32, UART) or MAC address...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryCyan, size: 20),
          suffixIcon: _searchFilter.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchFilter = '');
                  },
                )
              : null,
        ),
        onChanged: (val) => setState(() => _searchFilter = val),
      ),
    );
  }

  Widget _buildScanStatusHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.surfaceDark,
      child: Row(
        children: [
          if (_ble.isScanning)
            AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.8 - _radarController.value * 0.7),
                        blurRadius: 4 + _radarController.value * 8,
                        spreadRadius: _radarController.value * 6,
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 10),
          Text(
            _ble.isScanning ? 'Scanning for nearby BLE modules...' : 'Scan idle',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _ble.isScanning ? AppTheme.primaryCyan : AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '$count Found',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ScanResult result) {
    final device = result.device;
    final name = device.platformName.isNotEmpty ? device.platformName : 'Unknown BLE Device';
    final isEsp = name.toUpperCase().contains('SOLINK') || name.toUpperCase().contains('AADHYA') || name.toUpperCase().contains('AABS') || name.toUpperCase().contains('ESP') || name.toUpperCase().contains('UART') || name.toUpperCase().contains('IOT');
    final isLastConnected = _lastDeviceId == device.remoteId.str;
    final isConnecting = _connectingDeviceId == device.remoteId.str;
    final rssi = result.rssi;

    Color rssiColor;
    if (rssi >= -65) {
      rssiColor = AppTheme.accentGreen;
    } else if (rssi >= -80) {
      rssiColor = AppTheme.accentAmber;
    } else {
      rssiColor = AppTheme.accentRed;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Signal Strength & Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isEsp ? AppTheme.primaryCyan : AppTheme.surfaceDark).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEsp ? AppTheme.primaryCyan.withValues(alpha: 0.5) : AppTheme.cardBorder,
                ),
              ),
              child: Icon(
                isEsp ? Icons.memory_rounded : Icons.bluetooth_rounded,
                color: isEsp ? AppTheme.primaryCyan : AppTheme.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Device Name & ID
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isEsp ? AppTheme.primaryCyan : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (isLastConnected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RECENT',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentAmber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    device.remoteId.str,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Signal RSSI Badge
                  Row(
                    children: [
                      Icon(Icons.signal_cellular_alt_rounded, size: 14, color: rssiColor),
                      const SizedBox(width: 4),
                      Text(
                        '$rssi dBm',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: rssiColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (result.advertisementData.connectable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Connectable',
                            style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.accentGreen),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Connect Action Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEsp ? AppTheme.primaryCyan : AppTheme.cardBorder,
                foregroundColor: isEsp ? Colors.black : AppTheme.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: isConnecting ? null : () => _handleConnect(device),
              child: isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScanState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_ble.isScanning)
            const AadhyaAnimatedLogo(
              size: 80,
              duration: Duration(seconds: 12),
              showGlow: true,
            )
          else
            Icon(
              Icons.bluetooth_searching_rounded,
              size: 58,
              color: AppTheme.textSecondary.withValues(alpha: 0.35),
            ),
          const SizedBox(height: 16),
          Text(
            _ble.isScanning ? 'Searching for BLE devices...' : 'No Devices Found',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ensure your ESP32 is powered on and advertising',
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          if (!_ble.isScanning)
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Start Scanning'),
              onPressed: () => _ble.startScan(),
            ),
        ],
      ),
    );
  }
}
