import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ble_service.dart';
import '../services/provisioning_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aadhya_animated_logo.dart';
import '../widgets/bluetooth_status_banner.dart';
import '../widgets/theme_toggle_button.dart';
import 'mqtt_dashboard_screen.dart';

class ProvisioningScreen extends StatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends State<ProvisioningScreen> with SingleTickerProviderStateMixin {
  final ProvisioningService _prov = ProvisioningService.instance;
  final BleService _ble = BleService.instance;

  final TextEditingController _popController = TextEditingController(text: 'abcd1234');
  final TextEditingController _customSsidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscurePop = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _prov.addListener(_onProvUpdate);
    _ble.addListener(_onProvUpdate);

    // Initial scan with permissions
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hasPerm = await _ble.checkAndRequestPermissions();
      if (hasPerm) {
        _ble.startScan();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _popController.dispose();
    _customSsidController.dispose();
    _passwordController.dispose();
    _prov.removeListener(_onProvUpdate);
    _ble.removeListener(_onProvUpdate);
    super.dispose();
  }

  bool _wasBluetoothOn = false;

  void _onProvUpdate() {
    final nowOn = _ble.isBluetoothOn;
    if (!_wasBluetoothOn && nowOn && _prov.currentStep == ProvStep.deviceScan) {
      _ble.startScan();
    }
    _wasBluetoothOn = nowOn;
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // MAIN SCAFFOLD & APP BAR
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        leading: _prov.currentStep != ProvStep.deviceScan
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppTheme.getTextPrimary(context)),
                tooltip: 'Back',
                onPressed: _handleBackNavigation,
              )
            : null,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.getSurface(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.getPrimaryBorder(context), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.isDark(context) ? const Color(0x33000000) : const Color(0x140284C7),
                    blurRadius: 6,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: const AadhyaAnimatedLogo(
                size: 32,
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
                    'SOLink BLE Provisioning',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'SOLink Systems',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppTheme.getPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!_ble.isBluetoothOn)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: InkWell(
                onTap: () => _ble.turnOnBluetooth(),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bluetooth_disabled_rounded, size: 14, color: AppTheme.errorRed),
                      const SizedBox(width: 4),
                      Text(
                        'BT OFF',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Live Sensor Dashboard',
            icon: Icon(Icons.dashboard_customize_rounded, color: AppTheme.getPrimary(context)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MqttDashboardScreen()),
              );
            },
          ),
          if (_prov.currentStep == ProvStep.deviceScan) ...[
            IconButton(
              icon: _ble.isScanning
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.getPrimary(context)),
                    )
                  : Icon(Icons.refresh_rounded, color: AppTheme.getTextPrimary(context)),
              tooltip: _ble.isBluetoothOn ? 'Scan for Devices' : 'Turn ON Bluetooth',
              onPressed: () {
                if (!_ble.isBluetoothOn) {
                  _ble.turnOnBluetooth();
                } else {
                  _ble.startScan();
                }
              },
            ),
          ] else ...[
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppTheme.getTextSecondary(context)),
              tooltip: 'Reset Wizard',
              onPressed: () {
                _prov.reset();
                _ble.startScan();
              },
            ),
          ],
        ],
      ),
      body: AadhyaAnimatedBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildCurrentScreenContent(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.getSurface(context),
          boxShadow: [
            BoxShadow(
              color: AppTheme.isDark(context) ? const Color(0x33000000) : const Color(0x0D000000),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: _buildStepBreadcrumbs(),
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    switch (_prov.currentStep) {
      case ProvStep.securitySetup:
        _prov.reset();
        _ble.startScan();
        break;
      case ProvStep.wifiScan:
        _prov.currentStep = ProvStep.securitySetup;
        setState(() {});
        break;
      case ProvStep.enterCredentials:
        _prov.currentStep = ProvStep.wifiScan;
        setState(() {});
        break;
      case ProvStep.provisioning:
      case ProvStep.completed:
      case ProvStep.failed:
        _prov.reset();
        _ble.startScan();
        break;
      case ProvStep.deviceScan:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // STEP BREADCRUMBS INDICATOR
  // ---------------------------------------------------------------------------
  Widget _buildStepBreadcrumbs() {
    final steps = [
      {'name': 'Device', 'step': ProvStep.deviceScan},
      {'name': 'Security', 'step': ProvStep.securitySetup},
      {'name': 'Wi-Fi AP', 'step': ProvStep.wifiScan},
      {'name': 'Password', 'step': ProvStep.enterCredentials},
      {'name': 'Provision', 'step': ProvStep.provisioning},
    ];

    int activeIdx = 0;
    if (_prov.currentStep == ProvStep.securitySetup) activeIdx = 1;
    if (_prov.currentStep == ProvStep.wifiScan) activeIdx = 2;
    if (_prov.currentStep == ProvStep.enterCredentials) activeIdx = 3;
    if (_prov.currentStep == ProvStep.provisioning ||
        _prov.currentStep == ProvStep.completed ||
        _prov.currentStep == ProvStep.failed) {
      activeIdx = 4;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.getSurface(context),
        border: Border(top: BorderSide(color: AppTheme.getBorder(context))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (idx) {
          final isPast = idx < activeIdx;
          final isCurrent = idx == activeIdx;
          final name = steps[idx]['name'] as String;

          Color badgeBg = isCurrent
              ? AppTheme.getPrimary(context)
              : isPast
                  ? AppTheme.successGreen
                  : (AppTheme.isDark(context) ? AppTheme.darkCardElevated : AppTheme.cardBorder);

          Color textColor = isCurrent
              ? AppTheme.getPrimary(context)
              : isPast
                  ? AppTheme.successGreen
                  : AppTheme.getTextMuted(context);

          return Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent
                            ? AppTheme.getPrimary(context)
                            : isPast
                                ? AppTheme.successGreen
                                : AppTheme.getBorder(context),
                        width: 1.5,
                      ),
                    ),
                    child: isPast
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${idx + 1}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? (AppTheme.isDark(context) ? AppTheme.darkBg : Colors.white)
                                  : AppTheme.getTextSecondary(context),
                            ),
                          ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              if (idx < steps.length - 1)
                Container(
                  width: 24,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
                  color: isPast ? AppTheme.successGreen : AppTheme.getBorder(context),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SCREEN SWITCHER
  // ---------------------------------------------------------------------------
  Widget _buildCurrentScreenContent() {
    switch (_prov.currentStep) {
      case ProvStep.deviceScan:
        return _buildDeviceScanView();
      case ProvStep.securitySetup:
        return _buildSecuritySetupView();
      case ProvStep.wifiScan:
        return _buildWifiScanView();
      case ProvStep.enterCredentials:
        return _buildEnterCredentialsView();
      case ProvStep.provisioning:
      case ProvStep.completed:
      case ProvStep.failed:
        return _buildProvisioningStatusView();
    }
  }

  // ---------------------------------------------------------------------------
  // 1. DEVICE DISCOVERY VIEW (Official ESP BLE Provisioning Home Screen)
  // ---------------------------------------------------------------------------
  Widget _buildDeviceScanView() {
    final results = _ble.scanResults;
    final isBluetoothOff = !_ble.isBluetoothOn;

    return Column(
      children: [
        // Bluetooth State Warning Banner (visible when BT is off)
        const BluetoothStatusBanner(),

        // Scan Status Header (No prefix restriction)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.getSurface(context),
            border: Border(bottom: BorderSide(color: AppTheme.getBorder(context))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isBluetoothOff
                        ? Icons.bluetooth_disabled_rounded
                        : Icons.bluetooth_searching_rounded,
                    size: 18,
                    color: isBluetoothOff ? AppTheme.errorRed : AppTheme.getPrimary(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBluetoothOff ? 'Bluetooth Disabled' : 'Discovered Devices',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isBluetoothOff ? AppTheme.errorRed : AppTheme.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_ble.isScanning)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, _) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.getPrimary(context),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.getPrimary(context).withValues(alpha: 0.8),
                              blurRadius: 4 + _pulseController.value * 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Text(
                    isBluetoothOff
                        ? 'OFF'
                        : (_ble.isScanning ? 'Scanning...' : '${results.length} Discovered'),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isBluetoothOff
                          ? AppTheme.errorRed
                          : (_ble.isScanning
                              ? AppTheme.getPrimary(context)
                              : AppTheme.getTextSecondary(context)),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Device List or Empty State
        Expanded(
          child: isBluetoothOff
              ? _buildBluetoothOffHeroView()
              : (results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: AppTheme.getSurface(context),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.getPrimaryBorder(context), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.isDark(context) ? const Color(0x33000000) : const Color(0x140284C7),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: const AadhyaAnimatedLogo(
                                size: 90,
                                duration: Duration(seconds: 12),
                                showGlow: true,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Searching for Devices',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ensure your SOLink device is powered on, nearby and advertising BLE.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.getTextSecondary(context), height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _ble.startScan(),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Scan Again'),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _showQrCodeDialog,
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                              label: const Text('Scan Device QR Code'),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.getPrimary(context)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = results[index];
                        final name = item.device.platformName.isNotEmpty
                            ? item.device.platformName
                            : item.device.remoteId.str;
                        final rssi = item.rssi;

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.getSurface(context),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.getPrimaryBorder(context), width: 1.5),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: const AadhyaAnimatedLogo(
                                size: 40,
                                duration: Duration(seconds: 16),
                              ),
                            ),
                            title: Text(
                              name,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  item.device.remoteId.str,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.getTextSecondary(context)),
                                ),
                                const SizedBox(width: 8),
                                _buildRssiBadge(rssi),
                              ],
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.getPrimary(context),
                                foregroundColor: AppTheme.isDark(context) ? AppTheme.darkBg : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _prov.selectDevice(item.device),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Pair'),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 14),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )),
        ),
      ],
    );
  }

  /// Full-screen Hero view shown when phone Bluetooth is disabled
  Widget _buildBluetoothOffHeroView() {
    final isDark = AppTheme.isDark(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Bluetooth OFF Circle
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C1014) : const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.4 + _pulseController.value * 0.4),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.errorRed.withValues(alpha: 0.15 + _pulseController.value * 0.2),
                        blurRadius: 14 + _pulseController.value * 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: const Center(
                child: Icon(
                  Icons.bluetooth_disabled_rounded,
                  color: AppTheme.errorRed,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Bluetooth is Turned OFF',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your phone\'s Bluetooth is currently disabled. Please turn it on to discover and provision nearby SOLink BLE devices.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.getTextSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _ble.turnOnBluetooth(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.power_settings_new_rounded, size: 18),
              label: const Text('Turn ON Bluetooth'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _ble.openSettings(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.getTextPrimary(context),
                side: BorderSide(color: AppTheme.getBorder(context)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Open Phone Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRssiBadge(int rssi) {
    Color color = AppTheme.successGreen;
    if (rssi < -75) {
      color = AppTheme.errorRed;
    } else if (rssi < -60) {
      color = AppTheme.warningAmber;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.signal_cellular_alt_rounded, size: 13, color: color),
        const SizedBox(width: 2),
        Text(
          '$rssi dBm',
          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. SECURITY & PROOF OF POSSESSION (PoP) VIEW
  // ---------------------------------------------------------------------------
  Widget _buildSecuritySetupView() {
    final dev = _prov.targetDevice!;
    final isWorking = _prov.statusMessage.isNotEmpty &&
        (_prov.statusMessage.contains('Connecting') || _prov.statusMessage.contains('Handshaking'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security & Proof of Possession',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Establish an authenticated, encrypted BLE session with your SOLink device.',
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.getTextSecondary(context)),
          ),
          const SizedBox(height: 16),

          // Selected device details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.getSurface(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.getPrimaryBorder(context), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const AadhyaAnimatedLogo(
                      size: 40,
                      duration: Duration(seconds: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dev.platformName.isNotEmpty ? dev.platformName : 'SOLink Device',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          dev.remoteId.str,
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.getTextSecondary(context)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _prov.reset();
                      _ble.startScan();
                    },
                    child: Text('Change', style: TextStyle(color: AppTheme.getPrimary(context), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Security Mode Selector
          Text(
            'Select Security Protocol Scheme',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Security 1 (PoP Encrypted)'),
                  selected: _prov.securityType == 1,
                  selectedColor: AppTheme.getPrimarySoft(context),
                  checkmarkColor: AppTheme.getPrimary(context),
                  labelStyle: GoogleFonts.outfit(
                    color: _prov.securityType == 1 ? AppTheme.getPrimary(context) : AppTheme.getTextSecondary(context),
                    fontWeight: _prov.securityType == 1 ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _prov.securityType = 1);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Security 0 (Open)'),
                  selected: _prov.securityType == 0,
                  selectedColor: AppTheme.isDark(context) ? AppTheme.darkCardElevated : AppTheme.cardBorder,
                  labelStyle: GoogleFonts.outfit(
                    color: _prov.securityType == 0 ? AppTheme.getTextPrimary(context) : AppTheme.getTextSecondary(context),
                    fontWeight: _prov.securityType == 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _prov.securityType = 0);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // PoP Input (if Security 1)
          if (_prov.securityType == 1) ...[
            TextField(
              controller: _popController,
              obscureText: _obscurePop,
              style: GoogleFonts.jetBrainsMono(fontSize: 15, color: AppTheme.getTextPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Proof of Possession (PoP Key)',
                hintText: 'e.g. abcd1234',
                prefixIcon: Icon(Icons.key_rounded, color: AppTheme.getPrimary(context)),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePop ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePop = !_obscurePop),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Proof of Possession is configured in your firmware (e.g. pop = "abcd1234" in WiFiProv.beginProvision).',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.getTextSecondary(context)),
            ),
          ],

          if (_prov.errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _prov.errorMessage!,
                      style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.getTextPrimary(context)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.getPrimary(context),
              foregroundColor: AppTheme.isDark(context) ? AppTheme.darkBg : Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: isWorking
                ? null
                : () {
                    _prov.establishSession(
                      secType: _prov.securityType,
                      popKey: _popController.text.trim(),
                    );
                  },
            child: isWorking
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _prov.statusMessage,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : Text(
                    'Pair & Discover Wi-Fi Networks',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. WI-FI DISCOVERY VIEW (Official Espressif Wi-Fi List)
  // ---------------------------------------------------------------------------
  Widget _buildWifiScanView() {
    return Column(
      children: [
        // Subheader Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.getSurface(context),
            border: Border(bottom: BorderSide(color: AppTheme.getBorder(context))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Wi-Fi Network',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  Text(
                    '2.4 GHz networks detected by SOLink module',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.getTextSecondary(context)),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Re-scan Wi-Fi Networks',
                icon: _prov.isScanningWifi
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.getPrimary(context)),
                      )
                    : Icon(Icons.refresh_rounded, color: AppTheme.getPrimary(context)),
                onPressed: _prov.isScanningWifi ? null : () => _prov.scanWifiNetworks(),
              ),
            ],
          ),
        ),

        // Join hidden network button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: AppTheme.getTextPrimary(context),
              side: BorderSide(color: AppTheme.getBorder(context)),
            ),
            icon: Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.getPrimary(context)),
            label: const Text('Join Other / Hidden Network...'),
            onPressed: () => _prov.selectCustomNetwork(),
          ),
        ),

        // Scanned Networks List
        Expanded(
          child: _prov.isScanningWifi
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.getPrimary(context)),
                      const SizedBox(height: 16),
                      Text(
                        'SOLink is scanning 2.4GHz Wi-Fi channels...',
                        style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.getTextSecondary(context)),
                      ),
                    ],
                  ),
                )
              : _prov.wifiNetworks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 54, color: AppTheme.getTextSecondary(context).withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'No Wi-Fi Networks Found',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Make sure your Wi-Fi router is broadcasting 2.4GHz.',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.getTextMuted(context)),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () => _prov.scanWifiNetworks(),
                            child: const Text('Re-scan Networks'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _prov.wifiNetworks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ap = _prov.wifiNetworks[index];
                        final isSecure = ap.private;
                        final rssi = ap.rssi;

                        Color signalColor = AppTheme.successGreen;
                        if (rssi < -75) {
                          signalColor = AppTheme.errorRed;
                        } else if (rssi < -60) {
                          signalColor = AppTheme.warningAmber;
                        }

                        return Card(
                          child: ListTile(
                            onTap: () => _prov.selectWifiNetwork(ap),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: signalColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isSecure ? Icons.wifi_password_rounded : Icons.wifi_rounded,
                                color: signalColor,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              ap.ssid,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              '${isSecure ? "Secured (WPA2/WPA3)" : "Open"} • $rssi dBm',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.getTextSecondary(context)),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.getTextMuted(context)),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. ENTER CREDENTIALS VIEW
  // ---------------------------------------------------------------------------
  Widget _buildEnterCredentialsView() {
    final selectedAp = _prov.selectedWifi;
    final isHidden = selectedAp == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wi-Fi Credentials',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Provide the network passphrase so your SOLink module can connect.',
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.getTextSecondary(context)),
          ),
          const SizedBox(height: 16),

          // Selected Network Card
          if (!isHidden)
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.getPrimarySoft(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.wifi_rounded, color: AppTheme.getPrimary(context)),
                ),
                title: Text(
                  selectedAp.ssid,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  '${selectedAp.private ? "Secured Network" : "Open Network"} • ${selectedAp.rssi} dBm',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.getTextSecondary(context)),
                ),
                trailing: TextButton(
                  onPressed: () => setState(() => _prov.currentStep = ProvStep.wifiScan),
                  child: Text('Change', style: TextStyle(color: AppTheme.getPrimary(context))),
                ),
              ),
            )
          else
            TextField(
              controller: _customSsidController,
              style: GoogleFonts.outfit(fontSize: 15, color: AppTheme.getTextPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Network SSID (Name)',
                hintText: 'Enter Wi-Fi SSID',
                prefixIcon: Icon(Icons.wifi_rounded, color: AppTheme.getPrimary(context)),
              ),
            ),

          const SizedBox(height: 16),

          // Password Field
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.jetBrainsMono(fontSize: 15, color: AppTheme.getTextPrimary(context)),
            decoration: InputDecoration(
              labelText: 'Wi-Fi Password',
              hintText: 'Enter passphrase',
              prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.getPrimary(context)),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.getPrimary(context),
              foregroundColor: AppTheme.isDark(context) ? AppTheme.darkBg : Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () {
              final ssid = isHidden ? _customSsidController.text.trim() : selectedAp.ssid;
              final password = _passwordController.text;

              if (ssid.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please specify a network SSID')),
                );
                return;
              }

              _prov.startProvisioning(ssid: ssid, password: password);
            },
            child: Text(
              'Provision Device',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. PROVISIONING STATUS & VERIFICATION VIEW (Official 4-Step Checklist)
  // ---------------------------------------------------------------------------
  Widget _buildProvisioningStatusView() {
    final isSuccess = _prov.currentStep == ProvStep.completed;
    final isFailed = _prov.currentStep == ProvStep.failed;
    final isRunning = !isSuccess && !isFailed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Checklist Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fact_check_rounded, color: AppTheme.getPrimary(context), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Provisioning Progress',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildChecklistRow(
                    stepNum: 1,
                    title: 'Establish Session with Device',
                    status: _prov.stepSession,
                  ),
                  _buildChecklistDivider(),
                  _buildChecklistRow(
                    stepNum: 2,
                    title: 'Send Wi-Fi Credentials',
                    status: _prov.stepSendConfig,
                  ),
                  _buildChecklistDivider(),
                  _buildChecklistRow(
                    stepNum: 3,
                    title: 'Apply Wi-Fi Configuration',
                    status: _prov.stepApplyConfig,
                  ),
                  _buildChecklistDivider(),
                  _buildChecklistRow(
                    stepNum: 4,
                    title: 'Verify Connection & Get IP Address',
                    status: _prov.stepVerifyConnection,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Status Outcome
          if (isRunning) ...[
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, _) => Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.getPrimarySoft(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.getPrimary(context), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.getPrimary(context).withValues(alpha: 0.4 * _pulseController.value),
                      blurRadius: 14,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.getPrimary(context), strokeWidth: 3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Provisioning in Progress...',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _prov.statusMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.getTextSecondary(context)),
            ),
          ] else if (isSuccess) ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.successGreen, width: 2.5),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 50),
            ),
            const SizedBox(height: 16),
            Text(
              'Provisioning Successful!',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
            ),
            const SizedBox(height: 6),
            Text(
              'The SOLink module has joined your Wi-Fi network and is online.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 18),

            // Success Summary Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Assigned IPv4 Address:', style: GoogleFonts.outfit(color: AppTheme.getTextSecondary(context))),
                        Text(
                          _prov.assignedIp ?? '192.168.x.x',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: AppTheme.getBorder(context), height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Target Device:', style: GoogleFonts.outfit(color: AppTheme.getTextSecondary(context))),
                        Text(
                          _prov.targetDevice?.platformName ?? 'SOLink Device',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppTheme.getTextPrimary(context)),
                        ),
                      ],
                    ),
                    Divider(color: AppTheme.getBorder(context), height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Wi-Fi Network (SSID):', style: GoogleFonts.outfit(color: AppTheme.getTextSecondary(context))),
                        Text(
                          _prov.selectedWifi?.ssid ?? _customSsidController.text,
                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.getPrimary(context),
                foregroundColor: AppTheme.isDark(context) ? AppTheme.darkBg : Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.dashboard_rounded, size: 20),
              label: Text(
                'Open Live Sensor Dashboard',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MqttDashboardScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(color: AppTheme.getPrimaryBorder(context)),
                foregroundColor: AppTheme.getTextPrimary(context),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: () {
                _prov.reset();
                _ble.startScan();
              },
              label: const Text('Done / Provision Another Device'),
            ),
          ] else if (isFailed) ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.errorRed, width: 2.5),
              ),
              child: const Icon(Icons.cancel_rounded, color: AppTheme.errorRed, size: 50),
            ),
            const SizedBox(height: 16),
            Text(
              'Provisioning Failed',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.errorRed),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.5)),
              ),
              child: Text(
                _prov.errorMessage ?? 'Unknown failure occurred during provisioning.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.getTextPrimary(context)),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.getPrimary(context),
                foregroundColor: AppTheme.isDark(context) ? AppTheme.darkBg : Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => setState(() => _prov.currentStep = ProvStep.enterCredentials),
              child: const Text('Try Again / Re-enter Password'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: AppTheme.getTextPrimary(context),
                side: BorderSide(color: AppTheme.getBorder(context)),
              ),
              onPressed: () {
                _prov.reset();
                _ble.startScan();
              },
              child: const Text('Back to Device List'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistRow({
    required int stepNum,
    required String title,
    required StepStatus status,
  }) {
    Widget icon;
    Color textColor = AppTheme.getTextSecondary(context);

    switch (status) {
      case StepStatus.pending:
        icon = Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.getTextMuted(context), width: 1.5),
          ),
          child: Text(
            '$stepNum',
            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.getTextMuted(context), fontWeight: FontWeight.bold),
          ),
        );
        break;
      case StepStatus.inProgress:
        textColor = AppTheme.getPrimary(context);
        icon = SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.getPrimary(context)),
        );
        break;
      case StepStatus.success:
        textColor = AppTheme.getTextPrimary(context);
        icon = const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 22);
        break;
      case StepStatus.failed:
        textColor = AppTheme.errorRed;
        icon = const Icon(Icons.cancel_rounded, color: AppTheme.errorRed, size: 22);
        break;
    }

    return Row(
      children: [
        icon,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Container(width: 2, height: 16, color: AppTheme.getBorder(context)),
    );
  }

  // ---------------------------------------------------------------------------
  // DIALOGS: QR CODE
  // ---------------------------------------------------------------------------
  void _showQrCodeDialog() {
    final qrTextController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: AppTheme.getPrimary(context), size: 22),
            const SizedBox(width: 8),
            Text('Provisioning QR Code', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.getTextPrimary(context))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the QR code payload printed on your hardware or printed on your serial terminal.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qrTextController,
              maxLines: 3,
              style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppTheme.getTextPrimary(context)),
              decoration: const InputDecoration(
                hintText: '{"ver":"v1","name":"PROV_SOLink_IOT","pop":"abcd1234","transport":"ble"}',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('Sample Payload', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    qrTextController.text = '{"ver":"v1","name":"PROV_SOLink_IOT","pop":"abcd1234","transport":"ble"}';
                  },
                ),
                ActionChip(
                  label: const Text('Paste from Clipboard', style: TextStyle(fontSize: 11)),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      qrTextController.text = data!.text!;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.getPrimary(context),
              foregroundColor: AppTheme.isDark(context) ? AppTheme.darkBg : Colors.white,
            ),
            onPressed: () {
              final payload = qrTextController.text.trim();
              final parsed = _prov.parseQrPayload(payload);
              Navigator.of(ctx).pop();

              if (parsed != null && parsed['name']!.isNotEmpty) {
                final targetName = parsed['name']!.toLowerCase();
                final targetPop = parsed['pop'] ?? 'abcd1234';

                // Look for device in current BLE scan results
                final match = _ble.scanResults.where((r) =>
                    r.device.platformName.toLowerCase() == targetName ||
                    r.device.platformName.toLowerCase().contains(targetName)).firstOrNull;

                if (match != null) {
                  _popController.text = targetPop;
                  _prov.selectDevice(match.device, defaultPop: targetPop);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Found QR details for "${parsed['name']}", but device is not yet in BLE scan. Scanning...'),
                    ),
                  );
                  _ble.startScan();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid QR format. Expected JSON with "name" and "pop".')),
                );
              }
            },
            child: const Text('Parse & Pair'),
          ),
        ],
      ),
    );
  }
}
