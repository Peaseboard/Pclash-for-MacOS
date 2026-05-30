import 'dart:io';

import 'package:flutter/services.dart';

/// Platform channel for Linux system proxy control
class LinuxProxyChannel {
  static const _channel = MethodChannel('com.pclash.app/proxy');

  /// Check if platform supports proxy control
  static bool get isSupported => Platform.isLinux;

  /// Set system proxy via gsettings (GNOME)
  static Future<bool> setSystemProxy({
    required bool enabled,
    required int port,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Proxy control is only supported on Linux');
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

  /// Set up auto-start via systemd user service
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
