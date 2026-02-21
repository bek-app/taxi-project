import 'package:flutter/material.dart';

import '../api/taxi_api_client.dart';
import '../core/colors.dart';
import '../i18n/app_i18n.dart';
import '../models/backend_order.dart';

enum _TripsFilter { active, history }

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    required this.apiClient,
    required this.lang,
    super.key,
  });

  final TaxiApiClient apiClient;
  final AppLang lang;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<BackendOrder> _orders = const [];
  bool _loading = true;
  String? _errorKey;
  _TripsFilter _filter = _TripsFilter.active;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  bool _isTerminalOrder(BackendOrder order) {
    return order.status == 'COMPLETED' || order.status == 'CANCELED';
  }

  List<BackendOrder> get _activeOrders {
    return _orders
        .where((order) => !_isTerminalOrder(order))
        .toList(growable: false);
  }

  List<BackendOrder> get _historyOrders {
    return _orders.where(_isTerminalOrder).toList(growable: false);
  }

  List<BackendOrder> get _visibleOrders {
    return _filter == _TripsFilter.active ? _activeOrders : _historyOrders;
  }

  Future<void> _loadOrders({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _errorKey = null;
      });
    }
    try {
      final orders = await widget.apiClient.listOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _errorKey = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorKey = 'orders_load_failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _shortOrderId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  String _formatPoint(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return '—';
    }
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DRIVER_ASSIGNED':
      case 'DRIVER_ARRIVING':
      case 'IN_PROGRESS':
        return UiKitColors.success;
      case 'COMPLETED':
        return UiKitColors.primary;
      case 'CANCELED':
        return UiKitColors.danger;
      default:
        return UiKitColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'DRIVER_ASSIGNED':
        return Icons.notifications_active_rounded;
      case 'DRIVER_ARRIVING':
        return Icons.directions_car_filled_rounded;
      case 'IN_PROGRESS':
        return Icons.route_rounded;
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      case 'CANCELED':
        return Icons.cancel_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n(widget.lang);
    return Scaffold(
      backgroundColor: UiKitColors.background,
      appBar: AppBar(
        title: Text(i18n.t('my_trips')),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadOrders(showLoader: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: i18n.t('refresh_orders'),
          ),
        ],
      ),
      body: _buildBody(i18n),
    );
  }

  Widget _buildBody(AppI18n i18n) {
    if (_loading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorKey != null && _orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                i18n.t(_errorKey!),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _loadOrders(showLoader: true),
                child: Text(i18n.t('refresh_orders')),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadOrders(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          _buildSummaryCard(i18n),
          const SizedBox(height: 12),
          _buildFilterBar(i18n),
          if (_errorKey != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                i18n.t('orders_load_failed'),
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_visibleOrders.isEmpty)
            _buildEmptyForFilter(i18n)
          else
            ..._visibleOrders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTripCard(i18n, order),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(AppI18n i18n) {
    final totalRevenue =
        _orders.fold<double>(0, (sum, order) => sum + order.finalPrice);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [UiKitColors.primary, UiKitColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x25000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t('trips_summary_total'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${totalRevenue.toStringAsFixed(0)} ₸',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: i18n.t('trips_summary_active'),
                  value: _activeOrders.length.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: i18n.t('trips_summary_history'),
                  value: _historyOrders.length.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppI18n i18n) {
    return SegmentedButton<_TripsFilter>(
      segments: [
        ButtonSegment<_TripsFilter>(
          value: _TripsFilter.active,
          label: Text('${i18n.t('trips_active')} (${_activeOrders.length})'),
          icon: const Icon(Icons.local_taxi_rounded),
        ),
        ButtonSegment<_TripsFilter>(
          value: _TripsFilter.history,
          label: Text('${i18n.t('trips_history')} (${_historyOrders.length})'),
          icon: const Icon(Icons.history_rounded),
        ),
      ],
      selected: {_filter},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        setState(() => _filter = selection.first);
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmptyForFilter(AppI18n i18n) {
    final text = _filter == _TripsFilter.active
        ? i18n.t('trips_empty_active')
        : i18n.t('trips_empty_history');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            _filter == _TripsFilter.active
                ? Icons.local_taxi_outlined
                : Icons.history_toggle_off_rounded,
            color: UiKitColors.textSecondary,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: UiKitColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(AppI18n i18n, BackendOrder order) {
    final statusColor = _statusColor(order.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withAlpha(55)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(order.status),
                        size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      localizedOrderStatus(widget.lang, order.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${order.finalPrice.toStringAsFixed(0)} ₸',
                style: const TextStyle(
                  color: UiKitColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '#${_shortOrderId(order.id)}',
            style: const TextStyle(
              color: UiKitColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          _buildPointRow(
            icon: Icons.trip_origin_rounded,
            iconColor: UiKitColors.primary,
            label: i18n.t('pickup_label'),
            value: _formatPoint(order.pickupLatitude, order.pickupLongitude),
          ),
          const SizedBox(height: 8),
          _buildPointRow(
            icon: Icons.flag_rounded,
            iconColor: UiKitColors.success,
            label: i18n.t('dropoff_label'),
            value: _formatPoint(order.dropoffLatitude, order.dropoffLongitude),
          ),
        ],
      ),
    );
  }

  Widget _buildPointRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(
              color: UiKitColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
