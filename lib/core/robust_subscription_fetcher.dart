import 'dart:convert';
import 'dart:io';

/// Robust subscription fetcher with intelligent fallback
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

    // Attempt 2: Local Clash Proxy (127.0.0.1:7890)
    // Most common scenario: User has ClashX running.
    try {
      print('Attempting Local Proxy (127.0.0.1:7890)...');
      if (await _isPortOpen('127.0.0.1', 7890)) {
        final content = await _fetchViaProxy(uri, '127.0.0.1', 7890);
        if (content.isNotEmpty) return content;
      } else {
        print('Port 7890 not open, skipping...');
      }
    } catch (e) {
      print('Proxy fetch failed: $e');
      lastError = e.toString();
    }

    // Attempt 3: DoH (DNS over HTTPS)
    // Resolves domain to IP, then fetches. Useful if DNS is poisoned but IP is not blocked.
    try {
      print('Attempting DoH fallback...');
      final content = await _fetchViaDoH(uri);
      if (content.isNotEmpty) return content;
    } catch (e) {
      print('DoH fallback failed: $e');
      lastError = e.toString();
    }

    throw Exception('订阅导入失败: 请检查网络或代理设置。\\n错误详情: $lastError');
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

  static Future<String> _fetchViaDoH(Uri uri) async {
    // Simplified DoH using Cloudflare
    final dohUri = Uri.parse('https://cloudflare-dns.com/dns-query?name=${uri.host}&type=A');
    final client = HttpClient();
    try {
      final req = await client.getUrl(dohUri);
      req.headers.set('accept', 'application/dns-json');
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map;
        final answers = json['Answer'] as List?;
        if (answers != null && answers.isNotEmpty) {
          final ip = answers[0]['data'] as String;
          print('DoH resolved: $ip');
          final ipUri = uri.replace(host: ip);
          client.close(); // Close previous client
          return _fetchDirect(ipUri); // Fetch directly via IP
        }
      }
      throw Exception('DoH failed');
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
