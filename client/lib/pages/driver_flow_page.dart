import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api/taxi_api_client.dart';
import '../core/colors.dart';
import '../i18n/app_i18n.dart';
import '../models/backend_order.dart';
import '../models/route_snapshot.dart';
import '../widgets/map_backdrop.dart';

class DriverFlowPage extends StatefulWidget {
  const DriverFlowPage({
    required this.apiClient,
    required this.lang,
    super.key,
  });

  final TaxiApiClient apiClient;
  final AppLang lang;

  @override
  State<DriverFlowPage> createState() => _DriverFlowPageState();
}

class _DriverFlowPageState extends State<DriverFlowPage> {
  static const double _pickupArrivalRadiusMeters = 120;
  bool _online = false;
  bool _busy = false;
  String? _error;
  Position? _currentPosition;
  BackendOrder? _activeOrder;
  RouteSnapshot? _driverRouteSnapshot;
  Timer? _ordersPollingTimer;
  Timer? _driverRouteDebounce;
  StreamSubscription<Position>? _positionSubscription;
  bool _isSyncingDriverLocation = false;
  DateTime? _lastDriverLocationSyncAt;
  Position? _lastSyncedDriverPosition;
  String? _driverRouteKey;
  bool _isDriverRouteLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshOrders();
    unawaited(_startLocationTracking());
  }

  @override
  void dispose() {
    _ordersPollingTimer?.cancel();
    _driverRouteDebounce?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  LatLng? get _currentLatLng {
    final p = _currentPosition;
    if (p == null) return null;
    return LatLng(p.latitude, p.longitude);
  }

  LatLng? get _pickupPoint {
    final order = _activeOrder;
    if (order == null || !_isPanelVisibleOrder(order)) {
      return null;
    }
    if (order.pickupLatitude == null || order.pickupLongitude == null) {
      return null;
    }
    return LatLng(order.pickupLatitude!, order.pickupLongitude!);
  }

  LatLng? get _dropoffPoint {
    final order = _activeOrder;
    if (order == null || !_isPanelVisibleOrder(order)) {
      return null;
    }
    if (order.dropoffLatitude == null || order.dropoffLongitude == null) {
      return null;
    }
    return LatLng(order.dropoffLatitude!, order.dropoffLongitude!);
  }

  List<LatLng>? get _driverRoutePolylinePoints {
    final order = _activeOrder;
    if (order == null || !_isPanelVisibleOrder(order)) {
      return null;
    }

    final routedGeometry = _driverRouteSnapshot?.geometry;
    if (routedGeometry != null && routedGeometry.length >= 2) {
      return routedGeometry;
    }

    final driver = _currentLatLng;
    final pickup = _pickupPoint;
    final dropoff = _dropoffPoint;

    if ((order.status == 'DRIVER_ASSIGNED' ||
            order.status == 'DRIVER_ARRIVING' ||
            order.status == 'DRIVER_ARRIVED') &&
        driver != null &&
        pickup != null) {
      return [driver, pickup];
    }

    if (order.status == 'IN_PROGRESS' && driver != null && dropoff != null) {
      return [driver, dropoff];
    }

    return null;
  }

  LatLng? get _driverRouteTargetPoint {
    final order = _activeOrder;
    if (order == null || !_isPanelVisibleOrder(order)) {
      return null;
    }

    if (order.status == 'IN_PROGRESS') {
      return _dropoffPoint;
    }

    if (order.status == 'DRIVER_ASSIGNED' ||
        order.status == 'DRIVER_ARRIVING' ||
        order.status == 'DRIVER_ARRIVED') {
      return _pickupPoint;
    }

    return null;
  }

  String _toRouteCoordinate(LatLng point) {
    return '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}';
  }

  String _buildDriverRouteKey({
    required BackendOrder order,
    required LatLng from,
    required LatLng to,
  }) {
    return '${order.id}|${order.status}|'
        '${from.latitude.toStringAsFixed(4)},${from.longitude.toStringAsFixed(4)}|'
        '${to.latitude.toStringAsFixed(5)},${to.longitude.toStringAsFixed(5)}';
  }

  void _scheduleDriverRouteRefresh(
      {Duration delay = const Duration(milliseconds: 500)}) {
    _driverRouteDebounce?.cancel();
    _driverRouteDebounce = Timer(delay, () {
      unawaited(_refreshDriverRoute());
    });
  }

  Future<void> _refreshDriverRoute() async {
    final order = _activeOrder;
    final from = _currentLatLng;
    final to = _driverRouteTargetPoint;
    if (order == null ||
        !_isPanelVisibleOrder(order) ||
        from == null ||
        to == null) {
      if (!mounted) return;
      if (_driverRouteSnapshot == null &&
          _driverRouteKey == null &&
          !_isDriverRouteLoading) {
        return;
      }
      setState(() {
        _driverRouteSnapshot = null;
        _driverRouteKey = null;
        _isDriverRouteLoading = false;
      });
      return;
    }

    final key = _buildDriverRouteKey(order: order, from: from, to: to);
    if (_driverRouteKey == key &&
        (_driverRouteSnapshot != null || _isDriverRouteLoading)) {
      return;
    }

    if (mounted) {
      setState(() {
        _driverRouteKey = key;
        _isDriverRouteLoading = true;
      });
    }

    try {
      final route = await widget.apiClient.getRoute(
        coordinates: <String>[
          _toRouteCoordinate(from),
          _toRouteCoordinate(to),
        ],
      );

      if (!mounted || _driverRouteKey != key) {
        return;
      }

      if (route.geometry.length < 2) {
        setState(() {
          _driverRouteSnapshot = null;
          _isDriverRouteLoading = false;
        });
        return;
      }

      setState(() {
        _driverRouteSnapshot = route;
        _isDriverRouteLoading = false;
      });
    } catch (_) {
      if (!mounted || _driverRouteKey != key) {
        return;
      }
      setState(() {
        _driverRouteSnapshot = null;
        _isDriverRouteLoading = false;
      });
    }
  }

  double? _pickupDistanceMeters(BackendOrder order) {
    final current = _currentPosition;
    final pickupLat = order.pickupLatitude;
    final pickupLon = order.pickupLongitude;
    if (current == null || pickupLat == null || pickupLon == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      pickupLat,
      pickupLon,
    );
  }

  bool _canStartRide(BackendOrder order) {
    if (order.status != 'DRIVER_ARRIVING') {
      return true;
    }
    final distance = _pickupDistanceMeters(order);
    return distance != null && distance <= _pickupArrivalRadiusMeters;
  }

  String _canceledOrderMessage(BackendOrder? order) {
    final i18n = AppI18n(widget.lang);
    switch (order?.canceledByRole?.trim().toUpperCase()) {
      case 'CLIENT':
        return i18n.t('order_canceled_by_client');
      case 'DRIVER':
        return i18n.t('order_canceled_by_you');
      case 'ADMIN':
        return i18n.t('order_canceled_by_admin');
      default:
        return i18n.t('order_canceled');
    }
  }

  void _showCancelSnackBar(String message) {
    if (!mounted || message.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFFEFF6FF),
        surfaceTintColor: Colors.transparent,
        leading: const Icon(
          Icons.info_outline_rounded,
          color: UiKitColors.primary,
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: UiKitColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            icon: const Icon(Icons.close_rounded),
            color: UiKitColors.primary,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Future<void> _runWithLoader(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (value) {
        await _ensureLocationPermission();
        final position = _currentPosition ?? await _readCurrentPosition();
        if (!mounted) return;
        setState(() {
          _currentPosition = position;
          _error = null;
        });
        await widget.apiClient.updateDriverLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _lastDriverLocationSyncAt = DateTime.now();
        _lastSyncedDriverPosition = position;
      }

      await widget.apiClient.setDriverAvailability(value);

      if (!mounted) return;

      setState(() {
        _online = value;
      });

      if (value) {
        _startOrdersPolling();
        unawaited(_refreshOrders(showLoader: false));
        if (_currentPosition != null) {
          unawaited(_syncDriverLocation(_currentPosition!, force: true));
        } else {
          unawaited(_updateOwnLocationSilently());
        }
      } else {
        _ordersPollingTimer?.cancel();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _startOrdersPolling() {
    _ordersPollingTimer?.cancel();
    _ordersPollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!_online || _busy) {
          return;
        }
        unawaited(_refreshOrders(showLoader: false));
      },
    );
  }

  Future<void> _startLocationTracking() async {
    try {
      await _ensureLocationPermission();
      final initial = await _readCurrentPosition();
      if (!mounted) return;

      setState(() {
        _currentPosition = initial;
        _error = null;
      });
      _scheduleDriverRouteRefresh(delay: Duration.zero);
      unawaited(_syncDriverLocation(initial, force: true));

      await _positionSubscription?.cancel();
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 7,
      );
      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: settings).listen(
        (position) {
          if (!mounted) return;
          setState(() {
            _currentPosition = position;
          });
          _scheduleDriverRouteRefresh();
          unawaited(_syncDriverLocation(position));
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _error = AppI18n(widget.lang).t('location_unknown');
          });
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _ensureLocationPermission() async {
    final i18n = AppI18n(widget.lang);
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(i18n.t('location_service_disabled'));
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(i18n.t('location_permission_denied'));
    }
  }

  Future<Position> _readCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    ).timeout(const Duration(seconds: 8));
  }

  bool _shouldSyncDriverLocation(Position position, {required bool force}) {
    if (!_online) {
      return false;
    }
    if (force) {
      return true;
    }

    final lastAt = _lastDriverLocationSyncAt;
    final lastPosition = _lastSyncedDriverPosition;
    if (lastAt == null || lastPosition == null) {
      return true;
    }

    final elapsedSeconds = DateTime.now().difference(lastAt).inSeconds;
    if (elapsedSeconds >= 10) {
      return true;
    }

    final movedMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      lastPosition.latitude,
      lastPosition.longitude,
    );
    return movedMeters >= 25;
  }

  Future<void> _syncDriverLocation(
    Position position, {
    bool force = false,
  }) async {
    if (_isSyncingDriverLocation ||
        !_shouldSyncDriverLocation(position, force: force)) {
      return;
    }

    _isSyncingDriverLocation = true;
    try {
      await widget.apiClient.updateDriverLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _lastDriverLocationSyncAt = DateTime.now();
      _lastSyncedDriverPosition = position;
    } catch (_) {
      // Keep background sync silent; manual refresh still surfaces hard errors.
    } finally {
      _isSyncingDriverLocation = false;
    }
  }

  Future<void> _updateOwnLocationSilently() async {
    try {
      await _updateOwnLocation();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _updateOwnLocation() async {
    await _ensureLocationPermission();
    final position = await _readCurrentPosition();
    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _error = null;
    });
    _scheduleDriverRouteRefresh(delay: Duration.zero);
    await _syncDriverLocation(position, force: true);
  }

  Future<void> _refreshOrders({bool showLoader = true}) async {
    Future<void> action() async {
      final previousActiveOrder = _activeOrder;
      final orders = await widget.apiClient.listOrders();
      final candidate = _pickActiveOrder(orders);
      String? cancelMessage;

      if (previousActiveOrder != null && candidate == null) {
        for (final order in orders) {
          if (order.id == previousActiveOrder.id &&
              order.status == 'CANCELED') {
            cancelMessage = _canceledOrderMessage(order);
            break;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _activeOrder = candidate;
        if (cancelMessage != null && cancelMessage.isNotEmpty) {
          _error = cancelMessage;
        }
      });
      _scheduleDriverRouteRefresh(delay: Duration.zero);
      if (cancelMessage != null && cancelMessage.isNotEmpty) {
        _showCancelSnackBar(cancelMessage);
      }
    }

    if (showLoader) {
      await _runWithLoader(action);
    } else {
      try {
        await action();
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  bool _isPanelVisibleStatus(String status) {
    return status == 'DRIVER_ASSIGNED' ||
        status == 'DRIVER_ARRIVING' ||
        status == 'DRIVER_ARRIVED' ||
        status == 'IN_PROGRESS';
  }

  bool _isPanelVisibleOrder(BackendOrder order) {
    return _isPanelVisibleStatus(order.status);
  }

  BackendOrder? _pickActiveOrder(List<BackendOrder> orders) {
    final current = _activeOrder;
    if (current != null && _isPanelVisibleOrder(current)) {
      for (final order in orders) {
        if (order.id == current.id) {
          return _isPanelVisibleOrder(order) ? order : null;
        }
      }
      return current;
    }

    for (final order in orders) {
      if (_isPanelVisibleOrder(order)) {
        return order;
      }
    }

    return null;
  }

  Future<void> _acceptRide() async {
    final order = _activeOrder;
    if (order == null) return;

    await _runWithLoader(() async {
      final next = await widget.apiClient.updateOrderStatus(
        order.id,
        'DRIVER_ARRIVING',
      );
      if (!mounted) return;

      setState(() {
        _activeOrder = next;
      });
      _scheduleDriverRouteRefresh(delay: Duration.zero);
    });
  }

  Future<void> _updateStatus(String status) async {
    final order = _activeOrder;
    if (order == null) return;

    await _runWithLoader(() async {
      final next = await widget.apiClient.updateOrderStatus(order.id, status);
      if (!mounted) return;
      final cancelMessage =
          next.status == 'CANCELED' ? _canceledOrderMessage(next) : null;
      setState(() {
        _activeOrder = _isPanelVisibleOrder(next) ? next : null;
        if (cancelMessage != null) {
          _error = cancelMessage;
        }
      });
      _scheduleDriverRouteRefresh(delay: Duration.zero);
      if (cancelMessage != null) {
        _showCancelSnackBar(cancelMessage);
      }
    });
  }

  Future<void> _cancelActiveOrder() async {
    final order = _activeOrder;
    if (order == null || !order.canBeCanceled) return;

    await _updateStatus('CANCELED');
    await _refreshOrders(showLoader: false);
  }

  Widget _buildMapActionsOverlay(AppI18n i18n) {
    final onlineBg = _online ? UiKitColors.success : const Color(0xFF64748B);
    return Positioned(
      top: 12,
      right: 12,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: 'driver-online-toggle-fab',
            onPressed: _busy ? null : () => _toggleOnline(!_online),
            backgroundColor: onlineBg,
            foregroundColor: Colors.white,
            tooltip: i18n.t('online_mode'),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _online
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                  ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'driver-refresh-location-fab',
            onPressed: _busy ? null : () => _runWithLoader(_updateOwnLocation),
            backgroundColor: Colors.white,
            foregroundColor: UiKitColors.primary,
            tooltip: i18n.t('refresh_location'),
            child: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n(widget.lang);
    final order = _activeOrder;
    final panelOrder =
        order != null && _isPanelVisibleOrder(order) ? order : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('driver_workspace')),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapBackdrop(
              currentLocation: _currentLatLng,
              pickupPoint: _pickupPoint,
              dropoffPoint: _dropoffPoint,
              driverPoint: _currentLatLng,
              routePolylinePoints: _driverRoutePolylinePoints,
              showCurrentLocationMarker: false,
            ),
          ),
          _buildMapActionsOverlay(i18n),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _online
                              ? Icons.check_circle_rounded
                              : Icons.remove_circle_outline_rounded,
                          size: 16,
                          color: _online
                              ? UiKitColors.success
                              : UiKitColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            i18n.t('online_subtitle'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: UiKitColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      i18n.t('current_order'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    if (panelOrder == null)
                      Text(i18n.t('no_active_order'))
                    else ...[
                      Text(i18n.t('order_id', {'id': panelOrder.id})),
                      const SizedBox(height: 4),
                      Text(
                        i18n.t(
                          'status',
                          {
                            'value': localizedOrderStatus(
                                widget.lang, panelOrder.status)
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        i18n.t(
                          'final_price_label',
                          {'value': panelOrder.finalPrice.toStringAsFixed(0)},
                        ),
                      ),
                      if (panelOrder.status == 'DRIVER_ARRIVING' ||
                          panelOrder.status == 'DRIVER_ARRIVED') ...[
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) {
                            final distance = _pickupDistanceMeters(panelOrder);
                            if (distance == null) {
                              return Text(
                                i18n.t('pickup_distance_unknown'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: UiKitColors.textSecondary),
                              );
                            }

                            final reached =
                                panelOrder.status == 'DRIVER_ARRIVED' ||
                                    distance <= _pickupArrivalRadiusMeters;
                            return Text(
                              reached
                                  ? i18n.t('pickup_reached')
                                  : i18n.t(
                                      'distance_to_pickup',
                                      {
                                        'meters': distance.round().toString(),
                                      },
                                    ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: reached
                                        ? UiKitColors.success
                                        : UiKitColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            );
                          },
                        ),
                      ],
                    ],
                    if (_currentPosition != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'GPS: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: UiKitColors.textSecondary,
                            ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: UiKitColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (panelOrder != null &&
                        panelOrder.status == 'DRIVER_ARRIVING' &&
                        !_canStartRide(panelOrder)) ...[
                      const SizedBox(height: 8),
                      Text(
                        i18n.t('pickup_arrival_required'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: UiKitColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildStatusAction(i18n, panelOrder),
                    if (panelOrder != null && panelOrder.canBeCanceled) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _cancelActiveOrder,
                        icon: const Icon(Icons.cancel_outlined),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        label: Text(i18n.t('cancel')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAction(AppI18n i18n, BackendOrder? order) {
    if (order == null) {
      if (!_online) {
        return FilledButton(
          onPressed: _busy ? null : () => _toggleOnline(true),
          child: Text(_busy ? i18n.t('loading') : i18n.t('online_mode')),
        );
      }
      return const SizedBox.shrink();
    }

    if (order.status == 'DRIVER_ASSIGNED') {
      return FilledButton(
        onPressed: _busy ? null : _acceptRide,
        child: Text(_busy ? i18n.t('loading') : i18n.t('accept_ride')),
      );
    }

    if (order.status == 'DRIVER_ARRIVING') {
      final canMarkArrived = _canStartRide(order);
      return FilledButton(
        onPressed: _busy || !canMarkArrived
            ? null
            : () => _updateStatus('DRIVER_ARRIVED'),
        child: Text(_busy ? i18n.t('loading') : i18n.t('mark_arrived')),
      );
    }

    if (order.status == 'DRIVER_ARRIVED') {
      return FilledButton(
        onPressed: _busy ? null : () => _updateStatus('IN_PROGRESS'),
        child: Text(_busy ? i18n.t('loading') : i18n.t('start_ride')),
      );
    }

    if (order.status == 'IN_PROGRESS') {
      return OutlinedButton(
        onPressed: _busy ? null : () => _updateStatus('COMPLETED'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(_busy ? i18n.t('loading') : i18n.t('complete_ride')),
      );
    }

    return const SizedBox.shrink();
  }
}
