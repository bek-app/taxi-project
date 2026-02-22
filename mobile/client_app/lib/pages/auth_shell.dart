import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/taxi_api_client.dart';
import '../i18n/app_i18n.dart';
import '../models/app_role.dart';
import '../models/auth_session.dart';
import '../models/user_profile.dart';
import 'client_flow_page.dart';
import 'driver_flow_page.dart';
import 'login_page.dart';
import 'orders_page.dart';
import 'profile_page.dart';

class AuthShell extends StatefulWidget {
  const AuthShell({
    required this.lang,
    required this.onLangChanged,
    super.key,
  });

  final AppLang lang;
  final ValueChanged<AppLang> onLangChanged;

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  final TaxiApiClient _apiClient = TaxiApiClient();
  AuthSession? _session;
  bool _loading = true;

  static const _kToken = 'session_token';
  static const _kUserId = 'session_user_id';
  static const _kEmail = 'session_email';
  static const _kRole = 'session_role';

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kToken);
      final userId = prefs.getString(_kUserId);
      final email = prefs.getString(_kEmail);
      final roleStr = prefs.getString(_kRole);

      if (token != null &&
          token.isNotEmpty &&
          userId != null &&
          email != null &&
          roleStr != null) {
        _apiClient.setToken(token);
        if (mounted) {
          setState(() {
            _session = AuthSession(
              token: token,
              userId: userId,
              email: email,
              role: AppRoleX.fromBackend(roleStr),
            );
          });
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onLoggedIn(AuthSession session) async {
    await _persistSession(session);
    if (mounted) setState(() => _session = session);
  }

  Future<void> _onSessionUpdated(AuthSession session) async {
    await _persistSession(session);
    if (mounted) setState(() => _session = session);
  }

  Future<void> _persistSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, session.token);
    await prefs.setString(_kUserId, session.userId);
    await prefs.setString(_kEmail, session.email);
    await prefs.setString(_kRole, session.role.backendValue);
  }

  Future<void> _logout() async {
    _apiClient.clearAuth();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kEmail);
    await prefs.remove(_kRole);
    if (mounted) setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = _session;
    if (session == null) {
      return LoginPage(
        apiClient: _apiClient,
        onLoggedIn: _onLoggedIn,
        lang: widget.lang,
        onLangChanged: widget.onLangChanged,
      );
    }

    return RoleSwitcherShell(
      apiClient: _apiClient,
      session: session,
      onLogout: _logout,
      onSessionUpdated: _onSessionUpdated,
      lang: widget.lang,
      onLangChanged: widget.onLangChanged,
    );
  }
}

class RoleSwitcherShell extends StatefulWidget {
  const RoleSwitcherShell({
    required this.apiClient,
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
    required this.lang,
    required this.onLangChanged,
    super.key,
  });

  final TaxiApiClient apiClient;
  final AuthSession session;
  final VoidCallback onLogout;
  final ValueChanged<AuthSession> onSessionUpdated;
  final AppLang lang;
  final ValueChanged<AppLang> onLangChanged;

  @override
  State<RoleSwitcherShell> createState() => _RoleSwitcherShellState();
}

class _RoleSwitcherShellState extends State<RoleSwitcherShell> {
  static const double _sidebarWidth = 292;
  late AppRole _activeRole;

  @override
  void initState() {
    super.initState();
    _activeRole = widget.session.role == AppRole.admin
        ? AppRole.client
        : widget.session.role;
  }

  List<AppRole> get _allowedRoles {
    if (widget.session.role == AppRole.admin) {
      return const [AppRole.client, AppRole.driver];
    }
    return [widget.session.role];
  }

  String get _displayName {
    final email = widget.session.email.trim();
    if (email.isEmpty) {
      return 'User';
    }

    final at = email.indexOf('@');
    final raw = at > 0 ? email.substring(0, at) : email;
    if (raw.isEmpty) {
      return email;
    }
    if (raw.length == 1) {
      return raw.toUpperCase();
    }
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  Widget _buildMainContent() {
    return IndexedStack(
      index: _activeRole == AppRole.driver ? 1 : 0,
      children: [
        ClientFlowPage(
          apiClient: widget.apiClient,
          session: widget.session,
          lang: widget.lang,
        ),
        DriverFlowPage(
          apiClient: widget.apiClient,
          lang: widget.lang,
        ),
      ],
    );
  }

  Widget _buildRoleSwitcher() {
    final allowedRoles = _allowedRoles;
    return SegmentedButton<AppRole>(
      segments: allowedRoles
          .map(
            (role) => ButtonSegment(
              value: role,
              label: Text(role.label(widget.lang)),
              icon: Icon(
                role == AppRole.driver
                    ? Icons.local_taxi_outlined
                    : Icons.person_pin_circle_outlined,
              ),
            ),
          )
          .toList(),
      selected: <AppRole>{_activeRole},
      onSelectionChanged: (selected) {
        if (selected.isNotEmpty) {
          setState(() => _activeRole = selected.first);
        }
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStatePropertyAll(BorderSide.none),
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    return SegmentedButton<AppLang>(
      segments: AppLang.values
          .map(
            (lang) => ButtonSegment<AppLang>(
              value: lang,
              label: Text(lang.code),
            ),
          )
          .toList(),
      selected: <AppLang>{widget.lang},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          widget.onLangChanged(selection.first);
        }
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStatePropertyAll(BorderSide.none),
      ),
    );
  }

  Future<void> _openOrdersPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrdersPage(
          apiClient: widget.apiClient,
          lang: widget.lang,
        ),
      ),
    );
  }

  Future<void> _openProfilePage() async {
    final profile = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute<UserProfile>(
        builder: (_) => ProfilePage(
          apiClient: widget.apiClient,
          session: widget.session,
          lang: widget.lang,
        ),
      ),
    );
    if (!mounted || profile == null) return;

    widget.onSessionUpdated(
      widget.session.copyWith(
        userId: profile.id,
        email: profile.email,
        role: profile.role,
      ),
    );

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(AppI18n(widget.lang).t('profile_saved')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSidebarPanel(AppI18n i18n) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xEBFFFFFF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            i18n.t('app_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.session.email,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _activeRole.label(widget.lang),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: _openOrdersPage,
            icon: const Icon(Icons.receipt_long_rounded),
            label: Text(i18n.t('my_trips')),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _openProfilePage,
            icon: const Icon(Icons.person_outline_rounded),
            label: Text(i18n.t('profile')),
          ),
          const SizedBox(height: 16),
          Text(
            i18n.t('register_as_label'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildRoleSwitcher(),
          const SizedBox(height: 14),
          Text(
            i18n.t('language'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildLanguageSwitcher(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: Text(i18n.t('logout')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n(widget.lang);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;
        final sidebar = _buildSidebarPanel(i18n);

        if (isWide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  SizedBox(
                    width: _sidebarWidth,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: sidebar,
                    ),
                  ),
                  Expanded(child: _buildMainContent()),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          drawer: Drawer(
            width: _sidebarWidth,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: sidebar,
              ),
            ),
          ),
          body: Stack(
            children: [
              Positioned.fill(child: _buildMainContent()),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) {
                          return IconButton.filledTonal(
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            icon: const Icon(Icons.menu_rounded),
                            tooltip: 'Menu',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
