import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/taxi_api_client.dart';
import '../core/colors.dart';
import '../i18n/app_i18n.dart';
import '../models/app_role.dart';
import '../models/auth_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.apiClient,
    required this.onLoggedIn,
    required this.lang,
    required this.onLangChanged,
    super.key,
  });

  final TaxiApiClient apiClient;
  final ValueChanged<AuthSession> onLoggedIn;
  final AppLang lang;
  final ValueChanged<AppLang> onLangChanged;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _registerMode = false;
  AppRole _registerRole = AppRole.client;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  static const _kEmailKey = 'saved_email';

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kEmailKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      _emailController.text = saved;
    }
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmailKey, email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) return;

    if (_registerMode && password != _confirmPasswordController.text) {
      setState(() {
        _error = AppI18n(widget.lang).t('password_mismatch');
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final session = _registerMode
          ? await widget.apiClient.register(email, password, _registerRole)
          : await widget.apiClient.login(email, password);

      await _saveEmail(email);

      if (!mounted) return;
      widget.onLoggedIn(session);
    } catch (error) {
      if (!mounted) return;
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

  void _switchMode(bool registerMode) {
    setState(() {
      _registerMode = registerMode;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n(widget.lang);
    final isRegister = _registerMode;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF061A3A),
              Color(0xFF0B63F6),
              Color(0xFF41A4FF),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -90,
              right: -40,
              child: CircleAvatar(
                radius: 120,
                backgroundColor: Color(0x33FFFFFF),
              ),
            ),
            const Positioned(
              bottom: -80,
              left: -30,
              child: CircleAvatar(
                radius: 110,
                backgroundColor: Color(0x22FFB24C),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  i18n.t(isRegister ? 'register' : 'sign_in'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
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
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            i18n.t('login_subtitle'),
                            style: const TextStyle(
                                color: UiKitColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${i18n.t('api_label')}: ${widget.apiClient.baseUrl}',
                            style: const TextStyle(
                                color: UiKitColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          AutofillGroup(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: InputDecoration(
                                    labelText: i18n.t('email_label'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  autofillHints: isRegister
                                      ? const [AutofillHints.newPassword]
                                      : const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: i18n.t('password_label'),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined),
                                      onPressed: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isRegister) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: i18n.t('confirm_password_label'),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              i18n.t('register_as_label'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<AppRole>(
                              segments: const [
                                ButtonSegment(
                                  value: AppRole.client,
                                  icon: Icon(Icons.person_pin_circle_outlined),
                                  label: Text('CLIENT'),
                                ),
                                ButtonSegment(
                                  value: AppRole.driver,
                                  icon: Icon(Icons.local_taxi_outlined),
                                  label: Text('DRIVER'),
                                ),
                              ],
                              selected: <AppRole>{_registerRole},
                              onSelectionChanged: _submitting
                                  ? null
                                  : (selection) {
                                      if (selection.isNotEmpty) {
                                        setState(() {
                                          _registerRole = selection.first;
                                        });
                                      }
                                    },
                              showSelectedIcon: false,
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: UiKitColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: Text(
                              _submitting
                                  ? i18n.t(isRegister
                                      ? 'registering'
                                      : 'signing_in')
                                  : i18n.t(
                                      isRegister ? 'register' : 'sign_in'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => _switchMode(!isRegister),
                            child: Text(
                              i18n.t(
                                isRegister
                                    ? 'auth_switch_to_login'
                                    : 'auth_switch_to_register',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
