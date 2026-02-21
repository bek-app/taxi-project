import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api/taxi_api_client.dart';
import '../core/colors.dart';
import '../i18n/app_i18n.dart';
import '../models/backend_order.dart';

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

  @override
  void initState() {
    super.initState();
    _refreshOrders();
  }

  @override
  void dispose() {
    _ordersPollingTimer?.cancel();
    super.dispose();
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
    await _runWithLoader(() async {
      await widget.apiClient.setDriverAvailability(value);
      if (value) {
        await _updateOwnLocation();
      }

      if (!mounted) return;

      setState(() {
        _online = value;
      });

      if (value) {
        _startOrdersPolling();
        await _refreshOrders(showLoader: false);
      } else {
        _ordersPollingTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _activeOrder = null;
        });
      }
    });
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

  Future<void> _updateOwnLocation() async {
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

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    _currentPosition = position;

    await widget.apiClient.updateDriverLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> _refreshOrders({bool showLoader = true}) async {
    Future<void> action() async {
      final orders = await widget.apiClient.listOrders();
      BackendOrder? candidate;

      for (final order in orders) {
        if (order.status == 'COMPLETED' || order.status == 'CANCELED') {
          continue;
        }
        if (order.driverId != null && order.driverId!.isNotEmpty) {
          candidate = order;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        _activeOrder = candidate;
      });
    }

    if (showLoader) {
      await _runWithLoader(action);
    } else {
      await action();
    }
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

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n(widget.lang);
    final order = _activeOrder;
    final canAccept =
        _online && order != null && order.status == 'DRIVER_ASSIGNED';
    final canStart =
        _online && order != null && order.status == 'DRIVER_ARRIVING';
    final canComplete =
        _online && order != null && order.status == 'IN_PROGRESS';

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('driver_workspace')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          const SizedBox(height: 56),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(i18n.t('online_mode')),
            subtitle: Text(i18n.t('online_subtitle')),
            value: _online,
            onChanged: _busy ? null : _toggleOnline,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.t('current_order'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
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
                    const SizedBox(height: 4),
                    Text(i18n.t('driver_id', {'value': order.driverId ?? '-'})),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                          color: UiKitColors.danger,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _busy ? null : () => _refreshOrders(),
            child: Text(_busy ? i18n.t('loading') : i18n.t('refresh_orders')),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _busy ? null : () => _runWithLoader(_updateOwnLocation),
            child: Text(i18n.t('refresh_location')),
          ),
          if (_currentPosition != null) ...[
            const SizedBox(height: 8),
            Text(
              'GPS: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: UiKitColors.textSecondary,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || !canAccept ? null : _acceptRide,
            child: Text(i18n.t('accept_ride')),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed:
                _busy || !canStart ? null : () => _updateStatus('IN_PROGRESS'),
            child: Text(i18n.t('start_ride')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed:
                _busy || !canComplete ? null : () => _updateStatus('COMPLETED'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(i18n.t('complete_ride')),
          ),
        ],
      ),
    );
  }
}
