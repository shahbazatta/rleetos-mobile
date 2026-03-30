import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../config/app_config.dart';
import '../alerts_screen.dart';
import 'bus_list_screen.dart';
import 'dispatch_screen.dart';

class SupervisorHomeScreen extends StatefulWidget {
  const SupervisorHomeScreen({super.key});

  @override
  State<SupervisorHomeScreen> createState() => _SupervisorHomeScreenState();
}

class _SupervisorHomeScreenState extends State<SupervisorHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    _SupervisorDashboard(),
    BusListScreen(),
    DispatchScreen(),
    AlertsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fleet = context.read<FleetProvider>();
      fleet.loadCurrentUser();
      fleet.loadBuses();
      fleet.loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.bgColor,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.directions_bus_outlined), activeIcon: Icon(Icons.directions_bus), label: 'Buses'),
      BottomNavigationBarItem(icon: Icon(Icons.qr_code_2_outlined), activeIcon: Icon(Icons.qr_code_2), label: 'Dispatch'),
      BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Alerts'),
    ];

    return Consumer<FleetProvider>(
      builder: (_, fleet, __) {
        final unread = fleet.alerts.where((a) => !(a['is_read'] as bool? ?? false)).length;
        return BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppConfig.surfaceColor,
          selectedItemColor: AppConfig.primaryColor,
          unselectedItemColor: AppConfig.mutedColor,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            items[0],
            items[1],
            items[2],
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
              activeIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications),
              ),
              label: 'Alerts',
            ),
          ],
        );
      },
    );
  }
}

// ── Supervisor Dashboard ───────────────────────────────────────────────────────

class _SupervisorDashboard extends StatefulWidget {
  const _SupervisorDashboard();

  @override
  State<_SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<_SupervisorDashboard> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final fleet = context.read<FleetProvider>();
    await Future.wait([fleet.loadBuses(), fleet.loadAlerts()]);
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final fleet = context.watch<FleetProvider>();
    final user = auth.user;

    final buses = fleet.buses;
    final active = buses.where((b) => b['status'] == 'active').length;
    final idle = buses.where((b) => b['status'] == 'idle').length;
    final offline = buses.where((b) => b['status'] == 'offline' || b['status'] == null).length;
    final maintenance = buses.where((b) => b['status'] == 'maintenance').length;
    final unreadAlerts = fleet.alerts.where((a) => !(a['is_read'] as bool? ?? false)).length;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: AppConfig.primaryColor,
        backgroundColor: AppConfig.surfaceColor,
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                          Text(
                            'Good ${_greeting()}, Supervisor',
                            style: const TextStyle(color: AppConfig.mutedColor, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?['full_name'] as String? ?? 'Supervisor',
                            style: const TextStyle(
                              color: AppConfig.textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Refresh button
                    IconButton(
                      onPressed: _refresh,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppConfig.primaryColor),
                            )
                          : const Icon(Icons.refresh, color: AppConfig.primaryColor),
                    ),
                    // Avatar
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppConfig.primaryColor.withOpacity(0.15),
                      child: Text(
                        _initials(user?['full_name'] as String? ?? 'S'),
                        style: const TextStyle(
                          color: AppConfig.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Fleet Stats ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FLEET STATUS',
                      style: TextStyle(
                        color: AppConfig.mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _StatCard(label: 'Total Buses', value: '${buses.length}', color: AppConfig.primaryColor, icon: Icons.directions_bus)),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(label: 'Active', value: '$active', color: AppConfig.greenColor, icon: Icons.play_circle_outline)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _StatCard(label: 'Idle', value: '$idle', color: AppConfig.amberColor, icon: Icons.pause_circle_outline)),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(label: 'Offline', value: '$offline', color: AppConfig.mutedColor, icon: Icons.offline_bolt_outlined)),
                      ],
                    ),
                    if (maintenance > 0) ...[
                      const SizedBox(height: 12),
                      _StatCard(
                        label: 'In Maintenance',
                        value: '$maintenance',
                        color: AppConfig.redColor,
                        icon: Icons.build_outlined,
                        fullWidth: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Alerts summary ──
            if (unreadAlerts > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConfig.redColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppConfig.redColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppConfig.redColor, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$unreadAlerts unread alert${unreadAlerts > 1 ? 's' : ''} require your attention',
                            style: const TextStyle(color: AppConfig.redColor, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppConfig.redColor),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Quick Actions ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QUICK ACTIONS',
                      style: TextStyle(
                        color: AppConfig.mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QuickAction(
                      icon: Icons.qr_code_2,
                      title: 'Generate Dispatch QR',
                      subtitle: 'Approve a driver\'s dispatch',
                      color: AppConfig.greenColor,
                      onTap: () {
                        // Navigate to dispatch tab via bottom nav
                        final state = context.findAncestorStateOfType<_SupervisorHomeScreenState>();
                        state?.setState(() => state._selectedIndex = 2);
                      },
                    ),
                    const SizedBox(height: 10),
                    _QuickAction(
                      icon: Icons.directions_bus,
                      title: 'View All Buses',
                      subtitle: 'See buses with QR codes & status',
                      color: AppConfig.primaryColor,
                      onTap: () {
                        final state = context.findAncestorStateOfType<_SupervisorHomeScreenState>();
                        state?.setState(() => state._selectedIndex = 1);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Recent buses on active trips ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BUSES ON ACTIVE TRIPS',
                      style: TextStyle(
                        color: AppConfig.mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (active == 0)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppConfig.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppConfig.primaryColor.withOpacity(0.08)),
                        ),
                        child: const Center(
                          child: Text(
                            'No active trips right now',
                            style: TextStyle(color: AppConfig.mutedColor, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ...buses
                          .where((b) => b['status'] == 'active')
                          .take(5)
                          .map((bus) => _ActiveBusTile(bus: bus)),
                  ],
                ),
              ),
            ),

            // ── Sign out ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: TextButton.icon(
                  onPressed: () => _confirmSignOut(context),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppConfig.mutedColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'S';
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppConfig.surfaceColor,
        title: const Text('Sign Out', style: TextStyle(color: AppConfig.textColor)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(color: AppConfig.mutedColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppConfig.mutedColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.redColor),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool fullWidth;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              Text(label, style: const TextStyle(color: AppConfig.mutedColor, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: card) : card;
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConfig.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppConfig.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(color: AppConfig.mutedColor, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppConfig.mutedColor),
          ],
        ),
      ),
    );
  }
}

class _ActiveBusTile extends StatelessWidget {
  final Map<String, dynamic> bus;
  const _ActiveBusTile({required this.bus});

  @override
  Widget build(BuildContext context) {
    final reg = bus['registration'] as String? ?? '—';
    final driver = bus['driver_name'] as String? ?? 'No driver';
    final route = bus['route_name'] as String? ?? 'No route';
    final speed = bus['current_speed'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConfig.greenColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppConfig.greenColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppConfig.greenColor.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reg, style: const TextStyle(color: AppConfig.textColor, fontWeight: FontWeight.w700, fontSize: 14)),
                Text('$driver • $route', style: const TextStyle(color: AppConfig.mutedColor, fontSize: 11)),
              ],
            ),
          ),
          if (speed != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${(speed as num).toStringAsFixed(0)} km/h',
                style: const TextStyle(color: AppConfig.primaryColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
