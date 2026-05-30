import 'dart:io';

import 'package:flutter/services.dart';

/// Platform channel for macOS system proxy control
class MacOSProxyChannel {
  static const _channel = MethodChannel('com.pclash.app/proxy');

  /// Check if platform supports proxy control
  static bool get isSupported => Platform.isMacOS;

  /// Set system HTTP/SOCKS proxy
  static Future<bool> setSystemProxy({
    required bool enabled,
    required int port,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Proxy control is only supported on macOS');
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
    if (!isSupported) {
      throw UnsupportedError('Proxy control is only supported on macOS');
    }

    try {
      final result = await _channel.invokeMethod<bool>('disableProxy');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to disable proxy: ${e.message}');
    }
  }
}
