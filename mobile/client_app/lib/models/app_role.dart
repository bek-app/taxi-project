import '../i18n/app_i18n.dart';

enum AppRole { client, driver, admin }

extension AppRoleX on AppRole {
  String label(AppLang lang) {
    final i18n = AppI18n(lang);
    switch (this) {
      case AppRole.client:
        return i18n.t('role_client');
      case AppRole.driver:
        return i18n.t('role_driver');
      case AppRole.admin:
        return i18n.t('role_admin');
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
