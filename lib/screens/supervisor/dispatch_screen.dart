import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/fleet_provider.dart';
import '../../config/app_config.dart';

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  String? _selectedVehicleId;
  String? _selectedDriverId;
  bool _generating = false;
  String? _generatedQr;
  String? _error;
  DateTime? _expiresAt;

  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final fleet = context.read<FleetProvider>();
    setState(() {
      _buses = fleet.buses;
      // Derive driver list from buses (paired drivers) + fallback
      _drivers = fleet.buses
          .where((b) => b['driver_id'] != null)
          .map((b) => {
                'id': b['driver_id'],
                'full_name': b['driver_name'] ?? 'Driver',
                'vehicle_id': b['id'],
              })
          .toList();
    });
  }

  Future<void> _generate() async {
    if (_selectedVehicleId == null || _selectedDriverId == null) {
      setState(() => _error = 'Please select both a bus and a driver.');
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
      _generatedQr = null;
    });

    try {
      final fleet = context.read<FleetProvider>();
      final result = await fleet.generateDispatchQr(_selectedVehicleId!, _selectedDriverId!);
      final qrPayload = result['qr_payload'] as String?;
      final expiresAt = result['expires_at'] as String?;

      setState(() {
        _generatedQr = qrPayload;
        _expiresAt = expiresAt != null ? DateTime.parse(expiresAt) : null;
        _generating = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _generating = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _generatedQr = null;
      _expiresAt = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    if (_buses.isEmpty && fleet.buses.isNotEmpty) {
      _buses = fleet.buses;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _buildHeader(),
            const SizedBox(height: 24),

            if (_generatedQr == null) ...[
              // ── Form ──
              _buildForm(),
            ] else ...[
              // ── QR display ──
              _buildQrDisplay(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dispatch Approval',
          style: TextStyle(
            color: AppConfig.textColor,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Generate a QR code for the driver to scan and start their trip',
          style: TextStyle(color: AppConfig.mutedColor, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // How it works info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppConfig.primaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppConfig.primaryColor.withOpacity(0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppConfig.primaryColor, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Select the bus and driver below, then generate a dispatch QR code. '
                  'The driver scans this code to officially start their trip. '
                  'The code expires in 10 minutes.',
                  style: TextStyle(color: AppConfig.textColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Vehicle selector
        const _SectionLabel(label: 'SELECT BUS'),
        const SizedBox(height: 8),
        _BusSelector(
          buses: _buses,
          selectedId: _selectedVehicleId,
          onChanged: (id) {
            setState(() {
              _selectedVehicleId = id;
              // Auto-select the driver assigned to this bus
              final bus = _buses.firstWhere((b) => b['id'] == id, orElse: () => {});
              if (bus['driver_id'] != null) {
                _selectedDriverId = bus['driver_id'] as String;
              }
            });
          },
        ),
        const SizedBox(height: 20),

        // Driver selector
        const _SectionLabel(label: 'SELECT DRIVER'),
        const SizedBox(height: 8),
        _DriverSelector(
          buses: _buses,
          selectedId: _selectedDriverId,
          onChanged: (id) => setState(() => _selectedDriverId = id),
        ),
        const SizedBox(height: 28),

        // Error
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppConfig.redColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConfig.redColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppConfig.redColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppConfig.redColor, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Generate button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_selectedVehicleId == null || _selectedDriverId == null || _generating)
                ? null
                : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.qr_code_2, size: 20),
            label: Text(_generating ? 'Generating...' : 'Generate Dispatch QR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.greenColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppConfig.surfaceColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrDisplay() {
    final timeLeft = _expiresAt != null
        ? _expiresAt!.difference(DateTime.now())
        : const Duration(minutes: 10);
    final minutesLeft = timeLeft.inMinutes;
    final isExpired = timeLeft.isNegative;

    return Column(
      children: [
        // Success header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConfig.greenColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppConfig.greenColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppConfig.greenColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dispatch QR Generated!',
                      style: TextStyle(
                        color: AppConfig.greenColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      isExpired
                          ? 'This QR code has expired'
                          : 'Expires in ~$minutesLeft minute${minutesLeft != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: isExpired ? AppConfig.redColor : AppConfig.mutedColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isExpired)
                TextButton(
                  onPressed: _reset,
                  child: const Text('Regenerate', style: TextStyle(color: AppConfig.primaryColor)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // QR code
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppConfig.greenColor.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: QrImageView(
            data: _generatedQr!,
            version: QrVersions.auto,
            size: 260,
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
        const SizedBox(height: 20),

        // Instruction
        const Text(
          'Show this QR code to the driver',
          style: TextStyle(
            color: AppConfig.textColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'The driver scans this code using their mobile app to start the trip',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppConfig.mutedColor, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // Expiry timer
        if (!isExpired)
          _ExpiryTimer(expiresAt: _expiresAt!),
        const SizedBox(height: 24),

        // New QR button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Generate New QR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppConfig.primaryColor,
              side: BorderSide(color: AppConfig.primaryColor.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bus Selector ──────────────────────────────────────────────────────────────

class _BusSelector extends StatelessWidget {
  final List<Map<String, dynamic>> buses;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _BusSelector({required this.buses, required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (buses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConfig.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConfig.primaryColor.withOpacity(0.1)),
        ),
        child: const Text('No buses found. Pull down to refresh.', style: TextStyle(color: AppConfig.mutedColor, fontSize: 13)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedId != null ? AppConfig.primaryColor.withOpacity(0.4) : AppConfig.primaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: buses.map((bus) {
          final id = bus['id'] as String;
          final reg = bus['registration'] as String? ?? '—';
          final status = bus['status'] as String? ?? 'offline';
          final driver = bus['driver_name'] as String? ?? 'No driver';
          final selected = selectedId == id;

          final statusColor = status == 'active'
              ? AppConfig.greenColor
              : status == 'idle'
                  ? AppConfig.amberColor
                  : AppConfig.mutedColor;

          return InkWell(
            onTap: () => onChanged(id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? AppConfig.primaryColor.withOpacity(0.08) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reg, style: const TextStyle(color: AppConfig.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(driver, style: const TextStyle(color: AppConfig.mutedColor, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppConfig.primaryColor, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Driver Selector ───────────────────────────────────────────────────────────

class _DriverSelector extends StatelessWidget {
  final List<Map<String, dynamic>> buses;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _DriverSelector({required this.buses, required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final driversWithBus = buses.where((b) => b['driver_id'] != null).toList();

    if (driversWithBus.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConfig.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConfig.primaryColor.withOpacity(0.1)),
        ),
        child: const Text('No drivers currently assigned to buses.', style: TextStyle(color: AppConfig.mutedColor, fontSize: 13)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedId != null ? AppConfig.greenColor.withOpacity(0.4) : AppConfig.primaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: driversWithBus.map((bus) {
          final driverId = bus['driver_id'] as String;
          final driverName = bus['driver_name'] as String? ?? 'Driver';
          final busReg = bus['registration'] as String? ?? '—';
          final selected = selectedId == driverId;

          return InkWell(
            onTap: () => onChanged(driverId),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? AppConfig.greenColor.withOpacity(0.08) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppConfig.greenColor.withOpacity(0.15),
                    child: Text(
                      driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                      style: const TextStyle(color: AppConfig.greenColor, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driverName, style: const TextStyle(color: AppConfig.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Bus: $busReg', style: const TextStyle(color: AppConfig.mutedColor, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppConfig.greenColor, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Expiry Timer ──────────────────────────────────────────────────────────────

class _ExpiryTimer extends StatefulWidget {
  final DateTime expiresAt;
  const _ExpiryTimer({required this.expiresAt});

  @override
  State<_ExpiryTimer> createState() => _ExpiryTimerState();
}

class _ExpiryTimerState extends State<_ExpiryTimer> {
  late final Stream<Duration> _stream;

  @override
  void initState() {
    super.initState();
    _stream = Stream.periodic(const Duration(seconds: 1), (_) {
      return widget.expiresAt.difference(DateTime.now());
    }).takeWhile((d) => !d.isNegative);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: _stream,
      initialData: widget.expiresAt.difference(DateTime.now()),
      builder: (_, snap) {
        final d = snap.data ?? Duration.zero;
        final isExpired = d.isNegative || d == Duration.zero;
        final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
        final color = d.inSeconds < 60 ? AppConfig.redColor : AppConfig.amberColor;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                isExpired ? 'QR Code Expired' : 'Expires in $minutes:$seconds',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppConfig.mutedColor,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
