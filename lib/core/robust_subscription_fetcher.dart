import 'dart:convert';
import 'dart:io';

/// Robust subscription fetcher: Direct -> Local Proxy (ClashX)
class RobustSubscriptionFetcher {
  static Future<String> fetch(String url) async {
    final uri = Uri.parse(url);
    String? lastError;

    // Attempt 1: Direct
    try {
      print('Attempting direct fetch...');
      final content = await _fetchDirect(uri);
      if (content.isNotEmpty) return content;
    } catch (e) {
      print('Direct fetch failed: $e');
      lastError = e.toString();
    }

    // Attempt 2: Local Proxy (ClashX default HTTP port 7890)
    // Since ClashX works, routing through it is the most reliable method.
    try {
      print('Attempting Local Proxy (127.0.0.1:7890)...');
      if (await _isPortOpen('127.0.0.1', 7890)) {
        final content = await _fetchViaProxy(uri, '127.0.0.1', 7890);
        if (content.isNotEmpty) return content;
      }
    } catch (e) {
      print('Proxy fetch failed: $e');
      lastError = 'Proxy (7890): $e';
    }

    throw Exception('订阅导入失败: 请确保 ClashX 正在运行 (端口 7890)。\\n错误详情: $lastError');
  }

  static Future<String> _fetchDirect(Uri uri) async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    try {
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'ClashX/1.0.0');
      final response = await request.close();
      if (response.statusCode == 200) return await response.transform(utf8.decoder).join();
      throw Exception('HTTP ${response.statusCode}');
    } finally { client.close(); }
  }

  static Future<String> _fetchViaProxy(Uri uri, String host, int port) async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    client.findProxy = (url) => 'PROXY $host:$port';
    try {
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'ClashX/1.0.0');
      final response = await request.close();
      if (response.statusCode == 200) return await response.transform(utf8.decoder).join();
      throw Exception('HTTP ${response.statusCode}');
    } finally { client.close(); }
  }

  static Future<bool> _isPortOpen(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port, timeout: Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
