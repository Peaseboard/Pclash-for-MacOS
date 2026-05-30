import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/proxy.dart';
import '../models/traffic_stats.dart';
import '../utils/constants.dart';

/// REST API client for Mihomo external-controller
class MihomoApi {
  final Dio _dio;
  final String _host;
  final int _port;
  final String _secret;

  MihomoApi({
    required String host,
    required int port,
    String? secret,
  })  : _host = host,
        _port = port,
        _secret = secret ?? '',
        _dio = Dio(BaseOptions(
          baseUrl: 'http://$host:$port',
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Authorization': 'Bearer ${secret ?? ''}',
          },
        ));

  String get baseUrl => 'http://$_host:$_port';

  /// Get all proxies
  Future<Map<String, Proxy>> getProxies() async {
    try {
      final response = await _dio.get('/proxies');
      final data = response.data as Map<String, dynamic>;
      final proxies = <String, Proxy>{};
      for (final entry in data.entries) {
        proxies[entry.key] = Proxy.fromJson(entry.value as Map<String, dynamic>);
      }
      return proxies;
    } catch (e) {
      throw Exception('Failed to get proxies: $e');
    }
  }

  /// Get version info
  Future<Map<String, dynamic>> getVersion() async {
    try {
      final response = await _dio.get('/version');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get version: $e');
    }
  }

  /// Get current config
  Future<Map<String, dynamic>> getConfig() async {
    try {
      final response = await _dio.get('/configs');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get config: $e');
    }
  }

  /// Update config
  Future<void> updateConfig(Map<String, dynamic> patch) async {
    try {
      await _dio.patch('/configs', data: patch);
    } catch (e) {
      throw Exception('Failed to update config: $e');
    }
  }

  /// Reload config (after updating subscription)
  Future<void> reloadConfig(String configPath) async {
    try {
      await _dio.put(
        '/configs',
        queryParameters: {'force': 'true'},
        data: {'path': configPath, 'payload': ''},
      );
    } catch (e) {
      throw Exception('Failed to reload config: $e');
    }
  }

  /// Set proxy mode (rule/global/direct)
  Future<void> setMode(String mode) async {
    try {
      await _dio.patch('/configs', data: {'mode': mode});
    } catch (e) {
      throw Exception('Failed to set mode: $e');
    }
  }

  /// Select proxy in a group
  Future<void> selectProxy(String groupName, String proxyName) async {
    try {
      await _dio.put(
        '/proxies/${Uri.encodeComponent(groupName)}',
        data: {'name': proxyName},
      );
    } catch (e) {
      throw Exception('Failed to select proxy: $e');
    }
  }

  /// Test delay for a single proxy
  Future<int?> testDelay(String proxyName, {String? url, int? timeout}) async {
    try {
      final response = await _dio.get(
        '/proxies/${Uri.encodeComponent(proxyName)}/delay',
        queryParameters: {
          'url': url ?? AppConstants.delayTestUrl,
          'timeout': timeout ?? AppConstants.delayTestTimeout,
        },
      );
      return response.data['delay'] as int?;
    } catch (e) {
      return null;
    }
  }

  /// Test delay for all proxies in a group
  Future<void> testGroupDelay(String groupName, {String? url, int? timeout}) async {
    try {
      await _dio.get(
        '/group/${Uri.encodeComponent(groupName)}/delay',
        queryParameters: {
          'url': url ?? AppConstants.delayTestUrl,
          'timeout': timeout ?? AppConstants.delayTestTimeout,
        },
      );
    } catch (e) {
      throw Exception('Failed to test group delay: $e');
    }
  }

  /// Close all connections
  Future<void> closeAllConnections() async {
    try {
      await _dio.delete('/connections');
    } catch (e) {
      throw Exception('Failed to close connections: $e');
    }
  }

  /// Get traffic stats (one-shot)
  Future<TrafficStats> getTraffic() async {
    try {
      final response = await _dio.get('/traffic');
      return TrafficStats.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return const TrafficStats(up: 0, down: 0);
    }
  }

  /// Stream real-time traffic via WebSocket
  Stream<TrafficStats> trafficStream() {
    final wsUrl = 'ws://$_host:$_port/traffic';
    final channel = WebSocketChannel.connect(
      Uri.parse(wsUrl),
    );

    return channel.stream.map((event) {
      final data = jsonDecode(event as String) as Map<String, dynamic>;
      return TrafficStats.fromJson(data);
    }).handleError((_) {
      channel.sink.close();
      return const TrafficStats(up: 0, down: 0);
    });
  }

  /// Stream real-time logs via WebSocket
  Stream<Map<String, dynamic>> logStream({String level = 'info'}) {
    final wsUrl = 'ws://$_host:$_port/logs?level=$level';
    final channel = WebSocketChannel.connect(
      Uri.parse(wsUrl),
    );

    return channel.stream.map((event) {
      return jsonDecode(event as String) as Map<String, dynamic>;
    });
  }

  /// Stream connections via WebSocket
  Stream<Map<String, dynamic>> connectionsStream({int interval = 1000}) {
    final wsUrl = 'ws://$_host:$_port/connections?interval=$interval';
    final channel = WebSocketChannel.connect(
      Uri.parse(wsUrl),
    );

    return channel.stream.map((event) {
      return jsonDecode(event as String) as Map<String, dynamic>;
    });
  }

  /// Update GEO database
  Future<void> updateGeo() async {
    try {
      await _dio.post('/configs/geo');
    } catch (e) {
      throw Exception('Failed to update GEO: $e');
    }
  }

  /// Check if API is reachable
  Future<bool> isApiAvailable() async {
    try {
      await _dio.get('/version');
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _dio.close();
  }
}
