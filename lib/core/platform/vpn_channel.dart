import 'dart:io';

import 'package:flutter/services.dart';

/// Platform channel for VPN control (Android only)
class VpnChannel {
  static const _channel = MethodChannel('com.pclash.app/vpn');

  /// Check if platform supports VPN control
  static bool get isSupported => Platform.isAndroid;

  /// Start VPN service
  static Future<bool> startVpn({
    required int mihomoPort,
    required int apiPort,
    required String secret,
    String? configPath,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('VPN control is only supported on Android');
    }

    try {
      final result = await _channel.invokeMethod<bool>('startVpn', {
        'mihomoPort': mihomoPort,
        'apiPort': apiPort,
        'secret': secret,
        'configPath': configPath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to start VPN: ${e.message}');
    }
  }

  /// Stop VPN service
  static Future<bool> stopVpn() async {
    if (!isSupported) {
      throw UnsupportedError('VPN control is only supported on Android');
    }

    try {
      final result = await _channel.invokeMethod<bool>('stopVpn');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop VPN: ${e.message}');
    }
  }

  /// Check VPN status
  static Future<bool> checkStatus() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('checkVpnStatus');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
