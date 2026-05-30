import 'package:flutter/material.dart';

/// Application-wide constants and configuration
class AppConstants {
  AppConstants._();

  static const String appName = 'PClash';
  static const String appVersion = '1.0.0';

  // Mihomo defaults
  static const int defaultMixedPort = 7890;
  static const int defaultApiPort = 9090;
  static const String defaultApiSecret = 'pclash-secret';
  static const String defaultApiHost = '127.0.0.1';

  // URLs
  static const String delayTestUrl = 'https://www.gstatic.com/generate_204';
  static const int delayTestTimeout = 5000;

  // Storage keys
  static const String keyApiPort = 'api_port';
  static const String keyMixedPort = 'mixed_port';
  static const String keyApiSecret = 'api_secret';
  static const String keyProxyMode = 'proxy_mode';
  static const String keySubscriptionUrl = 'subscription_url';
  static const String keyAutoStart = 'auto_start';
  static const String keyThemeMode = 'theme_mode';
  static const String keySelectedProxy = 'selected_proxy_';

  // Mihomo binary names per platform
  static const String mihomoBinaryMacOSArm64 = 'mihomo-darwin-arm64';
  static const String mihomoBinaryMacOSAmd64 = 'mihomo-darwin-amd64';
  static const String mihomoBinaryAndroidArm64 = 'mihomo-android-arm64';
  static const String mihomoBinaryAndroidAmd64 = 'mihomo-android-amd64';

  // Light theme
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    colorSchemeSeed: const Color(0xFF3B82F6),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  // Dark theme
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: const Color(0xFF3B82F6),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
