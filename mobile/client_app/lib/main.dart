import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const TaxiSuperApp());
}

enum AppRole { client, driver, admin }

enum AppLang { kz, ru }

extension AppLangX on AppLang {
  String get code {
    switch (this) {
      case AppLang.kz:
        return 'KZ';
      case AppLang.ru:
        return 'RU';
    }
  }
}

class AppI18n {
  const AppI18n(this.lang);

  final AppLang lang;

  static const Map<AppLang, Map<String, String>> _strings = {
    AppLang.kz: {
      'app_title': 'Taxi MVP',
      'role_client': 'Жолаушы',
      'role_driver': 'Жүргізуші',
      'role_admin': 'Админ',
      'login_title': 'Taxi Super App',
      'login_subtitle': 'Бір қосымша, екі рөл. KZ/RU ауыстыру дайын.',
      'api_label': 'API',
      'email_label': 'Email',
      'password_label': 'Құпиясөз',
      'demo_client': 'Demo Жолаушы',
      'demo_driver': 'Demo Жүргізуші',
      'demo_admin': 'Demo Админ',
      'sign_in': 'Кіру',
      'signing_in': 'Кіріп жатыр...',
      'language': 'Тіл',
      'logout': 'Шығу',
      'search_destination': 'Мекенжай іздеу',
      'where_to': 'Қайда барасыз?',
      'signed_as': '{email} аккаунтымен кірді',
      'set_destination': 'Маршрут таңдау',
      'confirm_ride': 'Сапарды растау',
      'tariff': 'Тариф',
      'tariff_economy': 'Эконом',
      'tariff_comfort': 'Комфорт',
      'tariff_business': 'Бизнес',
      'tariff_multiplier': 'x{value} коэффициент',
      'formula_caption':
          'Формула: baseFare + (km * perKm) + (minutes * perMinute)',
      'final_price': 'Қорытынды: {price} KZT',
      'please_wait': 'Күтіңіз...',
      'searching_driver': 'Жүргізуші ізделуде...',
      'search_result': 'Іздеу нәтижесі',
      'creating_order': 'Backend ішінде тапсырыс жасалуда...',
      'order_short': 'Тапсырыс: {id} • Күйі: {status}',
      'retry_search': 'Қайта іздеу',
      'cancel': 'Бас тарту',
      'driver_not_found': 'Жүргізуші табылмады. Қайта іздеп көріңіз.',
      'driver_name': 'Aidos K.',
      'car_info': 'Toyota Camry • 001 ABC',
      'order_id': 'Тапсырыс ID: {id}',
      'call': 'Қоңырау',
      'complete_trip': 'Сапарды аяқтау',
      'updating': 'Жаңартылуда...',
      'trip_completed': 'Сапар аяқталды',
      'order_number': 'Тапсырыс: {id}',
      'book_again': 'Қайта тапсырыс беру',
      'driver_workspace': 'Жүргізуші панелі',
      'online_mode': 'Online режим',
      'online_subtitle': 'Redis availability + геолокация жаңарту',
      'current_order': 'Ағымдағы тапсырыс',
      'no_active_order': 'Белсенді тапсырыс жоқ.',
      'status': 'Күйі: {value}',
      'final_price_label': 'Соңғы баға: {value} KZT',
      'driver_id': 'Driver ID: {value}',
      'loading': 'Жүктелуде...',
      'refresh_orders': 'Тапсырысты жаңарту',
      'accept_ride': 'Сапарды қабылдау',
      'set_arriving': 'Жолда деп белгілеу',
      'start_ride': 'Сапарды бастау',
      'complete_ride': 'Сапарды аяқтау',
      'signed_role': '{email} ({role})',
      'status_CREATED': 'Жаңа',
      'status_SEARCHING_DRIVER': 'Жүргізуші ізделуде',
      'status_DRIVER_ASSIGNED': 'Жүргізуші тағайындалды',
      'status_DRIVER_ARRIVING': 'Жүргізуші келе жатыр',
      'status_IN_PROGRESS': 'Сапар жүріп жатыр',
      'status_COMPLETED': 'Аяқталды',
      'status_CANCELED': 'Бас тартылды',
      'invalid_login_response': 'Login жауабы қате.',
      'unknown_error': 'Белгісіз қате',
    },
    AppLang.ru: {
      'app_title': 'Taxi MVP',
      'role_client': 'Клиент',
      'role_driver': 'Водитель',
      'role_admin': 'Админ',
      'login_title': 'Taxi Super App',
      'login_subtitle': 'Один клиент, две роли. Переключение KZ/RU включено.',
      'api_label': 'API',
      'email_label': 'Email',
      'password_label': 'Пароль',
      'demo_client': 'Demo Клиент',
      'demo_driver': 'Demo Водитель',
      'demo_admin': 'Demo Админ',
      'sign_in': 'Войти',
      'signing_in': 'Вход...',
      'language': 'Язык',
      'logout': 'Выйти',
      'search_destination': 'Введите адрес',
      'where_to': 'Куда поедем?',
      'signed_as': 'Вход выполнен: {email}',
      'set_destination': 'Выбрать маршрут',
      'confirm_ride': 'Подтвердить поездку',
      'tariff': 'Тариф',
      'tariff_economy': 'Эконом',
      'tariff_comfort': 'Комфорт',
      'tariff_business': 'Бизнес',
      'tariff_multiplier': 'x{value} коэффициент',
      'formula_caption':
          'Формула: baseFare + (km * perKm) + (minutes * perMinute)',
      'final_price': 'Итог: {price} KZT',
      'please_wait': 'Подождите...',
      'searching_driver': 'Ищем водителя...',
      'search_result': 'Результат поиска',
      'creating_order': 'Создаем заказ в backend...',
      'order_short': 'Заказ: {id} • Статус: {status}',
      'retry_search': 'Повторить поиск',
      'cancel': 'Отмена',
      'driver_not_found': 'Водитель не найден. Попробуйте еще раз.',
      'driver_name': 'Aidos K.',
      'car_info': 'Toyota Camry • 001 ABC',
      'order_id': 'Заказ ID: {id}',
      'call': 'Позвонить',
      'complete_trip': 'Завершить поездку',
      'updating': 'Обновление...',
      'trip_completed': 'Поездка завершена',
      'order_number': 'Заказ: {id}',
      'book_again': 'Заказать снова',
      'driver_workspace': 'Панель водителя',
      'online_mode': 'Онлайн режим',
      'online_subtitle': 'Redis availability + обновление геолокации',
      'current_order': 'Текущий заказ',
      'no_active_order': 'Активных заказов нет.',
      'status': 'Статус: {value}',
      'final_price_label': 'Итоговая цена: {value} KZT',
      'driver_id': 'Driver ID: {value}',
      'loading': 'Загрузка...',
      'refresh_orders': 'Обновить заказы',
      'accept_ride': 'Принять заказ',
      'set_arriving': 'Отметить: подъезжаю',
      'start_ride': 'Начать поездку',
      'complete_ride': 'Завершить заказ',
      'signed_role': '{email} ({role})',
      'status_CREATED': 'Новый',
      'status_SEARCHING_DRIVER': 'Поиск водителя',
      'status_DRIVER_ASSIGNED': 'Водитель назначен',
      'status_DRIVER_ARRIVING': 'Водитель подъезжает',
      'status_IN_PROGRESS': 'Поездка идет',
      'status_COMPLETED': 'Завершено',
      'status_CANCELED': 'Отменено',
      'invalid_login_response': 'Некорректный ответ login.',
      'unknown_error': 'Неизвестная ошибка',
    },
  };

