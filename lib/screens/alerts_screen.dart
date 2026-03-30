import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fleet_provider.dart';
import '../config/app_config.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<FleetProvider>().loadAlerts(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<FleetProvider>().alerts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FleetProvider>().loadAlerts(),
          ),
        ],
      ),
      body: alerts.isEmpty
        ? const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_off_outlined, size: 56, color: AppConfig.mutedColor),
              SizedBox(height: 16),
              Text(
                'No alerts',
                style: TextStyle(color: AppConfig.mutedColor, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ]),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (_, i) {
              final a = alerts[i];
              final severity = a['severity'] as String? ?? 'info';
              final color = severity == 'critical'
                ? AppConfig.redColor
                : severity == 'warning'
                  ? AppConfig.amberColor
                  : AppConfig.primaryColor;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppConfig.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              (a['type'] as String? ?? 'alert').replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(a['occurred_at'] as String?),
                            style: const TextStyle(color: AppConfig.mutedColor, fontSize: 10),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          a['message'] as String? ?? '',
                          style: const TextStyle(color: AppConfig.textColor, fontSize: 13),
                        ),
                        if (a['vehicle_registration'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Bus: ${a['vehicle_registration']}',
                            style: const TextStyle(color: AppConfig.mutedColor, fontSize: 11),
                          ),
                        ],
                      ]),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}
