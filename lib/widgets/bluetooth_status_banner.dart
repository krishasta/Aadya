import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

/// An animated status banner that indicates when Bluetooth is turned off on the phone,
/// providing an immediate one-tap "Turn ON" action and settings access.
class BluetoothStatusBanner extends StatefulWidget {
  final VoidCallback? onEnabled;

  const BluetoothStatusBanner({
    super.key,
    this.onEnabled,
  });

  @override
  State<BluetoothStatusBanner> createState() => _BluetoothStatusBannerState();
}

class _BluetoothStatusBannerState extends State<BluetoothStatusBanner>
    with SingleTickerProviderStateMixin {
  final BleService _ble = BleService.instance;
  late final AnimationController _pulseController;
  bool _isEnabling = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleTurnOn() async {
    if (_isEnabling) return;
    setState(() => _isEnabling = true);

    try {
      final success = await _ble.turnOnBluetooth();
      if (success) {
        widget.onEnabled?.call();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isEnabling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ble,
      builder: (context, _) {
        final isOff = !_ble.isBluetoothOn;

        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isOff
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.isDark(context)
                        ? const Color(0xFF2C1014)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.isDark(context)
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFFECACA),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Pulsing Bluetooth Disabled Icon
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withValues(
                                alpha: 0.15 + _pulseController.value * 0.15,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: child,
                          );
                        },
                        child: const Icon(
                          Icons.bluetooth_disabled_rounded,
                          color: AppTheme.errorRed,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Text Information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bluetooth is OFF',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.errorRed,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Turn ON Bluetooth to discover & connect to Aadhya devices.',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: AppTheme.getTextSecondary(context),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // One-Tap Turn ON Button
                      ElevatedButton(
                        onPressed: _isEnabling ? null : _handleTurnOn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isEnabling
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.power_settings_new_rounded, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Turn ON',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
