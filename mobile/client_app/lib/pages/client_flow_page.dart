import 'dart:async';
import 'dart:convert';

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
import '../models/tariff.dart';
import '../widgets/map_backdrop.dart';

enum ClientFlowStep { home, confirmRide, searching, tracking, completed }

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
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<_GeoSuggestion> _suggestions = [];
  bool _isSearching = false;
  LatLng? _destinationLatLng;
  String? _destinationName;

  LatLng? get _currentLatLng {
    final p = _currentPosition;
    if (p == null) return null;
    return LatLng(p.latitude, p.longitude);
  }

  LatLng get _pickupPoint {
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

  double get _distanceKm {
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

  double get _durationMin => (_distanceKm * 2.8).roundToDouble();
  double get _baseFormulaPrice =>
      _baseFare + (_distanceKm * _perKm) + (_durationMin * _perMinute);
  double get _finalPrice =>
      _baseFormulaPrice * _tariffs[_selectedTariff].multiplier;
  double get _displayPrice => _activeOrder?.finalPrice ?? _finalPrice;
  AppI18n get _i18n => AppI18n(widget.lang);

  @override
  void initState() {
    super.initState();
    _refreshCurrentLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    _debounce?.cancel();
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
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
        'accept-language':
            widget.lang == AppLang.kz ? 'kk,ru,en' : 'ru,kk,en',
      });
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'TaxiMVP/1.0 (kz.taxi.project)'},
      );
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
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectDestination(_GeoSuggestion suggestion) {
    final name = suggestion.displayName.split(',').first.trim();
    setState(() {
      _destinationLatLng = suggestion.latLng;
      _destinationName = name;
      _searchController.text = name;
      _suggestions = [];
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _clearDestination() {
    setState(() {
      _destinationLatLng = null;
      _destinationName = null;
      _searchController.clear();
      _suggestions = [];
    });
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
        setState(
            () => _errorMessage = _locationError ?? _i18n.t('location_unknown'));
        return;
      }
    }

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
        current = await widget.apiClient
            .updateOrderStatus(current.id, 'IN_PROGRESS');
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
    });
  }

  // ── Screens ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case ClientFlowStep.home:
        return _buildHomeScreen(context);
      case ClientFlowStep.confirmRide:
        return _buildConfirmRideScreen(context);
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

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapBackdrop(
              currentLocation: _currentLatLng,
              pickupPoint: _currentLatLng ?? _fallbackPickup,
              dropoffPoint: hasDest ? _destinationLatLng : null,
            ),
          ),

          // ── Search bar + suggestions ──────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 84, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: i18n.t('search_destination'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: UiKitColors.primary),
                                ),
                              )
                            : (hasDest
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearDestination,
                                  )
                                : null),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    Card(
                      margin: const EdgeInsets.only(top: 4),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (context, index) {
                          final s = _suggestions[index];
                          final title = s.displayName.split(',').first.trim();
                          final subtitle = s.displayName
                              .split(',')
                              .skip(1)
                              .take(2)
                              .join(',')
                              .trim();
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined,
                                color: UiKitColors.primary),
                            title: Text(title),
                            subtitle: subtitle.isNotEmpty
                                ? Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () => _selectDestination(s),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom card ───────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.t('where_to'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i18n.t('signed_as', {'email': widget.session.email}),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UiKitColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          _isLocating
                              ? Icons.sync
                              : (_locationError == null
                                  ? Icons.my_location
                                  : Icons.location_off),
                          size: 14,
                          color: _locationError == null
                              ? UiKitColors.success
                              : UiKitColors.danger,
                        ),
                        const SizedBox(width: 6),
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
                                          ? UiKitColors.success
                                          : UiKitColors.danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed:
                              _isLocating ? null : _refreshCurrentLocation,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('GPS'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    if (hasDest) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.flag_rounded,
                              color: UiKitColors.success, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _destinationName!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${_distanceKm.toStringAsFixed(1)} km',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: UiKitColors.textSecondary,
                                    ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _step = ClientFlowStep.confirmRide),
                      child: Text(i18n.t('set_destination')),
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

  Widget _buildConfirmRideScreen(BuildContext context) {
    final i18n = _i18n;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(i18n.t('confirm_ride')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              child: MapBackdrop(
                currentLocation: _currentLatLng,
                pickupPoint: _pickupPoint,
                dropoffPoint: _dropoffPoint,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.t('tariff'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_tariffs.length, (index) {
                    final tariff = _tariffs[index];
                    final isSelected = _selectedTariff == index;
                    final price = _baseFormulaPrice * tariff.multiplier;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? UiKitColors.primary
                              : const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: Text(i18n.t(tariff.nameKey)),
                        subtitle: Text(
                          i18n.t('tariff_multiplier',
                              {'value': tariff.multiplier.toStringAsFixed(2)}),
                        ),
                        trailing: Text('${price.toStringAsFixed(0)} KZT'),
                        onTap: () => setState(() => _selectedTariff = index),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    i18n.t('formula_caption'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: UiKitColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i18n.t('final_price',
                        {'price': _finalPrice.toStringAsFixed(0)}),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSubmitting ? null : _confirmRideAndRequestDriver,
            child: Text(
              _isSubmitting ? i18n.t('please_wait') : i18n.t('confirm_ride'),
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
              },
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
