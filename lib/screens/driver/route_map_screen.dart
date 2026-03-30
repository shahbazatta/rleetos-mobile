import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/fleet_provider.dart';
import '../../config/app_config.dart';

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  late final MapController _mapController;
  List<LatLng> _routePoints = [];
  bool _loading = true;
  String? _error;
  String _routeName = 'My Route';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoute());
  }

  Future<void> _loadRoute() async {
    final fleet = context.read<FleetProvider>();
    try {
      await fleet.loadDriverRoute();
      final route = fleet.currentRoute;
      if (route == null) {
        setState(() {
          _error = 'No route assigned to your bus yet.';
          _loading = false;
        });
        return;
      }

      _routeName = route['name'] as String? ?? 'My Route';

      // Parse GeoJSON LineString coordinates
      final pathGeoJson = route['path_geojson'];
      List<LatLng> points = [];

      if (pathGeoJson != null) {
        final coords = pathGeoJson['coordinates'] as List<dynamic>?;
        if (coords != null) {
          for (final c in coords) {
            final lng = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            points.add(LatLng(lat, lng));
          }
        }
      }

      setState(() {
        _routePoints = points;
        _loading = false;
      });

      // Fit map to route bounds
      if (points.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds(points));
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat - 0.005, minLng - 0.005),
      LatLng(maxLat + 0.005, maxLng + 0.005),
    );
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.bgColor,
      appBar: AppBar(
        backgroundColor: AppConfig.surfaceColor,
        foregroundColor: AppConfig.textColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _routeName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            if (_routePoints.isNotEmpty)
              Text(
                '${_routePoints.length} waypoints',
                style: const TextStyle(fontSize: 11, color: AppConfig.mutedColor),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_routePoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.fit_screen_outlined),
              tooltip: 'Fit to route',
              onPressed: () => _fitBounds(_routePoints),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
                _routePoints = [];
              });
              _loadRoute();
            },
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildMap(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppConfig.primaryColor),
          SizedBox(height: 16),
          Text(
            'Loading route...',
            style: TextStyle(color: AppConfig.mutedColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route, size: 64, color: AppConfig.mutedColor.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppConfig.mutedColor, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadRoute();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final startPoint = _routePoints.isNotEmpty ? _routePoints.first : null;
    final endPoint = _routePoints.length > 1 ? _routePoints.last : null;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: startPoint ?? const LatLng(31.5204, 74.3587),
            initialZoom: 13,
          ),
          children: [
            // OSM Tile Layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.cloudnext.fleet.driver',
            ),

            // Route polyline
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: AppConfig.primaryColor,
                    strokeWidth: 4.5,
                  ),
                  // Outer glow effect
                  Polyline(
                    points: _routePoints,
                    color: AppConfig.primaryColor.withOpacity(0.2),
                    strokeWidth: 10,
                  ),
                ],
              ),

            // Markers: start (green) + end (red)
            MarkerLayer(
              markers: [
                if (startPoint != null)
                  Marker(
                    point: startPoint,
                    width: 36,
                    height: 36,
                    child: const _RouteMarker(
                      color: AppConfig.greenColor,
                      label: 'A',
                    ),
                  ),
                if (endPoint != null)
                  Marker(
                    point: endPoint,
                    width: 36,
                    height: 36,
                    child: const _RouteMarker(
                      color: AppConfig.redColor,
                      label: 'B',
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Legend overlay
        Positioned(
          bottom: 24,
          left: 16,
          child: _MapLegend(
            routeName: _routeName,
            waypoints: _routePoints.length,
          ),
        ),
      ],
    );
  }
}

class _RouteMarker extends StatelessWidget {
  final Color color;
  final String label;
  const _RouteMarker({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  final String routeName;
  final int waypoints;
  const _MapLegend({required this.routeName, required this.waypoints});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConfig.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 20, height: 3, color: AppConfig.primaryColor),
            const SizedBox(width: 8),
            Text(
              routeName,
              style: const TextStyle(
                color: AppConfig.textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const _LegendDot(color: AppConfig.greenColor, label: 'Start'),
            const SizedBox(width: 12),
            const _LegendDot(color: AppConfig.redColor, label: 'End'),
            const SizedBox(width: 12),
            Text(
              '$waypoints pts',
              style: const TextStyle(color: AppConfig.mutedColor, fontSize: 11),
            ),
          ]),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: AppConfig.mutedColor, fontSize: 11)),
    ]);
  }
}
