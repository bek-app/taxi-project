import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/taxi_api_client.dart';
import '../core/colors.dart';
import '../i18n/app_i18n.dart';
import '../models/app_role.dart';
import '../models/auth_session.dart';
import '../models/user_profile.dart';
import 'client_flow_page.dart';
import 'driver_flow_page.dart';
import 'login_page.dart';
import 'orders_page.dart';
import 'profile_page.dart';

enum _ShellView { workspace, orders, profile }

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
  _ShellView _activeView = _ShellView.workspace;

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

  void _showProfileSavedMessage() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(AppI18n(widget.lang).t('profile_saved')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyProfileUpdate(UserProfile profile) {
    widget.onSessionUpdated(
      widget.session.copyWith(
        userId: profile.id,
        email: profile.email,
        role: profile.role,
      ),
    );
    _showProfileSavedMessage();
  }

  Widget _buildMainContent() {
    switch (_activeView) {
      case _ShellView.orders:
        return OrdersPage(
          apiClient: widget.apiClient,
          lang: widget.lang,
        );
      case _ShellView.profile:
        return ProfilePage(
          apiClient: widget.apiClient,
          session: widget.session,
          lang: widget.lang,
          onLangChanged: widget.onLangChanged,
          popOnSave: false,
          onSaved: _applyProfileUpdate,
        );
      case _ShellView.workspace:
        break;
    }

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
          setState(() {
            _activeRole = selected.first;
            _activeView = _ShellView.workspace;
          });
        }
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStatePropertyAll(BorderSide.none),
      ),
    );
  }

  Future<void> _closeDrawerIfOpen() async {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _openWorkspace({required bool isWideLayout}) async {
    if (isWideLayout) {
      if (!mounted) return;
      setState(() => _activeView = _ShellView.workspace);
      return;
    }
    await _closeDrawerIfOpen();
  }

  Future<void> _openOrdersPage({required bool isWideLayout}) async {
    if (isWideLayout) {
      if (!mounted) return;
      setState(() => _activeView = _ShellView.orders);
      return;
    }

    await _closeDrawerIfOpen();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrdersPage(
          apiClient: widget.apiClient,
          lang: widget.lang,
        ),
      ),
    );
  }

  Future<void> _openProfilePage({required bool isWideLayout}) async {
    if (isWideLayout) {
      if (!mounted) return;
      setState(() => _activeView = _ShellView.profile);
      return;
    }

    await _closeDrawerIfOpen();
    if (!mounted) return;
    final profile = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute<UserProfile>(
        builder: (_) => ProfilePage(
          apiClient: widget.apiClient,
          session: widget.session,
          lang: widget.lang,
          onLangChanged: widget.onLangChanged,
        ),
      ),
    );
    if (!mounted || profile == null) return;
    _applyProfileUpdate(profile);
  }

  Widget _buildSidebarActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Material(
      color: selected ? const Color(0xFFE8F0FF) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFDCE7FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? UiKitColors.primary : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? UiKitColors.primary : null,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.chevron_right_rounded,
                color: selected ? UiKitColors.primary : const Color(0xFF94A3B8),
                size: selected ? 18 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarSection({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _buildSidebarPanel(
    AppI18n i18n, {
    required bool isDrawer,
    required bool isWideLayout,
  }) {
    final canSwitchRole = _allowedRoles.length > 1;
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    i18n.t('app_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isDrawer)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 18,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
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
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _activeRole.label(widget.lang),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF0F766E),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSidebarSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          i18n.t('workspace'),
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        _buildSidebarActionTile(
                          onTap: () {
                            _openWorkspace(isWideLayout: isWideLayout);
                          },
                          icon: Icons.dashboard_outlined,
                          title: i18n.t('workspace'),
                          selected: isWideLayout &&
                              _activeView == _ShellView.workspace,
                        ),
                        const SizedBox(height: 8),
                        _buildSidebarActionTile(
                          onTap: () {
                            _openOrdersPage(isWideLayout: isWideLayout);
                          },
                          icon: Icons.receipt_long_rounded,
                          title: i18n.t('my_trips'),
                          selected:
                              isWideLayout && _activeView == _ShellView.orders,
                        ),
                        const SizedBox(height: 8),
                        _buildSidebarActionTile(
                          onTap: () {
                            _openProfilePage(isWideLayout: isWideLayout);
                          },
                          icon: Icons.person_outline_rounded,
                          title: i18n.t('profile'),
                          selected:
                              isWideLayout && _activeView == _ShellView.profile,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (canSwitchRole) ...[
                    _buildSidebarSection(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            i18n.t('register_as_label'),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          _buildRoleSwitcher(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: Text(i18n.t('logout')),
            ),
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
        final sidebar = _buildSidebarPanel(
          i18n,
          isDrawer: !isWide,
          isWideLayout: isWide,
        );
        final drawerWidth = constraints.maxWidth < 380
            ? constraints.maxWidth - 16
            : _sidebarWidth;

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
            width: drawerWidth,
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
