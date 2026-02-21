import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../api/taxi_api_client.dart';
import '../core/colors.dart';
import '../i18n/app_i18n.dart';
import '../models/app_role.dart';
import '../models/auth_session.dart';
import '../models/backend_order.dart';
import '../models/route_snapshot.dart';
import '../models/tariff.dart';
import '../widgets/map_backdrop.dart';

enum ClientFlowStep { home, searching, tracking, completed }

class ClientFlowPage extends StatefulWidget {
  const ClientFlowPage({
    required this.apiClient,
    required this.session,
    required this.lang,
    super.key,
  });

  final TaxiApiClient apiClient;
  final AuthSession session;
  final AppLang lang;

  @override
  State<ClientFlowPage> createState() => _ClientFlowPageState();
}

class _ClientFlowPageState extends State<ClientFlowPage> {
  static const _fallbackPickup = LatLng(43.238949, 76.889709);
  static const _fallbackDropoff = LatLng(43.252600, 76.926400);
  static const _baseFare = 500.0;
  static const _perKm = 120.0;
  static const _perMinute = 25.0;
  static const _tariffs = <Tariff>[
    Tariff(nameKey: 'tariff_economy', multiplier: 1),
    Tariff(nameKey: 'tariff_comfort', multiplier: 1.25),
    Tariff(nameKey: 'tariff_business', multiplier: 1.5),
  ];

  ClientFlowStep _step = ClientFlowStep.home;
  int _selectedTariff = 0;
  int _rating = 5;
  bool _isSubmitting = false;
  bool _isLocating = false;
  String? _locationError;
  String? _errorMessage;
  BackendOrder? _activeOrder;
  Position? _currentPosition;

  // GPS stream
  StreamSubscription<Position>? _positionSubscription;

  // Search / geocoding
  final TextEditingController _pickupController = TextEditingController();
  LatLng? _pickupOverrideLatLng;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<_GeoSuggestion> _suggestions = [];
  bool _isSearching = false;
  LatLng? _destinationLatLng;
  String? _destinationName;
  _ActiveSearch _activeSearch = _ActiveSearch.none;
  Timer? _routeDebounce;
  RouteSnapshot? _routeSnapshot;
  bool _isRouteLoading = false;
  bool _isRouteFallback = false;
  String? _routeKey;
  bool _isReverseGeocodingPickup = false;
  int _pickupGeocodeToken = 0;
  int _destinationGeocodeToken = 0;

  LatLng? get _currentLatLng {
    final p = _currentPosition;
    if (p == null) return null;
    return LatLng(p.latitude, p.longitude);
  }

  LatLng get _pickupPoint {
    if (_pickupOverrideLatLng != null) return _pickupOverrideLatLng!;
    final order = _activeOrder;
    if (order?.pickupLatitude != null && order?.pickupLongitude != null) {
      return LatLng(order!.pickupLatitude!, order.pickupLongitude!);
    }
    return _currentLatLng ?? _fallbackPickup;
  }

  LatLng get _dropoffPoint {
    if (_destinationLatLng != null) return _destinationLatLng!;
    final order = _activeOrder;
    if (order?.dropoffLatitude != null && order?.dropoffLongitude != null) {
      return LatLng(order!.dropoffLatitude!, order.dropoffLongitude!);
    }
    final current = _currentLatLng;
    if (current != null) {
      return LatLng(current.latitude + 0.012, current.longitude + 0.018);
    }
    return _fallbackDropoff;
  }

  LatLng? get _driverPoint {
    if (_activeOrder?.driverId == null) return null;
    final pickup = _pickupPoint;
    return LatLng(pickup.latitude + 0.0035, pickup.longitude + 0.0045);
  }

  double get _fallbackDistanceKm {
    final pickup = _pickupPoint;
    final dropoff = _dropoffPoint;
    final meters = Geolocator.distanceBetween(
      pickup.latitude,
      pickup.longitude,
      dropoff.latitude,
      dropoff.longitude,
    );
    final km = meters / 1000;
    return km < 1.5 ? 1.5 : km;
  }

