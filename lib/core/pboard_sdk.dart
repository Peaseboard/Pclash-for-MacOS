import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../utils/security.dart';

/// Pboard SDK - Full API client for Pboard panels
/// 
/// This SDK allows any client to:
/// 1. Authenticate users via Pboard login
/// 2. Fetch subscription data
/// 3. Get user info (traffic, expiry, etc.)
/// 4. Manage nodes and proxy groups
/// 
/// Each customer can use this SDK to connect to their own Pboard instance
/// and build their own branded client.
class PboardSDK {
  final Dio _dio;
  final String _baseUrl;

  PboardSDK({required String baseUrl})
      : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl.replaceAll(RegExp(r'/+$'), ''),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ));

  /// Get base URL
  String get baseUrl => _baseUrl;

  // ==================== User Authentication ====================

  /// Login with email and password
  /// Returns: {token, user_id, email, role}
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/v1/passport/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data as Map<String, dynamic>;
      if (data['data'] == null) {
        throw Exception('Login failed: ${data['message']}');
      }

      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  /// Register new user
  /// Returns: {token, user_id, email}
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    try {
      final response = await _dio.post('/api/v1/passport/auth/register', data: {
        'email': email,
        'password': password,
        'invite_code': inviteCode,
      });

      final data = response.data as Map<String, dynamic>;
      if (data['data'] == null) {
        throw Exception('Registration failed: ${data['message']}');
      }

      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  /// Get current user info
  /// Requires: token in Authorization header
  Future<Map<String, dynamic>> getUserInfo(String token) async {
    try {
      final response = await _dio.get(
        '/api/v1/user/info',
        options: Options(headers: {'Authorization': token}),
      );

      final data = response.data as Map<String, dynamic>;
      if (data['data'] == null) {
        throw Exception('Failed to get user info');
      }

      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get user info: $e');
    }
  }

  /// Reset password
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/api/v1/passport/auth/resetPassword', data: {
        'email': email,
        'token': token,
        'password': newPassword,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==================== Subscription ====================

  /// Get subscription URL for the current user
  /// Returns the full Clash/Mihomo subscription URL
  String getSubscribeUrl(String token) {
    return '$_baseUrl/api/v1/client/subscribe?token=$token';
  }

  /// Fetch subscription content directly
  /// Returns raw Clash config YAML
  Future<String> fetchSubscription(String token) async {
    try {
      final response = await _dio.get(
        '/api/v1/client/subscribe',
        queryParameters: {'token': token},
        options: Options(
          headers: {'User-Agent': 'Clash.Meta'},
          responseType: ResponseType.plain,
        ),
      );

      // Parse subscription info headers
      final headers = response.headers;
      final userInfo = headers.map['subscription-userinfo']?.first;
      
      // Content could be base64 encoded or plain YAML
      String content = response.data as String;
      
      // Try to decode base64
      try {
        content = utf8.decode(base64.decode(content.trim()));
      } catch (_) {
        // Not base64, use as-is
      }

      return content;
    } catch (e) {
      throw Exception('Failed to fetch subscription: $e');
    }
  }

  // ==================== Plans & Orders ====================

  /// Get available plans
  Future<List<Map<String, dynamic>>> getPlans(String token) async {
    try {
      final response = await _dio.get(
        '/api/v1/user/plan/fetch',
        options: Options(headers: {'Authorization': token}),
      );

      final data = response.data as Map<String, dynamic>;
      if (data['data'] == null) return [];

      return (data['data'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Get user's orders
  Future<List<Map<String, dynamic>>> getOrders(String token) async {
    try {
      final response = await _dio.get(
        '/api/v1/user/order/fetch',
        options: Options(headers: {'Authorization': token}),
      );

      final data = response.data as Map<String, dynamic>;
      if (data['data'] == null) return [];

      return (data['data'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ==================== Tickets ====================

  /// Get user's tickets
  Future<List<Map<String, dynamic>>> getTickets(String token) async {
    try {
      final response = await _dio.get(
        '/api/v1/user/ticket/fetch',
        options: Options(headers: {'Authorization': token}),
      );

      final data = response.data as Map<String, dynamic>;
      if (data['data'] == null) return [];

      return (data['data'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Create a new ticket
  Future<Map<String, dynamic>?> createTicket({
    required String token,
    required String subject,
    required String message,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/user/ticket/save',
        data: {'subject': subject, 'message': message},
        options: Options(headers: {'Authorization': token}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>?;
    } catch (e) {
      throw Exception('Failed to create ticket: $e');
    }
  }

  // ==================== Utilities ====================

  /// Get server status
  Future<bool> checkConnectivity() async {
    try {
      final response = await _dio.get('/api/v1/server/status');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get panel config (public settings)
  Future<Map<String, dynamic>?> getPanelConfig() async {
    try {
      final response = await _dio.get('/api/v1/guest/config');
      final data = response.data as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Generate quick login URL (for web panel)
  String getQuickLoginUrl(String token) {
    return '$_baseUrl/api/v1/user/quickLogin?token=$token';
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}
