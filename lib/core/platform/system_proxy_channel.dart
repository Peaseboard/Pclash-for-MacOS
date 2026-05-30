import 'dart:io';

import 'package:flutter/services.dart';

/// Unified platform channel for system proxy control
/// Automatically routes to the correct platform implementation
class SystemProxyChannel {
  static const _channel = MethodChannel('com.pclash.app/proxy');

  /// Get current platform name
  static String get platformName {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  /// Check if current platform supports system proxy control
  static bool get isSupported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Set system HTTP/SOCKS proxy
  /// 
  /// Platform-specific implementation:
  /// - macOS: SystemConfiguration framework
  /// - Windows: Registry (Internet Settings)
  /// - Linux: gsettings (GNOME) / dconf
  static Future<bool> setSystemProxy({
    required bool enabled,
    required int port,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('System proxy control is not supported on $platformName');
    }

    try {
      final result = await _channel.invokeMethod<bool>('setSystemProxy', {
        'enabled': enabled,
        'port': port,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to set system proxy: ${e.message}');
    }
  }

  /// Get current proxy status
  static Future<Map<String, dynamic>?> getStatus() async {
    if (!isSupported) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getProxyStatus');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Disable system proxy
  static Future<bool> disableProxy() async {
    return setSystemProxy(enabled: false, port: 0);
  }

  /// Set up auto-start
  /// 
  /// Platform-specific implementation:
  /// - macOS: LaunchAgent plist
  /// - Windows: Registry Run key
  /// - Linux: systemd user service
  static Future<bool> setAutoStart(bool enabled) async {
    if (!isSupported) return false;

    try {
      await _channel.invokeMethod<bool>('setAutoStart', {'enabled': enabled});
      return true;
    } catch (_) {
      return false;
    }
  }
}
