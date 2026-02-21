import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TaxiSuperApp());
}

enum AppRole { client, driver, admin }

extension AppRoleX on AppRole {
  String get label {
    switch (this) {
      case AppRole.client:
        return 'Client';
      case AppRole.driver:
        return 'Driver';
      case AppRole.admin:
        return 'Admin';
    }
  }

  String get backendValue {
    switch (this) {
      case AppRole.client:
        return 'CLIENT';
      case AppRole.driver:
        return 'DRIVER';
      case AppRole.admin:
        return 'ADMIN';
    }
  }

  static AppRole fromBackend(String value) {
    switch (value.toUpperCase()) {
      case 'DRIVER':
        return AppRole.driver;
      case 'ADMIN':
        return AppRole.admin;
      default:
        return AppRole.client;
    }
  }
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

class TaxiSuperApp extends StatelessWidget {
  const TaxiSuperApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.spaceGroteskTextTheme();
    return MaterialApp(
      title: 'Taxi MVP',
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
      home: const AuthShell(),
    );
  }
}

class AuthShell extends StatefulWidget {
  const AuthShell({super.key});

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  final TaxiApiClient _apiClient = TaxiApiClient();
  AuthSession? _session;

  void _onLoggedIn(AuthSession session) {
    setState(() {
      _session = session;
    });
  }

  void _logout() {
    _apiClient.clearAuth();
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return LoginPage(
        apiClient: _apiClient,
        onLoggedIn: _onLoggedIn,
      );
    }

