import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/quick_command.dart';
import '../services/ble_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';

class ControlsTab extends StatefulWidget {
  const ControlsTab({super.key});

  @override
  State<ControlsTab> createState() => _ControlsTabState();
}

class _ControlsTabState extends State<ControlsTab> {
  final BleService _ble = BleService.instance;
  List<QuickCommand> _quickCommands = [];
  bool _isLoading = true;

  // Relay states
  final List<bool> _relayStates = [false, false, false, false];
  bool _ledState = false;
  double _pwmValue = 128.0;

  @override
  void initState() {
    super.initState();
    _loadCommands();
  }

  Future<void> _loadCommands() async {
    final list = await PreferencesService.loadQuickCommands();
    if (mounted) {
      setState(() {
        _quickCommands = list;
        _isLoading = false;
      });
    }
  }

  void _send(String cmd) {
    _ble.sendCommand(cmd);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent: $cmd'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: AppTheme.surfaceDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddCommandDialog({QuickCommand? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final commandController = TextEditingController(text: existing?.command ?? '');
    int selectedColor = existing?.colorValue ?? 0xFF00E5FF;

    final availableColors = [
      0xFF00E5FF, // Cyan
      0xFF00E676, // Green
      0xFFFFB300, // Amber
      0xFFFF3D71, // Red
      0xFFB388FF, // Purple
      0xFF2979FF, // Blue
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.cardBorder),
              ),
              title: Text(
                existing == null ? 'Add Quick Command' : 'Edit Command',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Button Label',
                        hintText: 'e.g., MOTOR START',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commandController,
                      decoration: const InputDecoration(
                        labelText: 'Command Payload',
                        hintText: 'e.g., MOTOR:START',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Button Accent Color',
                        style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: availableColors.map((col) {
                        final isSelected = selectedColor == col;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = col),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(col),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2.5)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 18, color: Colors.black)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final t = titleController.text.trim();
                    final c = commandController.text.trim();
                    if (t.isEmpty || c.isEmpty) return;

                    if (existing == null) {
                      final newCmd = QuickCommand(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: t,
                        command: c,
                        colorValue: selectedColor,
                      );
                      _quickCommands.add(newCmd);
                    } else {
                      final index = _quickCommands.indexWhere((x) => x.id == existing.id);
                      if (index != -1) {
                        _quickCommands[index] = existing.copyWith(
                          title: t,
                          command: c,
                          colorValue: selectedColor,
                        );
                      }
                    }

                    await PreferencesService.saveQuickCommands(_quickCommands);
                    setState(() {});
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(existing == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteCommand(String id) async {
    _quickCommands.removeWhere((c) => c.id == id);
    await PreferencesService.saveQuickCommands(_quickCommands);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Digital Toggles & Relays
          _buildHardwareSwitchesSection(),
          const SizedBox(height: 18),

          // Section 2: Analog / PWM Control
          _buildPwmSection(),
          const SizedBox(height: 18),

          // Section 3: Momentary Action Button
          _buildMomentarySection(),
          const SizedBox(height: 18),

          // Section 4: Quick Action Command Grid
          _buildQuickCommandsSection(),
        ],
      ),
    );
  }

  Widget _buildHardwareSwitchesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.power_settings_new_rounded, color: AppTheme.primaryCyan, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Hardware Relays & Digital Pins',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Instant GPIO toggle switches with feedback',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const Divider(color: AppTheme.cardBorder, height: 24),

            // ESP32 Onboard LED (Pin 2)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_ledState ? AppTheme.accentGreen : AppTheme.textMuted).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: _ledState ? AppTheme.accentGreen : AppTheme.textMuted,
                ),
              ),
              title: Text('Built-in LED (GPIO 2)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _ledState ? 'State: HIGH (ON)' : 'State: LOW (OFF)',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondary),
              ),
              trailing: Switch.adaptive(
                value: _ledState,
                activeThumbColor: AppTheme.accentGreen,
                onChanged: (val) {
                  setState(() => _ledState = val);
                  _send(val ? 'LED:1' : 'LED:0');
                },
              ),
            ),

            const SizedBox(height: 8),

            // 4-Channel Relays Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.3,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                final relayNum = index + 1;
                final isOn = _relayStates[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _relayStates[index] = !isOn;
                    });
                    _send('RELAY:$relayNum:${!isOn ? 1 : 0}');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isOn ? AppTheme.primaryCyan.withValues(alpha: 0.12) : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isOn ? AppTheme.primaryCyan : AppTheme.cardBorder,
                        width: isOn ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOn ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                          color: isOn ? AppTheme.primaryCyan : AppTheme.textMuted,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Relay $relayNum',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isOn ? AppTheme.primaryCyan : AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              isOn ? 'ACTIVE' : 'OFF',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: isOn ? AppTheme.primaryCyan : AppTheme.textMuted,
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
          ],
        ),
      ),
    );
  }

  Widget _buildPwmSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppTheme.accentAmber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Analog / PWM Output',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${_pwmValue.toInt()} / 255',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentAmber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Control motor speed, LED brightness, or servo angle',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.accentAmber,
                thumbColor: AppTheme.accentAmber,
                overlayColor: AppTheme.accentAmber.withValues(alpha: 0.2),
                inactiveTrackColor: AppTheme.cardBorder,
              ),
              child: Slider(
                value: _pwmValue,
                min: 0,
                max: 255,
                divisions: 255,
                onChanged: (val) {
                  setState(() => _pwmValue = val);
                },
                onChangeEnd: (val) {
                  _send('PWM:${val.toInt()}');
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0% (0)', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
                Text('50% (128)', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
                Text('100% (255)', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMomentarySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.touch_app_rounded, color: AppTheme.accentPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Momentary Push Button',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Sends BTN:1 on touch down, and BTN:0 on release',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTapDown: (_) => _send('BTN:1'),
              onTapUp: (_) => _send('BTN:0'),
              onTapCancel: () => _send('BTN:0'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentPurple.withValues(alpha: 0.25),
                      AppTheme.accentPurple.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentPurple, width: 1.5),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.radio_button_checked, color: AppTheme.accentPurple, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'PRESS & HOLD TO TRIGGER',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCommandsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dashboard_customize_rounded, color: AppTheme.primaryCyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Custom Macro Buttons',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16, color: AppTheme.primaryCyan),
                  label: Text('New', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.primaryCyan)),
                  onPressed: () => _showAddCommandDialog(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to fire command; long-press to edit or delete',
              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: _quickCommands.length,
              itemBuilder: (context, index) {
                final cmd = _quickCommands[index];
                final color = Color(cmd.colorValue);

                return InkWell(
                  onTap: () => _send(cmd.command),
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: AppTheme.surfaceDark,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit, color: AppTheme.primaryCyan),
                              title: const Text('Edit Command'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _showAddCommandDialog(existing: cmd);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete, color: AppTheme.accentRed),
                              title: const Text('Delete Command'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _deleteCommand(cmd.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cmd.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cmd.command,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
