import 'package:flutter/material.dart';

import '../api/taxi_api_client.dart';
import '../i18n/app_i18n.dart';
import '../models/backend_order.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  bool _isTerminalOrder(BackendOrder order) {
    return order.status == 'COMPLETED' || order.status == 'CANCELED';
  }

  List<BackendOrder> get _sortedOrders {
    final active = <BackendOrder>[];
    final history = <BackendOrder>[];
    for (final order in _orders) {
      if (_isTerminalOrder(order)) {
        history.add(order);
      } else {
        active.add(order);
      }
    }
    return <BackendOrder>[...active, ...history];
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

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n(widget.lang);
    return Scaffold(
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

    final sorted = _sortedOrders;
    if (sorted.isEmpty) {
      return Center(
        child: Text(
          i18n.t('orders_list_empty'),
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadOrders(showLoader: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final order = sorted[index];
          final isTerminal = _isTerminalOrder(order);

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTerminal
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFFBFDBFE),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${_shortOrderId(order.id)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localizedOrderStatus(widget.lang, order.status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isTerminal
                              ? const Color(0xFF64748B)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${order.finalPrice.toStringAsFixed(0)} ₸',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
