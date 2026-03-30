import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../config/app_config.dart';
import 'qr_scan_screen.dart';
import '../alerts_screen.dart';
import 'route_map_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FleetProvider>()
        ..loadCurrentUser()
        ..loadAlerts()
        ..loadDriverRoute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final fleet = context.watch<FleetProvider>();
    final user = fleet.currentUser ?? auth.user ?? {};
    final unread = fleet.alerts.where((a) => a['is_read'] == false).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CloudNext Fleet',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          if (fleet.isTripActive)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppConfig.greenColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppConfig.greenColor.withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(color: AppConfig.greenColor, shape: BoxShape.circle),
                ),
                const Text(
                  'Trip Active',
                  style: TextStyle(
                    color: AppConfig.greenColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppConfig.mutedColor, size: 20),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _DriverDashboard(user: user),
          const RouteMapScreen(),
          const AlertsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        backgroundColor: AppConfig.surfaceColor,
        selectedItemColor: AppConfig.primaryColor,
        unselectedItemColor: AppConfig.mutedColor,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Route',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            activeIcon: const Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

class _DriverDashboard extends StatelessWidget {
  final Map<String, dynamic> user;
  const _DriverDashboard({required this.user});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final hasVehicle = fleet.currentUser?['vehicle_id'] != null;
    final reg = fleet.currentUser?['registration'] as String?;
    final routeName = fleet.currentUser?['route_name'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Driver info card
        _InfoCard(
          icon: Icons.person,
          color: AppConfig.primaryColor,
          title: user['full_name']?.toString() ?? 'Driver',
          subtitle: user['employee_id']?.toString() ?? user['email']?.toString() ?? '',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppConfig.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'DRIVER',
              style: TextStyle(
                color: AppConfig.primaryColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Bus status card
        _InfoCard(
          icon: Icons.directions_bus,
          color: hasVehicle ? AppConfig.greenColor : AppConfig.mutedColor,
          title: hasVehicle ? 'Bus ${reg ?? ""}' : 'No Bus Assigned',
          subtitle: hasVehicle
            ? (routeName != null ? 'Route: $routeName' : 'No route assigned')
            : 'Scan bus QR code to pair',
        ),
        const SizedBox(height: 24),

        // Action buttons
        const Text(
          'ACTIONS',
          style: TextStyle(
            fontSize: 11,
            color: AppConfig.mutedColor,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: Icons.qr_code_scanner,
          label: 'Scan Bus QR',
          subtitle: 'Pair with a bus',
          color: AppConfig.primaryColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QrScanScreen(mode: QrScanMode.pairBus)),
          ),
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: Icons.play_circle_outline,
          label: 'Scan Dispatch Approval',
          subtitle: 'Scan supervisor QR to start trip',
          color: AppConfig.greenColor,
          enabled: hasVehicle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QrScanScreen(mode: QrScanMode.dispatch)),
          ),
        ),
        const SizedBox(height: 10),
        if (fleet.isTripActive) ...[
          _ActionButton(
            icon: Icons.stop_circle_outlined,
            label: 'End Trip',
            subtitle: 'Mark current trip as completed',
            color: AppConfig.redColor,
            onTap: () => _confirmEndTrip(context, fleet),
          ),
          const SizedBox(height: 10),
        ],
        _ActionButton(
          icon: Icons.map_outlined,
          label: 'View Route',
          subtitle: hasVehicle && routeName != null ? routeName : 'No route assigned',
          color: AppConfig.amberColor,
          enabled: hasVehicle && fleet.currentRoute != null,
          onTap: () {
            if (fleet.currentRoute != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RouteMapScreen()));
            }
          },
        ),
      ]),
    );
  }

  void _confirmEndTrip(BuildContext context, FleetProvider fleet) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppConfig.surfaceColor,
        title: const Text(
          'End Trip?',
          style: TextStyle(color: AppConfig.textColor, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This will mark the current trip as completed.',
          style: TextStyle(color: AppConfig.mutedColor),
        ),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text('End Trip', style: TextStyle(color: AppConfig.redColor, fontWeight: FontWeight.w700)),
            onPressed: () async {
              Navigator.pop(context);
              await fleet.endTrip();
            },
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppConfig.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: const TextStyle(color: AppConfig.textColor, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          Text(subtitle, style: const TextStyle(color: AppConfig.mutedColor, fontSize: 12)),
        ]),
      ),
      if (trailing != null) trailing!,
    ]),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled ? color.withOpacity(0.08) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? color.withOpacity(0.25) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(children: [
        Icon(icon, color: enabled ? color : AppConfig.mutedColor, size: 26),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              label,
              style: TextStyle(
                color: enabled ? AppConfig.textColor : AppConfig.mutedColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(subtitle, style: const TextStyle(color: AppConfig.mutedColor, fontSize: 12)),
          ]),
        ),
        Icon(
          Icons.chevron_right,
          color: enabled ? AppConfig.mutedColor : Colors.white.withOpacity(0.1),
          size: 20,
        ),
      ]),
    ),
  );
}
