import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/fleet_provider.dart';
import '../../config/app_config.dart';

class BusListScreen extends StatefulWidget {
  const BusListScreen({super.key});

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  String _search = '';
  String _statusFilter = 'all';
  bool _loading = false;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await context.read<FleetProvider>().loadBuses();
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> buses) {
    return buses.where((b) {
      final reg = (b['registration'] as String? ?? '').toLowerCase();
      final driver = (b['driver_name'] as String? ?? '').toLowerCase();
      final matchSearch = _search.isEmpty || reg.contains(_search) || driver.contains(_search);
      final status = b['status'] as String? ?? 'offline';
      final matchStatus = _statusFilter == 'all' || status == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final buses = _filtered(fleet.buses);

    return SafeArea(
      child: Column(
        children: [
          // ── Header ──
          _buildHeader(fleet.buses.length),

          // ── Search + Filter ──
          _buildSearchFilter(),

          // ── List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppConfig.primaryColor))
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppConfig.primaryColor,
                    backgroundColor: AppConfig.surfaceColor,
                    child: buses.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: buses.length,
                            itemBuilder: (_, i) => _BusTile(bus: buses[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        border: Border(bottom: BorderSide(color: AppConfig.primaryColor.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Buses',
                  style: TextStyle(color: AppConfig.textColor, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  '$total buses in fleet',
                  style: const TextStyle(color: AppConfig.mutedColor, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppConfig.primaryColor),
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilter() {
    final statuses = ['all', 'active', 'idle', 'offline', 'maintenance'];
    return Container(
      color: AppConfig.surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Search
          TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            style: const TextStyle(color: AppConfig.textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by registration or driver...',
              hintStyle: const TextStyle(color: AppConfig.mutedColor, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppConfig.mutedColor, size: 20),
              filled: true,
              fillColor: AppConfig.bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statuses.map((s) {
                final selected = _statusFilter == s;
                final color = _statusColor(s);
                return GestureDetector(
                  onTap: () => setState(() => _statusFilter = s),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.2) : AppConfig.bgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? color : AppConfig.primaryColor.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1),
                      style: TextStyle(
                        color: selected ? color : AppConfig.mutedColor,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(Icons.directions_bus, size: 64, color: AppConfig.mutedColor.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                _search.isNotEmpty ? 'No buses match "$_search"' : 'No buses found',
                style: const TextStyle(color: AppConfig.mutedColor, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active': return AppConfig.greenColor;
      case 'idle': return AppConfig.amberColor;
      case 'maintenance': return AppConfig.redColor;
      default: return AppConfig.mutedColor;
    }
  }
}

// ── Bus Tile ──────────────────────────────────────────────────────────────────

class _BusTile extends StatelessWidget {
  final Map<String, dynamic> bus;
  const _BusTile({required this.bus});

  Color get _statusColor {
    switch (bus['status'] as String? ?? 'offline') {
      case 'active': return AppConfig.greenColor;
      case 'idle': return AppConfig.amberColor;
      case 'maintenance': return AppConfig.redColor;
      default: return AppConfig.mutedColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reg = bus['registration'] as String? ?? '—';
    final driver = bus['driver_name'] as String? ?? 'No driver assigned';
    final route = bus['route_name'] as String? ?? 'No route';
    final status = bus['status'] as String? ?? 'offline';
    final qrCode = bus['qr_code'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConfig.primaryColor.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          // Main row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Status dot
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _statusColor.withOpacity(0.4), blurRadius: 4, spreadRadius: 1)],
                  ),
                ),
                // Bus info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            reg,
                            style: const TextStyle(color: AppConfig.textColor, fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: status, color: _statusColor),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        driver,
                        style: const TextStyle(color: AppConfig.mutedColor, fontSize: 12),
                      ),
                      if (route != 'No route')
                        Row(
                          children: [
                            const Icon(Icons.route, size: 11, color: AppConfig.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              route,
                              style: const TextStyle(color: AppConfig.primaryColor, fontSize: 11),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // QR button
                if (qrCode != null)
                  GestureDetector(
                    onTap: () => _showQrDialog(context, reg, qrCode),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppConfig.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppConfig.primaryColor.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.qr_code, color: AppConfig.primaryColor, size: 22),
                    ),
                  ),
              ],
            ),
          ),

          // Inline mini QR preview (collapsed by default, tap main QR button to see full)
          if (qrCode != null)
            _MiniQrPreview(qrCode: qrCode, reg: reg),
        ],
      ),
    );
  }

  void _showQrDialog(BuildContext context, String reg, String qrCode) {
    showDialog(
      context: context,
      builder: (_) => _QrFullDialog(registration: reg, qrCode: qrCode),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MiniQrPreview extends StatefulWidget {
  final String qrCode;
  final String reg;
  const _MiniQrPreview({required this.qrCode, required this.reg});

  @override
  State<_MiniQrPreview> createState() => _MiniQrPreviewState();
}

class _MiniQrPreviewState extends State<_MiniQrPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(height: 1, color: AppConfig.primaryColor.withOpacity(0.08)),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppConfig.mutedColor,
                ),
                const SizedBox(width: 6),
                Text(
                  _expanded ? 'Hide QR Code' : 'Show QR Code for driver pairing',
                  style: const TextStyle(color: AppConfig.mutedColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: widget.qrCode,
                    version: QrVersions.auto,
                    size: 150,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF050D1A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF050D1A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.reg,
                  style: const TextStyle(color: AppConfig.textColor, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const Text(
                  'Driver scans this to pair with bus',
                  style: TextStyle(color: AppConfig.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Full QR Dialog ────────────────────────────────────────────────────────────

class _QrFullDialog extends StatelessWidget {
  final String registration;
  final String qrCode;
  const _QrFullDialog({required this.registration, required this.qrCode});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppConfig.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        registration,
                        style: const TextStyle(color: AppConfig.textColor, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      const Text(
                        'Bus QR Code',
                        style: TextStyle(color: AppConfig.mutedColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppConfig.mutedColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // QR code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: qrCode,
                version: QrVersions.auto,
                size: 240,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF050D1A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF050D1A),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payload text
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConfig.bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      qrCode,
                      style: const TextStyle(
                        color: AppConfig.primaryColor,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    color: AppConfig.mutedColor,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: qrCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppConfig.primaryColor, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Driver scans this QR code to pair their mobile app with this bus.',
                      style: TextStyle(color: AppConfig.textColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