  String t(String key, [Map<String, String> params = const {}]) {
    final fallback = _strings[AppLang.kz]?[key] ?? key;
    final raw = _strings[lang]?[key] ?? fallback;
    var resolved = raw;
    for (final entry in params.entries) {
      resolved = resolved.replaceAll('{${entry.key}}', entry.value);
    }
    return resolved;
  }
}

String localizedOrderStatus(AppLang lang, String status) {
  final i18n = AppI18n(lang);
  switch (status) {
    case 'CREATED':
      return i18n.t('status_CREATED');
    case 'SEARCHING_DRIVER':
      return i18n.t('status_SEARCHING_DRIVER');
    case 'DRIVER_ASSIGNED':
      return i18n.t('status_DRIVER_ASSIGNED');
    case 'DRIVER_ARRIVING':
      return i18n.t('status_DRIVER_ARRIVING');
    case 'IN_PROGRESS':
      return i18n.t('status_IN_PROGRESS');
    case 'COMPLETED':
      return i18n.t('status_COMPLETED');
    case 'CANCELED':
      return i18n.t('status_CANCELED');
    default:
      return status;
  }
}

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

enum ClientFlowStep {
  home,
  confirmRide,
  searching,
  tracking,
  completed,
}

class UiKitColors {
  static const primary = Color(0xFF0B63F6);
  static const primaryDark = Color(0xFF083B8A);
  static const accent = Color(0xFFFFB24C);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const background = Color(0xFFF3F6FB);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
}

