import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/colors.dart';
import 'i18n/app_i18n.dart';
import 'pages/auth_shell.dart';

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
