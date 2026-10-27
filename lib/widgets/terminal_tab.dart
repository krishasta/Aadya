import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/log_message.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class TerminalTab extends StatefulWidget {
  const TerminalTab({super.key});

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final BleService _ble = BleService.instance;

  String _filterQuery = '';
  final List<String> _sentHistory = [];

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onBleUpdate);
  }

  @override
  void dispose() {
    _ble.removeListener(_onBleUpdate);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onBleUpdate() {
    if (!mounted) return;
    setState(() {});
    if (_ble.autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _ble.sendCommand(text);
    if (!_sentHistory.contains(text)) {
      _sentHistory.insert(0, text);
      if (_sentHistory.length > 20) _sentHistory.removeLast();
    }
    _inputController.clear();
  }

  void _copyToClipboard(String content, String label) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppTheme.surfaceDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filterQuery.isEmpty
        ? _ble.logs
        : _ble.logs
            .where((m) =>
                m.text.toLowerCase().contains(_filterQuery.toLowerCase()) ||
                m.hexString.toLowerCase().contains(_filterQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        // Top Toolbar
        _buildToolbar(),

        // Search Bar (Optional collapsible or clean compact row)
        if (_filterQuery.isNotEmpty || _ble.logs.isNotEmpty) _buildSearchBar(),

        // Terminal Log Area
        Expanded(
          child: Container(
            color: AppTheme.consoleBg,
            child: filteredLogs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      return _buildLogItem(filteredLogs[index]);
                    },
                  ),
          ),
        ),

        // Quick Command Chips
        if (_sentHistory.isNotEmpty) _buildHistoryChips(),

        // Bottom Input Row
        _buildInputBar(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          // Packet stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_upward_rounded, size: 14, color: AppTheme.primaryCyan),
                Text(
                  ' ${_ble.totalBytesSent}B',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_downward_rounded, size: 14, color: AppTheme.accentGreen),
                Text(
                  ' ${_ble.totalBytesReceived}B',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Line Ending Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _ble.lineEnding,
              dropdownColor: AppTheme.cardDark,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.primaryCyan),
              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryCyan, size: 18),
              items: const [
                DropdownMenuItem(value: '\r\n', child: Text('CRLF (\\r\\n)')),
                DropdownMenuItem(value: '\n', child: Text('LF (\\n)')),
                DropdownMenuItem(value: '\r', child: Text('CR (\\r)')),
                DropdownMenuItem(value: '', child: Text('None')),
              ],
              onChanged: (val) {
                if (val != null) _ble.updateLineEnding(val);
              },
            ),
          ),
          const SizedBox(width: 4),

          // Hex View Toggle
          IconButton(
            tooltip: _ble.hexMode ? 'Switch to ASCII' : 'Switch to HEX',
            icon: Icon(
              Icons.code_rounded,
              color: _ble.hexMode ? AppTheme.accentAmber : AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: () => _ble.toggleHexMode(!_ble.hexMode),
          ),

          // Auto Scroll Toggle
          IconButton(
            tooltip: _ble.autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            icon: Icon(
              Icons.vertical_align_bottom_rounded,
              color: _ble.autoScroll ? AppTheme.primaryCyan : AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: () => _ble.toggleAutoScroll(!_ble.autoScroll),
          ),

          // Export Logs
          IconButton(
            tooltip: 'Export Logs',
            icon: const Icon(Icons.share_outlined, color: AppTheme.textSecondary, size: 20),
            onPressed: () {
              final logs = _ble.exportLogsAsText();
              _copyToClipboard(logs, 'Complete log');
            },
          ),

          // Clear Logs
          IconButton(
            tooltip: 'Clear Console',
            icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.accentRed, size: 20),
            onPressed: () {
              _ble.clearLogs();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: AppTheme.surfaceDark.withValues(alpha: 0.5),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Filter logs by text or hex...',
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (val) => setState(() => _filterQuery = val),
            ),
          ),
          if (_filterQuery.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _filterQuery = ''),
              child: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildLogItem(LogMessage msg) {
    Color dirColor;
    String dirBadge;
    IconData dirIcon;

    switch (msg.direction) {
      case MessageDirection.tx:
        dirColor = AppTheme.primaryCyan;
        dirBadge = "TX";
        dirIcon = Icons.arrow_upward_rounded;
        break;
      case MessageDirection.rx:
        dirColor = AppTheme.accentGreen;
        dirBadge = "RX";
        dirIcon = Icons.arrow_downward_rounded;
        break;
      case MessageDirection.system:
        dirColor = AppTheme.accentAmber;
        dirBadge = "SYS";
        dirIcon = Icons.info_outline;
        break;
      case MessageDirection.error:
        dirColor = AppTheme.accentRed;
        dirBadge = "ERR";
        dirIcon = Icons.error_outline;
        break;
    }

    final displayText = _ble.hexMode ? msg.hexString : msg.text.replaceAll('\r', '').replaceAll('\n', '');

    return InkWell(
      onLongPress: () => _copyToClipboard(displayText, 'Message text'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timestamp
            Text(
              msg.formattedTime,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 8),

            // Direction Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: dirColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: dirColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(dirIcon, size: 10, color: dirColor),
                  const SizedBox(width: 2),
                  Text(
                    dirBadge,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: dirColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Message Body
            Expanded(
              child: Text(
                displayText,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  color: dirColor,
                  fontWeight: msg.direction == MessageDirection.rx ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.terminal_rounded, size: 54, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'Serial Console Ready',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Commands sent and received from SOLink will appear here',
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryChips() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: AppTheme.surfaceDark,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _sentHistory.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cmd = _sentHistory[index];
          return ActionChip(
            backgroundColor: AppTheme.cardDark,
            side: const BorderSide(color: AppTheme.cardBorder),
            label: Text(
              cmd,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.primaryCyan),
            ),
            onPressed: () {
              _inputController.text = cmd;
            },
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    final canSend = _ble.writeCharacteristic != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                style: GoogleFonts.jetBrainsMono(fontSize: 13.5, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: canSend ? 'Type command (e.g. LED:1, STATUS, PING)...' : 'Connect to a BLE device first...',
                  hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                  prefixIcon: const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryCyan),
                  suffixIcon: _inputController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _inputController.clear()),
                        )
                      : null,
                ),
                onSubmitted: (_) => _handleSend(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryCyan, AppTheme.secondaryCyan],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.black),
                onPressed: canSend ? _handleSend : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