class TaxiSuperApp extends StatefulWidget {
  const TaxiSuperApp({super.key});

  @override
  State<TaxiSuperApp> createState() => _TaxiSuperAppState();
}

class _TaxiSuperAppState extends State<TaxiSuperApp> {
  AppLang _lang = AppLang.kz;

  void _setLanguage(AppLang lang) {
    setState(() {
      _lang = lang;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();
    final i18n = AppI18n(_lang);

    return MaterialApp(
      title: i18n.t('app_title'),
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
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            color: UiKitColors.textPrimary,
            letterSpacing: -0.1,
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            color: UiKitColors.textPrimary,
            letterSpacing: -0.1,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            color: UiKitColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            color: UiKitColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: UiKitColors.primary,
            foregroundColor: Colors.white,
            textStyle: baseTextTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            foregroundColor: UiKitColors.textPrimary,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x14000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: UiKitColors.primary, width: 1.4),
          ),
        ),
      ),
      home: AuthShell(
        lang: _lang,
        onLangChanged: _setLanguage,
      ),
    );
  }
}

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
  final TextEditingController _emailController =
      TextEditingController(text: 'client@taxi.local');
  final TextEditingController _passwordController =
      TextEditingController(text: 'client123');
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
    final i18n = AppI18n(widget.lang);

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
                                  i18n.t('login_title'),
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
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: i18n.t('email_label'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: i18n.t('password_label'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _submitting
                                    ? null
                                    : () => _fillDemo(
                                          'client@taxi.local',
                                          'client123',
                                        ),
                                child: Text(i18n.t('demo_client')),
                              ),
                              OutlinedButton(
                                onPressed: _submitting
                                    ? null
                                    : () => _fillDemo(
                                          'driver@taxi.local',
                                          'driver123',
                                        ),
                                child: Text(i18n.t('demo_driver')),
                              ),
                              OutlinedButton(
                                onPressed: _submitting
                                    ? null
                                    : () => _fillDemo(
                                          'admin@taxi.local',
                                          'admin123',
                                        ),
                                child: Text(i18n.t('demo_admin')),
                              ),
                            ],
                          ),
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
                            onPressed: _submitting ? null : _login,
                            child: Text(
                              _submitting
                                  ? i18n.t('signing_in')
                                  : i18n.t('sign_in'),
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

class ClientFlowPage extends StatefulWidget {
  const ClientFlowPage({
    required this.apiClient,
    required this.session,
    required this.lang,
    super.key,
  });

  final TaxiApiClient apiClient;
  final AuthSession session;
  final AppLang lang;

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
    Tariff(nameKey: 'tariff_economy', multiplier: 1),
    Tariff(nameKey: 'tariff_comfort', multiplier: 1.25),
    Tariff(nameKey: 'tariff_business', multiplier: 1.5),
  ];

  ClientFlowStep _step = ClientFlowStep.home;
  int _selectedTariff = 0;
  int _rating = 5;
  bool _isSubmitting = false;
  String? _errorMessage;
  BackendOrder? _activeOrder;

  double get _baseFormulaPrice =>
      _baseFare + (_distanceKm * _perKm) + (_durationMin * _perMinute);

  double get _finalPrice =>
      _baseFormulaPrice * _tariffs[_selectedTariff].multiplier;

  double get _displayPrice => _activeOrder?.finalPrice ?? _finalPrice;
  AppI18n get _i18n => AppI18n(widget.lang);

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
          _errorMessage = _i18n.t('driver_not_found');
        });
        return;
      }

      final arriving = await widget.apiClient
          .updateOrderStatus(assigned.id, 'DRIVER_ARRIVING');

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
        current =
            await widget.apiClient.updateOrderStatus(current.id, 'IN_PROGRESS');
      }
      if (current.status != 'COMPLETED') {
        current =
            await widget.apiClient.updateOrderStatus(current.id, 'COMPLETED');
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
    final i18n = _i18n;

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
                child: TextField(
                  decoration: InputDecoration(
                    hintText: i18n.t('search_destination'),
                    prefixIcon: const Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
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
                      i18n.t('where_to'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      i18n.t('signed_as', {'email': widget.session.email}),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UiKitColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _step = ClientFlowStep.confirmRide),
                      child: Text(i18n.t('set_destination')),
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
    final i18n = _i18n;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(i18n.t('confirm_ride')),
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
                  Text(
                    i18n.t('tariff'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                          color: isSelected
                              ? UiKitColors.primary
                              : const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: Text(i18n.t(tariff.nameKey)),
                        subtitle: Text(
                          i18n.t(
                            'tariff_multiplier',
                            {'value': tariff.multiplier.toStringAsFixed(2)},
                          ),
                        ),
                        trailing: Text('${price.toStringAsFixed(0)} KZT'),
                        onTap: () => setState(() => _selectedTariff = index),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    i18n.t('formula_caption'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: UiKitColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i18n.t(
                      'final_price',
                      {'price': _finalPrice.toStringAsFixed(0)},
                    ),
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
            child: Text(
              _isSubmitting ? i18n.t('please_wait') : i18n.t('confirm_ride'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingScreen(BuildContext context) {
    final i18n = _i18n;

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
                      const CircularProgressIndicator(
                          color: UiKitColors.primary),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      _isSubmitting
                          ? i18n.t('searching_driver')
                          : i18n.t('search_result'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeOrder == null
                          ? i18n.t('creating_order')
                          : i18n.t(
                              'order_short',
                              {
                                'id': _activeOrder!.id.substring(0, 8),
                                'status': localizedOrderStatus(
                                  widget.lang,
                                  _activeOrder!.status,
                                ),
                              },
                            ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UiKitColors.textSecondary,
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
                      child: Text(i18n.t('retry_search')),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : _cancelOrderAndGoHome,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(i18n.t('cancel')),
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
    final i18n = _i18n;
    final status = localizedOrderStatus(
      widget.lang,
      _activeOrder?.status ?? 'DRIVER_ARRIVING',
    );

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
                              Text(i18n.t('driver_name'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(i18n.t('car_info')),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
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
                      i18n.t('order_id', {'id': _activeOrder?.id ?? '-'}),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: UiKitColors.textSecondary,
                          ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: UiKitColors.danger,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.call),
                            label: Text(i18n.t('call')),
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
                            child: Text(
                              _isSubmitting
                                  ? i18n.t('updating')
                                  : i18n.t('complete_trip'),
                            ),
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
    final i18n = _i18n;

    return Scaffold(
      appBar: AppBar(title: Text(i18n.t('trip_completed'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 56, color: UiKitColors.success),
                    const SizedBox(height: 12),
                    Text(
                      '${_displayPrice.toStringAsFixed(0)} KZT',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(i18n
                        .t('order_number', {'id': _activeOrder?.id ?? '-'})),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      children: List.generate(5, (index) {
                        final filled = index < _rating;
                        return IconButton(
                          onPressed: () => setState(() => _rating = index + 1),
                          icon: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: filled
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF9CA3AF),
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
              child: Text(i18n.t('book_again')),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverFlowPage extends StatefulWidget {
  const DriverFlowPage({
    required this.apiClient,
    required this.lang,
    super.key,
  });

  final TaxiApiClient apiClient;
  final AppLang lang;

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
    final i18n = AppI18n(widget.lang);
    final order = _activeOrder;
    final canAccept = _online &&
        order != null &&
        (order.status == 'SEARCHING_DRIVER' || order.status == 'CREATED');
    final canArriving =
        _online && order != null && order.status == 'DRIVER_ASSIGNED';
    final canStart =
        _online && order != null && order.status == 'DRIVER_ARRIVING';
    final canComplete =
        _online && order != null && order.status == 'IN_PROGRESS';

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('driver_workspace')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          const SizedBox(height: 56),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(i18n.t('online_mode')),
            subtitle: Text(i18n.t('online_subtitle')),
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
                  Text(
                    i18n.t('current_order'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (order == null)
                    Text(i18n.t('no_active_order'))
                  else ...[
                    Text(i18n.t('order_id', {'id': order.id})),
                    const SizedBox(height: 4),
                    Text(
                      i18n.t(
                        'status',
                        {
                          'value':
                              localizedOrderStatus(widget.lang, order.status)
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      i18n.t(
                        'final_price_label',
                        {'value': order.finalPrice.toStringAsFixed(0)},
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(i18n.t('driver_id', {'value': order.driverId ?? '-'})),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                          color: UiKitColors.danger,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _busy ? null : () => _refreshOrders(),
            child: Text(_busy ? i18n.t('loading') : i18n.t('refresh_orders')),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || !canAccept ? null : _acceptRide,
            child: Text(i18n.t('accept_ride')),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _busy || !canArriving
                ? null
                : () => _updateStatus('DRIVER_ARRIVING'),
            child: Text(i18n.t('set_arriving')),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed:
                _busy || !canStart ? null : () => _updateStatus('IN_PROGRESS'),
            child: Text(i18n.t('start_ride')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed:
                _busy || !canComplete ? null : () => _updateStatus('COMPLETED'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(i18n.t('complete_ride')),
          ),
        ],
      ),
    );
  }
}

class Tariff {
  const Tariff({
    required this.nameKey,
    required this.multiplier,
  });

  final String nameKey;
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
    const String fromEnv =
        String.fromEnvironment('API_BASE_URL', defaultValue: '');
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
    final userMap = (decoded['user'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

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

  Future<http.Response> _post(String path,
      {Map<String, dynamic>? body, bool includeAuth = true}) {
    return _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(includeAuth: includeAuth),
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> _patch(String path,
      {Map<String, dynamic>? body, bool includeAuth = true}) {
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
        .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }
}

class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop();

  static const LatLng _pickupPoint = LatLng(43.238949, 76.889709);
  static const LatLng _driverPoint = LatLng(43.246820, 76.906130);
  static const LatLng _dropOffPoint = LatLng(43.255388, 76.928742);
  static const LatLng _mapCenter = LatLng(43.245260, 76.910645);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: _mapCenter,
            initialZoom: 13.4,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'kz.taxi.project',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [
                    _pickupPoint,
                    _driverPoint,
                    _dropOffPoint,
                  ],
                  color: UiKitColors.primary,
                  strokeWidth: 5,
                ),
              ],
            ),
            MarkerLayer(
              markers: const [
                Marker(
                  point: _pickupPoint,
                  width: 42,
                  height: 42,
                  child: _MapPin(
                    icon: Icons.trip_origin,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
                Marker(
                  point: _driverPoint,
                  width: 42,
                  height: 42,
                  child: _MapPin(
                    icon: Icons.local_taxi,
                    color: UiKitColors.primary,
                  ),
                ),
                Marker(
                  point: _dropOffPoint,
                  width: 42,
                  height: 42,
                  child: _MapPin(
                    icon: Icons.flag_rounded,
                    color: UiKitColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Positioned(
          right: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xE6FFFFFF),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
