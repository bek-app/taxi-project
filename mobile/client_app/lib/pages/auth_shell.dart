import 'package:flutter/material.dart';

import '../api/taxi_api_client.dart';
import '../i18n/app_i18n.dart';
import '../models/app_role.dart';
import '../models/auth_session.dart';
import 'client_flow_page.dart';
import 'driver_flow_page.dart';
import 'login_page.dart';

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
        lang: widget.lang,
        onLangChanged: widget.onLangChanged,
      );
    }

    return RoleSwitcherShell(
      apiClient: _apiClient,
      session: session,
      onLogout: _logout,
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
    required this.lang,
    required this.onLangChanged,
    super.key,
  });

  final TaxiApiClient apiClient;
  final AuthSession session;
  final VoidCallback onLogout;
  final AppLang lang;
  final ValueChanged<AppLang> onLangChanged;

  @override
  State<RoleSwitcherShell> createState() => _RoleSwitcherShellState();
}

class _RoleSwitcherShellState extends State<RoleSwitcherShell> {
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

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n(widget.lang);
    final allowedRoles = _allowedRoles;

    return Stack(
      children: [
        IndexedStack(
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
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xEBFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        i18n.t(
                          'signed_role',
                          {
                            'email': widget.session.email,
                            'role': widget.session.role.label(widget.lang),
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SegmentedButton<AppRole>(
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
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SegmentedButton<AppLang>(
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
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout),
                      tooltip: i18n.t('logout'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