    return RoleSwitcherShell(
      apiClient: _apiClient,
      session: session,
      onLogout: _logout,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.apiClient,
    required this.onLoggedIn,
    super.key,
  });

  final TaxiApiClient apiClient;
  final ValueChanged<AuthSession> onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController(text: 'client@taxi.local');
  final TextEditingController _passwordController = TextEditingController(text: 'client123');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final session = await widget.apiClient.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) {
        return;
      }
      widget.onLoggedIn(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _fillDemo(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Taxi Auth Login',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'API: ${widget.apiClient.baseUrl}',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _submitting ? null : () => _fillDemo('client@taxi.local', 'client123'),
                          child: const Text('Demo Client'),
                        ),
                        OutlinedButton(
                          onPressed: _submitting ? null : () => _fillDemo('driver@taxi.local', 'driver123'),
                          child: const Text('Demo Driver'),
                        ),
                        OutlinedButton(
                          onPressed: _submitting ? null : () => _fillDemo('admin@taxi.local', 'admin123'),
                          child: const Text('Demo Admin'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(color: UiKitColors.danger, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submitting ? null : _login,
                      child: Text(_submitting ? 'Signing in...' : 'Sign In'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleSwitcherShell extends StatefulWidget {
  const RoleSwitcherShell({
    required this.apiClient,
    required this.session,
    required this.onLogout,
    super.key,
  });

  final TaxiApiClient apiClient;
  final AuthSession session;
  final VoidCallback onLogout;

  @override
  State<RoleSwitcherShell> createState() => _RoleSwitcherShellState();
}

class _RoleSwitcherShellState extends State<RoleSwitcherShell> {
  late AppRole _activeRole;

  @override
  void initState() {
    super.initState();
    _activeRole = widget.session.role == AppRole.admin ? AppRole.client : widget.session.role;
  }

  List<AppRole> get _allowedRoles {
    if (widget.session.role == AppRole.admin) {
      return const [AppRole.client, AppRole.driver];
    }
    return [widget.session.role];
  }

  @override
  Widget build(BuildContext context) {
    final allowedRoles = _allowedRoles;

    return Stack(
      children: [
        IndexedStack(
          index: _activeRole == AppRole.driver ? 1 : 0,
          children: [
            ClientFlowPage(
              apiClient: widget.apiClient,
              session: widget.session,
            ),
            DriverFlowPage(apiClient: widget.apiClient),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text('${widget.session.email} (${widget.session.role.label})'),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SegmentedButton<AppRole>(
                    segments: allowedRoles
                        .map(
                          (role) => ButtonSegment(
                            value: role,
                            label: Text(role.label),
                            icon: Icon(role == AppRole.driver ? Icons.local_taxi_outlined : Icons.person_pin_circle_outlined),
                          ),
                        )
                        .toList(),
                    selected: <AppRole>{_activeRole},
                    onSelectionChanged: (Set<AppRole> selected) {
                      if (selected.isEmpty) {
                        return;
                      }
                      setState(() => _activeRole = selected.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      side: const WidgetStatePropertyAll(BorderSide.none),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ClientFlowPage extends StatefulWidget {
  const ClientFlowPage({
    required this.apiClient,
    required this.session,
    super.key,
  });

  final TaxiApiClient apiClient;
  final AuthSession session;

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
      await widget.apiClient.prepareDemoDriver();

      final order = await widget.apiClient.createOrder(
        passengerId: widget.session.userId,
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
      final assigned = await widget.apiClient.searchDriver(order.id);

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

      final arriving = await widget.apiClient.updateOrderStatus(assigned.id, 'DRIVER_ARRIVING');

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
        current = await widget.apiClient.updateOrderStatus(current.id, 'IN_PROGRESS');
      }
      if (current.status != 'COMPLETED') {
        current = await widget.apiClient.updateOrderStatus(current.id, 'COMPLETED');
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
        await widget.apiClient.updateOrderStatus(order.id, 'CANCELED');
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
              padding: const EdgeInsets.fromLTRB(16, 84, 16, 0),
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
                      'Signed in as: ${widget.session.email}',
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

class DriverFlowPage extends StatefulWidget {
  const DriverFlowPage({required this.apiClient, super.key});

  final TaxiApiClient apiClient;

  @override
  State<DriverFlowPage> createState() => _DriverFlowPageState();
}

class _DriverFlowPageState extends State<DriverFlowPage> {
  bool _online = false;
  bool _busy = false;
  String? _error;
  BackendOrder? _activeOrder;

  @override
  void initState() {
    super.initState();
    _refreshOrders();
  }

  Future<void> _runWithLoader(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
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
        await widget.apiClient.updateDriverLocation();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _online = value;
      });

      if (value) {
        await _refreshOrders(showLoader: false);
      } else {
        if (!mounted) {
          return;
        }
        setState(() {
          _activeOrder = null;
        });
      }
    });
  }

  Future<void> _refreshOrders({bool showLoader = true}) async {
    Future<void> action() async {
      final orders = await widget.apiClient.listOrders();
      BackendOrder? candidate;

      for (final order in orders) {
        if (order.status == 'COMPLETED' || order.status == 'CANCELED') {
          continue;
        }
        candidate = order;
        break;
      }

      if (!mounted) {
        return;
      }

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
    if (order == null) {
      return;
    }

    await _runWithLoader(() async {
      BackendOrder next = order;
      if (order.status == 'SEARCHING_DRIVER' || order.status == 'CREATED') {
        next = await widget.apiClient.searchDriver(order.id);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _activeOrder = next;
      });
    });
  }

  Future<void> _updateStatus(String status) async {
    final order = _activeOrder;
    if (order == null) {
      return;
    }

    await _runWithLoader(() async {
      final next = await widget.apiClient.updateOrderStatus(order.id, status);
      if (!mounted) {
        return;
      }
      setState(() {
        _activeOrder = next;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = _activeOrder;
    final canAccept = _online && order != null && (order.status == 'SEARCHING_DRIVER' || order.status == 'CREATED');
    final canArriving = _online && order != null && order.status == 'DRIVER_ASSIGNED';
    final canStart = _online && order != null && order.status == 'DRIVER_ARRIVING';
    final canComplete = _online && order != null && order.status == 'IN_PROGRESS';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Workspace'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          const SizedBox(height: 56),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Online mode'),
            subtitle: const Text('Redis availability + geo location update'),
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
                  Text('Current order', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (order == null)
                    const Text('Белсенді тапсырыс жоқ.')
                  else ...[
                    Text('Order ID: ${order.id}'),
                    const SizedBox(height: 4),
                    Text('Status: ${order.status}'),
                    const SizedBox(height: 4),
                    Text('Final price: ${order.finalPrice.toStringAsFixed(0)} KZT'),
                    const SizedBox(height: 4),
                    Text('Driver ID: ${order.driverId ?? '-'}'),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(color: UiKitColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _busy ? null : () => _refreshOrders(),
            child: Text(_busy ? 'Loading...' : 'Refresh Orders'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || !canAccept ? null : _acceptRide,
            child: const Text('Accept Ride'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _busy || !canArriving ? null : () => _updateStatus('DRIVER_ARRIVING'),
            child: const Text('Set Arriving'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _busy || !canStart ? null : () => _updateStatus('IN_PROGRESS'),
            child: const Text('Start Ride'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy || !canComplete ? null : () => _updateStatus('COMPLETED'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Complete Ride'),
          ),
        ],
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

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.role,
  });

  final String token;
  final String userId;
  final String email;
  final AppRole role;
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
  static const double _demoPickupLat = 43.238949;
  static const double _demoPickupLng = 76.889709;
  static const double _demoDropoffLat = 43.240978;
  static const double _demoDropoffLng = 76.924758;

  final http.Client _client;
  String? _accessToken;

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

  Future<AuthSession> login(String email, String password) async {
    final response = await _post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      includeAuth: false,
    );

    final decoded = _decodeAsMap(response);
    final token = (decoded['accessToken'] ?? '').toString();
    final userMap = (decoded['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    if (token.isEmpty || userMap.isEmpty) {
      throw Exception('Invalid login response');
    }

    final session = AuthSession(
      token: token,
      userId: (userMap['id'] ?? '').toString(),
      email: (userMap['email'] ?? '').toString(),
      role: AppRoleX.fromBackend((userMap['role'] ?? 'CLIENT').toString()),
    );

    _accessToken = token;
    return session;
  }

  void clearAuth() {
    _accessToken = null;
  }

  Future<void> prepareDemoDriver() async {
    await setDriverAvailability(true);
    await updateDriverLocation();
  }

  Future<void> setDriverAvailability(bool online) async {
    await _patch(
      '/drivers/$_demoDriverId/availability',
      body: {'online': online},
    );
  }

  Future<void> updateDriverLocation() async {
    await _patch(
      '/drivers/$_demoDriverId/location',
      body: const {
        'latitude': _demoPickupLat,
        'longitude': _demoPickupLng,
      },
    );
  }

  Future<List<BackendOrder>> listOrders() async {
    final response = await _get('/orders');
    final decoded = _decodeAsList(response);
    return decoded.map(BackendOrder.fromJson).toList(growable: false);
  }

  Future<BackendOrder> createOrder({
    required String passengerId,
    required String cityId,
    required double distanceKm,
    required double durationMinutes,
    required double surgeMultiplier,
  }) async {
    final response = await _post(
      '/orders',
      body: {
        'passengerId': passengerId,
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

  Future<http.Response> _get(String path, {bool includeAuth = true}) {
    return _client.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(includeAuth: includeAuth),
    );
  }

  Future<http.Response> _post(String path, {Map<String, dynamic>? body, bool includeAuth = true}) {
    return _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(includeAuth: includeAuth),
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> _patch(String path, {Map<String, dynamic>? body, bool includeAuth = true}) {
    return _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(includeAuth: includeAuth),
      body: body == null ? null : jsonEncode(body),
    );
  }

  Map<String, String> _headers({required bool includeAuth}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (includeAuth && _accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    return headers;
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

  List<Map<String, dynamic>> _decodeAsList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Unexpected API list response: ${response.body}');
    }

    return decoded
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
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
