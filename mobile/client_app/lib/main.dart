import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ClientApp());
}

enum ClientFlowStep {
  home,
  confirmRide,
  searching,
  tracking,
  completed,
}

class UiKitColors {
  static const primary = Color(0xFF2563EB);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const background = Color(0xFFF9FAFB);
  static const textPrimary = Color(0xFF111827);
}

class ClientApp extends StatelessWidget {
  const ClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.spaceGroteskTextTheme();
    return MaterialApp(
      title: 'Taxi Client MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: UiKitColors.background,
        colorScheme: const ColorScheme.light(
          primary: UiKitColors.primary,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: UiKitColors.textPrimary,
          error: UiKitColors.danger,
          onError: Colors.white,
        ),
        textTheme: baseTextTheme.copyWith(
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: UiKitColors.textPrimary),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: UiKitColors.textPrimary),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            color: UiKitColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: UiKitColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const ClientFlowPage(),
    );
  }
}

class ClientFlowPage extends StatefulWidget {
  const ClientFlowPage({super.key});

  @override
  State<ClientFlowPage> createState() => _ClientFlowPageState();
}

class _ClientFlowPageState extends State<ClientFlowPage> {
  static const _distanceKm = 8.5;
  static const _durationMin = 18.0;
  static const _baseFare = 500.0;
  static const _perKm = 120.0;
  static const _perMinute = 25.0;
  static const _tariffs = <Tariff>[
    Tariff(name: 'Economy', multiplier: 1),
    Tariff(name: 'Comfort', multiplier: 1.25),
    Tariff(name: 'Business', multiplier: 1.5),
  ];

  final TaxiApiClient _apiClient = TaxiApiClient();

  ClientFlowStep _step = ClientFlowStep.home;
  int _selectedTariff = 0;
  int _rating = 5;
  bool _isSubmitting = false;
  String? _errorMessage;
  BackendOrder? _activeOrder;

  double get _baseFormulaPrice => _baseFare + (_distanceKm * _perKm) + (_durationMin * _perMinute);

  double get _finalPrice => _baseFormulaPrice * _tariffs[_selectedTariff].multiplier;

  double get _displayPrice => _activeOrder?.finalPrice ?? _finalPrice;

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

  Future<void> _confirmRideAndRequestDriver() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _step = ClientFlowStep.searching;
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _apiClient.prepareDemoDriver();