  double get _distanceKm => _routeSnapshot?.distanceKm ?? _fallbackDistanceKm;

  double get _durationMin =>
      _routeSnapshot?.durationMinutes ??
      (_fallbackDistanceKm * 2.8).roundToDouble();

  double get _baseFormulaPrice =>
      _baseFare + (_distanceKm * _perKm) + (_durationMin * _perMinute);
  double get _finalPrice =>
      _baseFormulaPrice * _tariffs[_selectedTariff].multiplier;
  double get _displayPrice => _activeOrder?.finalPrice ?? _finalPrice;
  AppI18n get _i18n => AppI18n(widget.lang);

  List<LatLng>? get _routePolylinePoints {
    final points = _routeSnapshot?.geometry;
    if (points == null || points.length < 2) {
      return null;
    }
    return points;
  }

  bool get _needsRouteEstimate =>
      _destinationLatLng != null || _activeOrder != null;

  @override
  void initState() {
    super.initState();
    _refreshCurrentLocation();
    _scheduleRouteRefresh(delay: Duration.zero);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _pickupController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _routeDebounce?.cancel();
    super.dispose();
  }

  // ── Geolocation ──────────────────────────────────────────────────────────

  Future<void> _refreshCurrentLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _locationError = _i18n.t('location_service_disabled');
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _locationError = _i18n.t('location_permission_denied');
          });
        }
        return;
      }

      // Cancel any existing stream before starting a new one
      await _positionSubscription?.cancel();

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 metres
      );

      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
        (position) {
          if (!mounted) return;
          setState(() {
            _currentPosition = position;
            _locationError = null;
            _isLocating = false;
          });
          _autofillPickupFromCurrentLocation();
          _scheduleRouteRefresh();
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _isLocating = false;
            _locationError = _i18n.t('location_unknown');
          });
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _locationError = _i18n.t('location_unknown');
      });
    }
  }

  // ── Geocoding (Nominatim) ─────────────────────────────────────────────────

  Map<String, String> _nominatimHeaders() {
    if (kIsWeb) {
      return const <String, String>{};
    }
    return const <String, String>{
      'User-Agent': 'TaxiMVP/1.0 (kz.taxi.project)',
    };
  }

  String _preferredLanguageCode() {
    return widget.lang == AppLang.kz ? 'kk,ru,en' : 'ru,kk,en';
  }

  String _shortAddress(String displayName) {
    final parts = displayName
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return displayName.trim();
    }
    if (parts.length == 1) {
      return parts.first;
    }
    return '${parts[0]}, ${parts[1]}';
  }

  String _formatLatLng(LatLng point) {
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  bool _isSamePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00001 &&
        (a.longitude - b.longitude).abs() < 0.00001;
  }

  Future<String?> _reverseGeocodeLabel(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': point.latitude.toStringAsFixed(6),
      'lon': point.longitude.toStringAsFixed(6),
      'format': 'jsonv2',
      'zoom': '18',
      'addressdetails': '1',
      'accept-language': _preferredLanguageCode(),
    });

    final response = await http.get(uri, headers: _nominatimHeaders());
    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final displayName = (decoded['display_name'] ?? '').toString().trim();
    if (displayName.isEmpty) {
      return null;
    }
    return _shortAddress(displayName);
  }

  void _autofillPickupFromCurrentLocation({bool force = false}) {
    final current = _currentLatLng;
    if (current == null) {
      return;
    }
    unawaited(_reverseGeocodePickup(current, force: force));
  }

  Future<void> _reverseGeocodePickup(LatLng point, {bool force = false}) async {
    if (!force) {
      if (_pickupOverrideLatLng != null) {
        return;
      }
      if (_pickupController.text.trim().isNotEmpty) {
        return;
      }
    }

    if (_isReverseGeocodingPickup) {
      return;
    }

    _isReverseGeocodingPickup = true;
    final token = ++_pickupGeocodeToken;

    try {
      final label = await _reverseGeocodeLabel(point);
      if (!mounted || token != _pickupGeocodeToken) {
        return;
      }

      final text = label ?? _formatLatLng(point);
      if (_pickupOverrideLatLng != null && !force) {
        return;
      }

      setState(() {
        _pickupController.text = text;
      });
    } catch (_) {
      if (!mounted || token != _pickupGeocodeToken) {
        return;
      }
      setState(() {
        if (_pickupController.text.trim().isEmpty) {
          _pickupController.text = _formatLatLng(point);
        }
      });
    } finally {
      _isReverseGeocodingPickup = false;
    }
  }

  Future<void> _resolveDestinationAddress(LatLng point) async {
    final token = ++_destinationGeocodeToken;
    try {
      final label = await _reverseGeocodeLabel(point);
      if (!mounted || token != _destinationGeocodeToken) {
        return;
      }
      final current = _destinationLatLng;
      if (current == null || !_isSamePoint(current, point)) {
        return;
      }

      if (label == null || label.isEmpty) {
        return;
      }

      setState(() {
        _destinationName = label;
        _searchController.text = label;
      });
    } catch (_) {}
  }

  void _onMapTapped(LatLng point) {
    final formatted = _formatLatLng(point);
    setState(() {
      _destinationLatLng = point;
      _destinationName = formatted;
      _searchController.text = formatted;
      _suggestions = [];
      _activeSearch = _ActiveSearch.none;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    _scheduleRouteRefresh();
    unawaited(_resolveDestinationAddress(point));
  }

  void _onPickupChanged(String value) {
    _debounce?.cancel();
    setState(() => _activeSearch = _ActiveSearch.pickup);
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600),
        () => _fetchNominatimSuggestions(value.trim()));
  }

  void _onDropoffChanged(String value) {
    _debounce?.cancel();
    setState(() => _activeSearch = _ActiveSearch.dropoff);
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600),
        () => _fetchNominatimSuggestions(value.trim()));
  }

  Future<void> _fetchNominatimSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '5',
        'countrycodes': 'kz',
        'accept-language': _preferredLanguageCode(),
      });
      final response = await http.get(uri, headers: _nominatimHeaders());
      if (!mounted) return;
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        setState(() {
          _suggestions = list
              .map((item) => _GeoSuggestion(
                    displayName: item['display_name'] as String,
                    latLng: LatLng(
                      double.parse(item['lat'] as String),
                      double.parse(item['lon'] as String),
                    ),
                  ))
              .toList();
        });
      } else {
        setState(() => _suggestions = []);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestions = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSuggestionTapped(_GeoSuggestion suggestion) {
    final name = suggestion.displayName.split(',').first.trim();
    if (_activeSearch == _ActiveSearch.pickup) {
      setState(() {
        _pickupOverrideLatLng = suggestion.latLng;
        _pickupController.text = name;
        _suggestions = [];
        _activeSearch = _ActiveSearch.none;
      });
    } else {
      setState(() {
        _destinationLatLng = suggestion.latLng;
        _destinationName = name;
        _searchController.text = name;
        _suggestions = [];
        _activeSearch = _ActiveSearch.none;
      });
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _scheduleRouteRefresh();
  }

  void _clearPickupOverride() {
    setState(() {
      _pickupOverrideLatLng = null;
      _pickupController.clear();
      _suggestions = [];
    });
    _autofillPickupFromCurrentLocation(force: true);
    _scheduleRouteRefresh();
  }

  void _clearDestination() {
    setState(() {
      _destinationLatLng = null;
      _destinationName = null;
      _searchController.clear();
      _suggestions = [];
    });
    _destinationGeocodeToken++;
    _scheduleRouteRefresh();
  }

  // ── Routing estimate (backend) ─────────────────────────────────────────────

  void _scheduleRouteRefresh(
      {Duration delay = const Duration(milliseconds: 450)}) {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(delay, _refreshRouteEstimate);
  }

  String _buildRouteKey(LatLng pickup, LatLng dropoff) {
    return '${pickup.latitude.toStringAsFixed(5)},${pickup.longitude.toStringAsFixed(5)}'
        '|${dropoff.latitude.toStringAsFixed(5)},${dropoff.longitude.toStringAsFixed(5)}';
  }

  String _toRouteCoordinate(LatLng point) {
    return '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}';
  }

  Future<void> _refreshRouteEstimate() async {
    if (!_needsRouteEstimate) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routeSnapshot = null;
        _isRouteLoading = false;
        _isRouteFallback = false;
        _routeKey = null;
      });
      return;
    }

    final pickup = _pickupPoint;
    final dropoff = _dropoffPoint;
    final key = _buildRouteKey(pickup, dropoff);

    if (_routeKey == key &&
        (_routeSnapshot != null || _isRouteFallback || _isRouteLoading)) {
      return;
    }

    if (mounted) {
      setState(() {
        _routeKey = key;
        _isRouteLoading = true;
        _isRouteFallback = false;
      });
    }

    try {
      final route = await widget.apiClient.getRoute(
        coordinates: <String>[
          _toRouteCoordinate(pickup),
          _toRouteCoordinate(dropoff),
        ],
      );

      if (!mounted || _routeKey != key) {
        return;
      }

      if (route.distanceKm <= 0 ||
          route.durationMinutes <= 0 ||
          route.geometry.length < 2) {
        setState(() {
          _routeSnapshot = null;
          _isRouteLoading = false;
          _isRouteFallback = true;
        });
        return;
      }

      setState(() {
        _routeSnapshot = route;
        _isRouteLoading = false;
        _isRouteFallback = false;
      });
    } catch (_) {
      if (!mounted || _routeKey != key) {
        return;
      }
      setState(() {
        _routeSnapshot = null;
        _isRouteLoading = false;
        _isRouteFallback = true;
      });
    }
  }

  String _routeInfoText() {
    if (_isRouteLoading) {
      return _i18n.t('route_calculating');
    }
    if (_routeSnapshot != null) {
      return _i18n.t('route_ready', {
        'km': _distanceKm.toStringAsFixed(1),
        'min': _durationMin.toStringAsFixed(0),
      });
    }
    if (_isRouteFallback) {
      return _i18n.t('route_fallback');
    }
    return _i18n.t('route_calculating');
  }

  Color _routeInfoColor() {
    if (_isRouteLoading) {
      return UiKitColors.primary;
    }
    if (_routeSnapshot != null) {
      return UiKitColors.success;
    }
    if (_isRouteFallback) {
      return UiKitColors.textSecondary;
    }
    return UiKitColors.textSecondary;
  }

  // ── Order flow ────────────────────────────────────────────────────────────

  Future<void> _confirmRideAndRequestDriver() async {
    if (_isSubmitting) return;

    if (widget.session.role == AppRole.driver) {
      setState(() => _errorMessage = _i18n.t('client_only_message'));
      return;
    }

    if (_currentPosition == null) {
      await _refreshCurrentLocation();
      if (_currentPosition == null) {
        setState(() =>
            _errorMessage = _locationError ?? _i18n.t('location_unknown'));
        return;
      }
    }

    await _refreshRouteEstimate();

    final pickup = _pickupPoint;
    final dropoff = _dropoffPoint;

    setState(() {
      _step = ClientFlowStep.searching;
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final order = await widget.apiClient.createOrder(
        passengerId: widget.session.userId,
        cityId: 'almaty',
        pickupLatitude: pickup.latitude,
        pickupLongitude: pickup.longitude,
        dropoffLatitude: dropoff.latitude,
        dropoffLongitude: dropoff.longitude,
        distanceKm: _distanceKm,
        durationMinutes: _durationMin,
        surgeMultiplier: _tariffs[_selectedTariff].multiplier,
      );
      if (!mounted) return;
      setState(() => _activeOrder = order);
      _scheduleRouteRefresh(delay: Duration.zero);
      await _searchDriverForCurrentOrder(showLoader: false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _searchDriverForCurrentOrder({bool showLoader = true}) async {
    final order = _activeOrder;
    if (order == null) return;

    if (showLoader) {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });
    }

    try {
      final assigned = await widget.apiClient.searchDriver(order.id);
      if (!mounted) return;
      setState(() => _activeOrder = assigned);
      _scheduleRouteRefresh(delay: Duration.zero);

      if (assigned.driverId == null || assigned.status != 'DRIVER_ASSIGNED') {
        setState(() => _errorMessage = _i18n.t('driver_not_found'));
        return;
      }

      final arriving = await widget.apiClient
          .updateOrderStatus(assigned.id, 'DRIVER_ARRIVING');
      if (!mounted) return;
      setState(() {
        _activeOrder = arriving;
        _step = ClientFlowStep.tracking;
        _errorMessage = null;
      });
      _scheduleRouteRefresh(delay: Duration.zero);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted && showLoader) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _completeTrip() async {
    final order = _activeOrder;
    if (order == null || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      BackendOrder current = order;
      if (current.status != 'IN_PROGRESS') {
        current =
            await widget.apiClient.updateOrderStatus(current.id, 'IN_PROGRESS');
      }
      if (current.status != 'COMPLETED') {
        current =
            await widget.apiClient.updateOrderStatus(current.id, 'COMPLETED');
      }
      if (!mounted) return;
      setState(() {
        _activeOrder = current;
        _step = ClientFlowStep.completed;
      });
      _scheduleRouteRefresh(delay: Duration.zero);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cancelOrderAndGoHome() async {
    final order = _activeOrder;
    if (order != null && order.canBeCanceled) {
      try {
        await widget.apiClient.updateOrderStatus(order.id, 'CANCELED');
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _activeOrder = null;
      _errorMessage = null;
      _isSubmitting = false;
      _step = ClientFlowStep.home;
      _pickupOverrideLatLng = null;
      _pickupController.clear();
    });
    _scheduleRouteRefresh(delay: Duration.zero);
  }

  // ── Screens ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case ClientFlowStep.home:
        return _buildHomeScreen(context);
      case ClientFlowStep.searching:
        return _buildSearchingScreen(context);
      case ClientFlowStep.tracking:
        return _buildTrackingScreen(context);
      case ClientFlowStep.completed:
        return _buildCompletedScreen(context);
    }
  }

  Widget _buildHomeScreen(BuildContext context) {
    final i18n = _i18n;
    final hasDest = _destinationLatLng != null;
    final gpsOk = _currentLatLng != null && _locationError == null;

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────
          Positioned.fill(
            child: MapBackdrop(
              currentLocation: _currentLatLng,
              pickupPoint: _currentLatLng ?? _fallbackPickup,
              dropoffPoint: hasDest ? _destinationLatLng : null,
              routePolylinePoints: hasDest ? _routePolylinePoints : null,
              onMapTap: _step == ClientFlowStep.home ? _onMapTapped : null,
            ),
          ),

          // ── A/B search card + suggestions ────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 84, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search card
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // A: Pickup row
                        Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(Icons.radio_button_checked,
                                color: UiKitColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _pickupController,
                                onChanged: _onPickupChanged,
                                onTap: () => setState(
                                    () => _activeSearch = _ActiveSearch.pickup),
                                decoration: InputDecoration(
                                  hintText: i18n.t('your_location'),
                                  hintStyle: const TextStyle(
                                      color: UiKitColors.textSecondary),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                ),
                              ),
                            ),
                            if (_pickupOverrideLatLng != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _clearPickupOverride,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(Icons.my_location,
                                    size: 18,
                                    color: gpsOk
                                        ? UiKitColors.success
                                        : UiKitColors.textSecondary),
                              ),
                          ],
                        ),
                        // Vertical connector
                        Padding(
                          padding: const EdgeInsets.only(left: 23),
                          child: Row(
                            children: [
                              Container(
                                width: 2,
                                height: 10,
                                color: const Color(0xFFE5E7EB),
                              ),
                              const Expanded(
                                  child: Divider(height: 1, indent: 8)),
                            ],
                          ),
                        ),
                        // B: Dropoff row
                        Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(Icons.location_on,
                                color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onDropoffChanged,
                                onTap: () => setState(() =>
                                    _activeSearch = _ActiveSearch.dropoff),
                                decoration: InputDecoration(
                                  hintText: i18n.t('where_to'),
                                  hintStyle: const TextStyle(
                                      color: UiKitColors.textSecondary),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                ),
                              ),
                            ),
                            if (_isSearching)
                              const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: UiKitColors.primary),
                                ),
                              )
                            else if (hasDest)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _clearDestination,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Suggestions dropdown
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 56),
                          itemBuilder: (context, index) {
                            final s = _suggestions[index];
                            final title = s.displayName.split(',').first.trim();
                            final subtitle = s.displayName
                                .split(',')
                                .skip(1)
                                .take(2)
                                .join(',')
                                .trim();
                            final isPickup =
                                _activeSearch == _ActiveSearch.pickup;
                            return ListTile(
                              dense: true,
                              leading: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isPickup
                                      ? const Color(0xFFEDE9FE)
                                      : const Color(0xFFD1FAE5),
                                ),
                                child: Icon(
                                  isPickup
                                      ? Icons.radio_button_checked
                                      : Icons.location_on_outlined,
                                  size: 16,
                                  color: isPickup
                                      ? UiKitColors.primary
                                      : UiKitColors.success,
                                ),
                              ),
                              title: Text(title,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              subtitle: subtitle.isNotEmpty
                                  ? Text(subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12))
                                  : null,
                              onTap: () => _onSuggestionTapped(s),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom action card ────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1C000000),
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // GPS status row
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isLocating
                                ? UiKitColors.primary
                                : (_locationError == null
                                    ? UiKitColors.success
                                    : UiKitColors.danger),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _isLocating
                                ? i18n.t('locating')
                                : (_locationError == null
                                    ? i18n.t('location_ready')
                                    : _locationError!),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _locationError == null
                                          ? UiKitColors.textSecondary
                                          : UiKitColors.danger,
                                    ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _isLocating ? null : _refreshCurrentLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'GPS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: UiKitColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!hasDest) ...[
                      const SizedBox(height: 10),
                      Text(
                        i18n.t('map_tap_hint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: UiKitColors.textSecondary,
                            ),
                      ),
                    ],
                    if (hasDest) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _destinationName ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${_distanceKm.toStringAsFixed(1)} км  •  ~${_durationMin.toStringAsFixed(0)} мин',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: UiKitColors.textSecondary),
                          ),
                        ],
                      ),
                      if (_isRouteLoading || _isRouteFallback) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              _isRouteLoading ? Icons.sync : Icons.info_outline,
                              size: 13,
                              color: _routeInfoColor(),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _routeInfoText(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: _routeInfoColor()),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        i18n.t('tariff'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_tariffs.length, (index) {
                          final tariff = _tariffs[index];
                          final isSelected = _selectedTariff == index;
                          final tariffPrice =
                              _baseFormulaPrice * tariff.multiplier;
                          return ChoiceChip(
                            label: Text(
                              '${i18n.t(tariff.nameKey)} • ${tariffPrice.toStringAsFixed(0)} ₸',
                            ),
                            selected: isSelected,
                            onSelected: (_) =>
                                setState(() => _selectedTariff = index),
                            selectedColor: const Color(0xFFE0E7FF),
                            checkmarkColor: UiKitColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? UiKitColors.primary
                                  : UiKitColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? UiKitColors.primary
                                  : const Color(0xFFE5E7EB),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _finalPrice.toStringAsFixed(0),
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: UiKitColors.primary,
                                  height: 1,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '₸',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: UiKitColors.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 16),
                    // CTA button
                    FilledButton(
                      onPressed: hasDest && !_isSubmitting
                          ? _confirmRideAndRequestDriver
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor: const Color(0xFFF3F4F6),
                        disabledForegroundColor: UiKitColors.textSecondary,
                      ),
                      child: Text(
                        _isSubmitting
                            ? i18n.t('please_wait')
                            : hasDest
                                ? i18n.t('confirm_ride')
                                : i18n.t('where_to'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingScreen(BuildContext context) {
    final i18n = _i18n;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapBackdrop(
              currentLocation: _currentLatLng,
              pickupPoint: _pickupPoint,
              dropoffPoint: _dropoffPoint,
              driverPoint: _driverPoint,
              routePolylinePoints: _routePolylinePoints,
            ),
          ),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSubmitting) ...[
                      const CircularProgressIndicator(
                          color: UiKitColors.primary),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      _isSubmitting
                          ? i18n.t('searching_driver')
                          : i18n.t('search_result'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeOrder == null
                          ? i18n.t('creating_order')
                          : i18n.t('order_short', {
                              'id': _activeOrder!.id.substring(0, 8),
                              'status': localizedOrderStatus(
                                  widget.lang, _activeOrder!.status),
                            }),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UiKitColors.textSecondary,
                          ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: UiKitColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : (_activeOrder == null
                              ? _confirmRideAndRequestDriver
                              : () => _searchDriverForCurrentOrder()),
                      child: Text(i18n.t('retry_search')),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : _cancelOrderAndGoHome,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(i18n.t('cancel')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingScreen(BuildContext context) {
    final i18n = _i18n;
    final status = localizedOrderStatus(
        widget.lang, _activeOrder?.status ?? 'DRIVER_ARRIVING');

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapBackdrop(
              currentLocation: _currentLatLng,
              pickupPoint: _pickupPoint,
              dropoffPoint: _dropoffPoint,
              driverPoint: _driverPoint,
              routePolylinePoints: _routePolylinePoints,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 26,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFFE0E7FF),
                          child: Icon(Icons.person, color: UiKitColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i18n.t('driver_name'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(i18n.t('car_info')),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      i18n.t('order_id', {'id': _activeOrder?.id ?? '-'}),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UiKitColors.textSecondary,
                          ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: UiKitColors.danger,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.call),
                            label: Text(i18n.t('call')),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _completeTrip,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              _isSubmitting
                                  ? i18n.t('updating')
                                  : i18n.t('complete_trip'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedScreen(BuildContext context) {
    final i18n = _i18n;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('trip_completed'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 56, color: UiKitColors.success),
                    const SizedBox(height: 12),
                    Text(
                      '${_displayPrice.toStringAsFixed(0)} KZT',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(i18n
                        .t('order_number', {'id': _activeOrder?.id ?? '-'})),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      children: List.generate(5, (index) {
                        final filled = index < _rating;
                        return IconButton(
                          onPressed: () => setState(() => _rating = index + 1),
                          icon: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: filled
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF9CA3AF),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                setState(() {
                  _activeOrder = null;
                  _errorMessage = null;
                  _step = ClientFlowStep.home;
                });
                _scheduleRouteRefresh(delay: Duration.zero);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(i18n.t('book_again')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class _GeoSuggestion {
  const _GeoSuggestion({required this.displayName, required this.latLng});
  final String displayName;
  final LatLng latLng;
}

enum _ActiveSearch { none, pickup, dropoff }
