import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api/taxi_api_client.dart';
import '../core/colors.dart';
import '../i18n/app_i18n.dart';
import '../models/backend_order.dart';
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
  bool _online = false;
  bool _busy = false;
  String? _error;
  Position? _currentPosition;
  BackendOrder? _activeOrder;
  Timer? _ordersPollingTimer;
  StreamSubscription<Position>? _positionSubscription;
  bool _isSyncingDriverLocation = false;
  DateTime? _lastDriverLocationSyncAt;
  Position? _lastSyncedDriverPosition;

  @override
  void initState() {
    super.initState();
    _refreshOrders();
    unawaited(_startLocationTracking());
  }

  @override
  void dispose() {
    _ordersPollingTimer?.cancel();
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
    if (order?.pickupLatitude == null || order?.pickupLongitude == null) {
      return null;
    }
    return LatLng(order!.pickupLatitude!, order.pickupLongitude!);
  }

  LatLng? get _dropoffPoint {
    final order = _activeOrder;
    if (order?.dropoffLatitude == null || order?.dropoffLongitude == null) {
      return null;
    }
    return LatLng(order!.dropoffLatitude!, order.dropoffLongitude!);
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
    await _syncDriverLocation(position, force: true);
  }

  Future<void> _refreshOrders({bool showLoader = true}) async {
    Future<void> action() async {
      final orders = await widget.apiClient.listOrders();
      final candidate = _pickActiveOrder(orders);

      if (!mounted) return;

      setState(() {
        _activeOrder = candidate;
      });
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

  bool _isTerminalOrder(BackendOrder order) {
    return order.status == 'COMPLETED' || order.status == 'CANCELED';
  }

  BackendOrder? _pickActiveOrder(List<BackendOrder> orders) {
    final current = _activeOrder;
    if (current != null && !_isTerminalOrder(current)) {
      for (final order in orders) {
        if (order.id == current.id) {
          return order;
        }
      }
      return current;
    }

    for (final order in orders) {
      if (!_isTerminalOrder(order)) {
        return order;
      }
    }

    if (orders.isEmpty) {
      return null;
    }

    return orders.first;
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
    });
  }

  Future<void> _updateStatus(String status) async {
    final order = _activeOrder;
    if (order == null) return;

    await _runWithLoader(() async {
      final next = await widget.apiClient.updateOrderStatus(order.id, status);
      if (!mounted) return;
      setState(() {
        _activeOrder = next;
      });
    });
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
                    if (order == null)
                      Text(i18n.t('no_active_order'))
                    else ...[
                      Text(i18n.t('order_id', {'id': order.id})),
                      const SizedBox(height: 4),
                      Text(
                        i18n.t(
                          'status',
                          {
                            'value':
                                localizedOrderStatus(widget.lang, order.status)
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        i18n.t(
                          'final_price_label',
                          {'value': order.finalPrice.toStringAsFixed(0)},
                        ),
                      ),
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
                    const SizedBox(height: 12),
                    _buildStatusAction(i18n, order),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _busy ? null : () => _refreshOrders(),
                      child: Text(i18n.t('refresh_orders')),
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

  Widget _buildStatusAction(AppI18n i18n, BackendOrder? order) {
    if (order == null) {
      if (!_online) {
        return FilledButton(
          onPressed: _busy ? null : () => _toggleOnline(true),
          child: Text(_busy ? i18n.t('loading') : i18n.t('online_mode')),
        );
      }
      return FilledButton.tonal(
        onPressed: _busy ? null : () => _refreshOrders(),
        child: Text(_busy ? i18n.t('loading') : i18n.t('refresh_orders')),
      );
    }

    if (order.status == 'DRIVER_ASSIGNED') {
      return FilledButton(
        onPressed: _busy ? null : _acceptRide,
        child: Text(_busy ? i18n.t('loading') : i18n.t('accept_ride')),
      );
    }

    if (order.status == 'DRIVER_ARRIVING') {
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

    return FilledButton.tonal(
      onPressed: _busy ? null : () => _refreshOrders(),
      child: Text(_busy ? i18n.t('loading') : i18n.t('refresh_status')),
    );
  }
}