      final order = await _apiClient.createOrder(
        cityId: 'almaty',
        distanceKm: _distanceKm,
        durationMinutes: _durationMin,
        surgeMultiplier: _tariffs[_selectedTariff].multiplier,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _activeOrder = order;
      });

      await _searchDriverForCurrentOrder(showLoader: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _searchDriverForCurrentOrder({bool showLoader = true}) async {
    final order = _activeOrder;
    if (order == null) {
      return;
    }

    if (showLoader) {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });
    }

    try {
      final assigned = await _apiClient.searchDriver(order.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeOrder = assigned;
      });

      if (assigned.driverId == null || assigned.status != 'DRIVER_ASSIGNED') {
        setState(() {
          _errorMessage = 'Driver табылмады. Қайта іздеп көріңіз.';
        });
        return;
      }

      final arriving = await _apiClient.updateOrderStatus(assigned.id, 'DRIVER_ARRIVING');

      if (!mounted) {
        return;
      }

      setState(() {
        _activeOrder = arriving;
        _step = ClientFlowStep.tracking;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted && showLoader) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _completeTrip() async {
    final order = _activeOrder;
    if (order == null || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      BackendOrder current = order;
      if (current.status != 'IN_PROGRESS') {
        current = await _apiClient.updateOrderStatus(current.id, 'IN_PROGRESS');
      }
      if (current.status != 'COMPLETED') {
        current = await _apiClient.updateOrderStatus(current.id, 'COMPLETED');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _activeOrder = current;
        _step = ClientFlowStep.completed;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _cancelOrderAndGoHome() async {
    final order = _activeOrder;
    if (order != null && order.canBeCanceled) {
      try {
        await _apiClient.updateOrderStatus(order.id, 'CANCELED');
      } catch (_) {
        // Ignore cancellation error when user just wants to leave flow.
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _activeOrder = null;
      _errorMessage = null;
      _isSubmitting = false;
      _step = ClientFlowStep.home;
    });
  }

  Widget _buildHomeScreen(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _MapBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DecoratedBox(
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
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search destination',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  ),
                ),
              ),
            ),
          ),
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
                      'Where to?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'API: ${_apiClient.baseUrl}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _step = ClientFlowStep.confirmRide),
                      child: const Text('Set Destination'),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Confirm Ride'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              child: _MapBackdrop(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tariff', style: Theme.of(context).textTheme.titleMedium),
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
                          color: isSelected ? UiKitColors.primary : const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(tariff.name),
                        subtitle: Text('x${tariff.multiplier.toStringAsFixed(2)} multiplier'),
                        trailing: Text('${price.toStringAsFixed(0)} KZT'),
                        onTap: () => setState(() => _selectedTariff = index),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    'Formula: baseFare + (km * perKm) + (minutes * perMinute)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Final: ${_finalPrice.toStringAsFixed(0)} KZT',
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
            child: Text(_isSubmitting ? 'Please wait...' : 'Confirm Ride'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingScreen(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _MapBackdrop()),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSubmitting) ...[
                      const CircularProgressIndicator(color: UiKitColors.primary),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      _isSubmitting ? 'Searching for driver...' : 'Search result',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeOrder == null
                          ? 'Creating order in backend...'
                          : 'Order: ${_activeOrder!.id.substring(0, 8)} • Status: ${_activeOrder!.status}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
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
                      child: const Text('Retry Search'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : _cancelOrderAndGoHome,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Cancel'),
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
    final status = _activeOrder?.status ?? 'DRIVER_ARRIVING';
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _MapBackdrop()),
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
                              Text('Aidos K.', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 2),
                              const Text('Toyota Camry • 001 ABC'),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      'Order ID: ${_activeOrder?.id ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: UiKitColors.danger, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.call),
                            label: const Text('Call'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _completeTrip,
                            child: Text(_isSubmitting ? 'Updating...' : 'Complete Trip'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Completed')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, size: 56, color: UiKitColors.success),
                    const SizedBox(height: 12),
                    Text(
                      '${_displayPrice.toStringAsFixed(0)} KZT',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text('Order: ${_activeOrder?.id ?? '-'}'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      children: List.generate(5, (index) {
                        final filled = index < _rating;
                        return IconButton(
                          onPressed: () => setState(() => _rating = index + 1),
                          icon: Icon(
                            filled ? Icons.star_rounded : Icons.star_border_rounded,
                            color: filled ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF),
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
              child: const Text('Book Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class Tariff {
  const Tariff({
    required this.name,
    required this.multiplier,
  });

  final String name;
  final double multiplier;
}

class BackendOrder {
  const BackendOrder({
    required this.id,
    required this.status,
    required this.finalPrice,
    required this.driverId,
  });

  final String id;
  final String status;
  final double finalPrice;
  final String? driverId;

  bool get canBeCanceled => status != 'COMPLETED' && status != 'CANCELED';

  factory BackendOrder.fromJson(Map<String, dynamic> json) {
    final dynamic rawPrice = json['finalPrice'];
    final double parsedPrice;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else {
      parsedPrice = double.tryParse(rawPrice?.toString() ?? '0') ?? 0;
    }

    final dynamic rawDriverId = json['driverId'];
    return BackendOrder(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      finalPrice: parsedPrice,
      driverId: rawDriverId?.toString(),
    );
  }
}

class TaxiApiClient {
  TaxiApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const String _demoDriverId = '3fbf77cb-0b80-4b1e-84a4-c56b9d0f4da0';
  static const String _demoPassengerId = 'f3a51fc6-fd09-4c32-8c6f-46fd019e3472';
  static const double _demoPickupLat = 43.238949;
  static const double _demoPickupLng = 76.889709;
  static const double _demoDropoffLat = 43.240978;
  static const double _demoDropoffLng = 76.924758;

  final http.Client _client;

  String get baseUrl {
    const String fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:3000/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }

    return 'http://127.0.0.1:3000/api';
  }

  Future<void> prepareDemoDriver() async {
    await _patch(
      '/drivers/$_demoDriverId/availability',
      body: const {'online': true},
    );
    await _patch(
      '/drivers/$_demoDriverId/location',
      body: const {
        'latitude': _demoPickupLat,
        'longitude': _demoPickupLng,
      },
    );
  }

  Future<BackendOrder> createOrder({
    required String cityId,
    required double distanceKm,
    required double durationMinutes,
    required double surgeMultiplier,
  }) async {
    final response = await _post(
      '/orders',
      body: {
        'passengerId': _demoPassengerId,
        'cityId': cityId,
        'pickupLatitude': _demoPickupLat,
        'pickupLongitude': _demoPickupLng,
        'dropoffLatitude': _demoDropoffLat,
        'dropoffLongitude': _demoDropoffLng,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
        'surgeMultiplier': surgeMultiplier,
      },
    );
    return BackendOrder.fromJson(_decodeAsMap(response));
  }

  Future<BackendOrder> searchDriver(String orderId) async {
    final response = await _post('/orders/$orderId/search-driver');
    return BackendOrder.fromJson(_decodeAsMap(response));
  }

  Future<BackendOrder> updateOrderStatus(String orderId, String status) async {
    final response = await _patch(
      '/orders/$orderId/status',
      body: {'status': status},
    );
    return BackendOrder.fromJson(_decodeAsMap(response));
  }

  Future<http.Response> _post(String path, {Map<String, dynamic>? body}) {
    return _client.post(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> _patch(String path, {Map<String, dynamic>? body}) {
    return _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
  }

  Map<String, dynamic> _decodeAsMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected API response: ${response.body}');
    }

    return decoded;
  }
}

class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDDEAFF),
            Color(0xFFEEF2FF),
            Color(0xFFEFF6FF),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _GridRoadPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GridRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = const Color(0x1F2563EB)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }

    final route = Paint()
      ..color = UiKitColors.primary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.58,
        size.width * 0.54,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.67,
        size.width * 0.88,
        size.height * 0.35,
      );
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
