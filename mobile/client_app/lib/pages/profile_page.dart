import 'package:flutter/material.dart';

import '../api/taxi_api_client.dart';
import '../core/colors.dart';
import '../i18n/app_i18n.dart';
import '../models/app_role.dart';
import '../models/auth_session.dart';
import '../models/user_profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.apiClient,
    required this.session,
    required this.lang,
    super.key,
  });

  final TaxiApiClient apiClient;
  final AuthSession session;
  final AppLang lang;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;
  UserProfile? _profile;

  AppI18n get _i18n => AppI18n(widget.lang);

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.session.email;
    _loadProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await widget.apiClient.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _emailController.text = profile.email;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final email = _emailController.text.trim();
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmNewPassword = _confirmNewPasswordController.text;
    final wantsPasswordChange =
        newPassword.isNotEmpty || confirmNewPassword.isNotEmpty;

    if (email.isEmpty) {
      setState(() => _error = _i18n.t('profile_email_required'));
      return;
    }

    if (wantsPasswordChange) {
      if (currentPassword.isEmpty) {
        setState(() => _error = _i18n.t('profile_current_password_required'));
        return;
      }
      if (newPassword.length < 6) {
        setState(() => _error = _i18n.t('profile_new_password_min'));
        return;
      }
      if (newPassword != confirmNewPassword) {
        setState(() => _error = _i18n.t('password_mismatch'));
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = await widget.apiClient.updateMyProfile(
        email: email,
        currentPassword: wantsPasswordChange ? currentPassword : null,
        newPassword: wantsPasswordChange ? newPassword : null,
      );
      if (!mounted) return;

      setState(() {
        _profile = profile;
        _emailController.text = profile.email;
      });

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmNewPasswordController.clear();

      Navigator.of(context).pop(profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = _i18n;
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('profile')),
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _loadProfile,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: i18n.t('refresh_profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        i18n.t('profile_title'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i18n.t('profile_subtitle'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: UiKitColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 14),
                      if (profile != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar:
                                  const Icon(Icons.badge_outlined, size: 18),
                              label: Text(
                                i18n.t('profile_user_id', {'id': profile.id}),
                              ),
                            ),
                            Chip(
                              avatar:
                                  const Icon(Icons.shield_outlined, size: 18),
                              label: Text(profile.role.label(widget.lang)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: i18n.t('email_label'),
                          hintText: 'user@example.com',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        i18n.t('profile_password_section'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        i18n.t('profile_password_hint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: UiKitColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _currentPasswordController,
                        enabled: !_saving,
                        obscureText: _obscureCurrent,
                        decoration: InputDecoration(
                          labelText: i18n.t('profile_current_password'),
                          suffixIcon: IconButton(
                            onPressed: _saving
                                ? null
                                : () => setState(
                                      () => _obscureCurrent = !_obscureCurrent,
                                    ),
                            icon: Icon(
                              _obscureCurrent
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _newPasswordController,
                        enabled: !_saving,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          labelText: i18n.t('profile_new_password'),
                          suffixIcon: IconButton(
                            onPressed: _saving
                                ? null
                                : () =>
                                    setState(() => _obscureNew = !_obscureNew),
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmNewPasswordController,
                        enabled: !_saving,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: i18n.t('profile_confirm_new_password'),
                          suffixIcon: IconButton(
                            onPressed: _saving
                                ? null
                                : () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: UiKitColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_loading) ...[
                        const SizedBox(height: 14),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: (_saving || _loading) ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? i18n.t('saving_changes')
                              : i18n.t('save_changes'),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
