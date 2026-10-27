import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  final BleService _ble = BleService.instance;

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _ble.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_ble.discoveredServices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings_bluetooth_rounded, size: 54, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No Services Discovered Yet',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Discover GATT Services'),
              onPressed: () => _ble.discoverAndConfigureServices(),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Serial Mapping Card
          _buildActiveMappingCard(),
          const SizedBox(height: 16),

          Text(
            'Discovered GATT Services (${_ble.discoveredServices.length})',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Set as TX" or "Set as RX" to route terminal data through any characteristic',
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ble.discoveredServices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final service = _ble.discoveredServices[index];
              return _buildServiceCard(service);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMappingCard() {
    final txChar = _ble.writeCharacteristic;
    final rxChar = _ble.notifyCharacteristic;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_rounded, color: AppTheme.primaryCyan, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Active Serial Communication Pipeline',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(color: AppTheme.cardBorder, height: 20),

            // TX Pipeline
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'TX (Write)',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryCyan,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    txChar != null
                        ? txChar.uuid.str128
                        : 'Not assigned (Select writable characteristic below)',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: txChar != null ? AppTheme.textPrimary : AppTheme.accentRed,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // RX Pipeline
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'RX (Notify)',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rxChar != null
                        ? rxChar.uuid.str128
                        : 'Not assigned (Select notify characteristic below)',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: rxChar != null ? AppTheme.textPrimary : AppTheme.accentRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(BluetoothService service) {
    final sUuid = service.uuid.str128;
    final isNus = sUuid.toLowerCase().contains("6e400001");

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isNus ? Icons.speed_rounded : Icons.folder_open_rounded,
                  color: isNus ? AppTheme.accentGreen : AppTheme.primaryCyan,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isNus ? 'Nordic UART Service (NUS)' : 'Service',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isNus ? AppTheme.accentGreen : AppTheme.textPrimary,
                            ),
                          ),
                          if (isNus) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'RECOMMENDED',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        sUuid,
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: AppTheme.cardBorder, height: 20),

            // Characteristics list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: service.characteristics.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, cIdx) {
                final c = service.characteristics[cIdx];
                return _buildCharacteristicRow(c);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacteristicRow(BluetoothCharacteristic c) {
    final isCurrentTx = _ble.writeCharacteristic?.uuid == c.uuid;
    final isCurrentRx = _ble.notifyCharacteristic?.uuid == c.uuid;
    final canWrite = c.properties.write || c.properties.writeWithoutResponse;
    final canNotify = c.properties.notify || c.properties.indicate;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isCurrentTx || isCurrentRx) ? AppTheme.primaryCyan : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.uuid.str128,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isCurrentTx)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ACTIVE TX',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              if (isCurrentRx)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ACTIVE RX',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Property Chips
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (c.properties.read) _buildPropBadge('READ', AppTheme.primaryCyan),
              if (c.properties.write) _buildPropBadge('WRITE', AppTheme.accentGreen),
              if (c.properties.writeWithoutResponse) _buildPropBadge('WRITE NO RESP', AppTheme.accentGreen),
              if (c.properties.notify) _buildPropBadge('NOTIFY', AppTheme.accentAmber),
              if (c.properties.indicate) _buildPropBadge('INDICATE', AppTheme.accentAmber),
            ],
          ),

          const SizedBox(height: 8),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (canWrite && !isCurrentTx)
                TextButton.icon(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                  label: const Text('Set as TX'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryCyan,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    _ble.setManualCharacteristics(write: c);
                  },
                ),
              if (canNotify && !isCurrentRx)
                TextButton.icon(
                  icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                  label: const Text('Set as RX'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentGreen,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    _ble.setManualCharacteristics(notify: c);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPropBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
