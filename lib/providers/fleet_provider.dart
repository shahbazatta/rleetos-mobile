import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class FleetProvider extends ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _buses = [];
  Map<String, dynamic>? _currentRoute;
  bool _isLoading = false;
  String? _error;

  // Trip state
  String? _activeTripId;
  String? _assignedVehicleId;
  bool _isTripActive = false;
  Timer? _gpsTimer;

  Map<String, dynamic>? get currentUser => _currentUser;
  List<Map<String, dynamic>> get alerts => _alerts;
  List<Map<String, dynamic>> get buses => _buses;
  Map<String, dynamic>? get currentRoute => _currentRoute;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get activeTripId => _activeTripId;
  String? get assignedVehicleId => _assignedVehicleId;
  bool get isTripActive => _isTripActive;

  void updateToken(String? token) {
    ApiService.setToken(token);
  }

  Future<void> loadCurrentUser() async {
    try {
      final data = await ApiService.get('/mobile/me');
      _currentUser = data['user'] as Map<String, dynamic>;
      _assignedVehicleId = _currentUser?['vehicle_id'] as String?;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadAlerts() async {
    try {
      final data = await ApiService.get('/mobile/alerts');
      _alerts = List<Map<String, dynamic>>.from(data['alerts'] as List);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadBuses() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.get('/mobile/supervisor/buses');
      _buses = List<Map<String, dynamic>>.from(data['buses'] as List);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadDriverRoute() async {
    try {
      final data = await ApiService.get('/mobile/driver/route');
      _currentRoute = data['route'] as Map<String, dynamic>;
      notifyListeners();
    } catch (_) {}
  }

  // ── Driver: Pair with bus via QR ─────────────────────────────
  Future<Map<String, dynamic>> pairWithBus(String qrCode) async {
    final data = await ApiService.post('/mobile/pair-bus', {'qr_code': qrCode});
    final vehicle = data['vehicle'] as Map<String, dynamic>;
    _assignedVehicleId = vehicle['id'] as String;
    _currentUser = {...?_currentUser, 'vehicle_id': _assignedVehicleId};
    notifyListeners();
    // Load route for new vehicle
    await loadDriverRoute();
    return data;
  }

  // ── Driver: Scan dispatch QR to start trip ────────────────────
  Future<Map<String, dynamic>> approveDispatch(String qrPayload) async {
    if (_assignedVehicleId == null) {
      throw const ApiException('You must be paired with a bus first');
    }
    final data = await ApiService.post('/mobile/dispatch/approve', {
      'qr_payload': qrPayload,
      'vehicle_id': _assignedVehicleId,
    });
    _activeTripId = data['trip_id'] as String;
    _isTripActive = true;
    notifyListeners();
    _startGpsTracking();
    return data;
  }

  // ── GPS Tracking (every 30 sec) ───────────────────────────────
  void _startGpsTracking() {
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendGpsUpdate());
    _sendGpsUpdate(); // immediate first update
  }

  void stopGpsTracking() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  Future<void> _sendGpsUpdate() async {
    if (_assignedVehicleId == null) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) return;
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      // final pos = await Geolocator.getCurrentPosition(
      //   locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      // );
      await ApiService.post('/mobile/telemetry', {
        'vehicle_id': _assignedVehicleId,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed': pos.speed * 3.6, // m/s → km/h
        'heading': pos.heading,
        'engine_on': true,
      });
    } catch (_) {}
  }

  // ── Driver: End trip ─────────────────────────────────────────
  Future<void> endTrip() async {
    if (_activeTripId == null || _assignedVehicleId == null) return;
    await ApiService.post('/mobile/trip/end', {
      'trip_id': _activeTripId,
      'vehicle_id': _assignedVehicleId,
    });
    _activeTripId = null;
    _isTripActive = false;
    stopGpsTracking();
    notifyListeners();
  }

  // ── Supervisor: Generate dispatch QR ─────────────────────────
  Future<Map<String, dynamic>> generateDispatchQr(String vehicleId, String driverId) async {
    return await ApiService.post('/mobile/dispatch/generate', {
      'vehicle_id': vehicleId,
      'driver_id': driverId,
    });
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }
}
