import 'dart:convert';
import 'dart:io';

/// Robust subscription fetcher: Direct -> Hardcoded Proxy -> DoH (AliDNS)
class RobustSubscriptionFetcher {
  static Future<String> fetch(String url) async {
    // Trim whitespace to prevent "nodename nor servname" errors
    url = url.trim();
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

    // Attempt 2: Hardcoded Local Proxy (ClashX default HTTP port 7890)
    try {
      print('Attempting Hardcoded Proxy (127.0.0.1:7890)...');
      if (await _isPortOpen('127.0.0.1', 7890)) {
        final content = await _fetchViaProxy(uri, '127.0.0.1', 7890);
        if (content.isNotEmpty) return content;
      }
    } catch (e) {
      print('Hardcoded Proxy fetch failed: $e');
      lastError = 'Proxy (7890): $e';
    }

    // Attempt 3: DoH Fallback (AliDNS 223.5.5.5)
    // Resolve domain to IP via AliDNS, then fetch by IP.
    // This bypasses local DNS pollution/blocks entirely.
    try {
      print('Attempting DoH Fallback (AliDNS)...');
      final content = await _fetchViaDoH(uri);
      if (content.isNotEmpty) return content;
    } catch (e) {
      print('DoH Fallback failed: $e');
      lastError = 'DoH: $e';
    }

    throw Exception('订阅导入失败: 无法连接订阅服务器。\\n错误详情: $lastError');
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
    // 1. Resolve IP using AliDNS (223.5.5.5)
    final ip = await _resolveDnsOverHttps(uri.host);
    if (ip == null) throw Exception('Could not resolve IP via DoH');

    // 2. Fetch via IP with Host header spoofing
    print('Resolved ${uri.host} to $ip, fetching via IP...');
    final ipUri = uri.replace(host: ip);
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    try {
      final request = await client.getUrl(ipUri);
      request.headers.set('User-Agent', 'ClashX/1.0.0');
      request.headers.set('Host', uri.host); // Critical for Virtual Hosts/SNI
      final response = await request.close();
      if (response.statusCode == 200) return await response.transform(utf8.decoder).join();
      throw Exception('HTTP ${response.statusCode}');
    } finally { client.close(); }
  }

  static Future<String?> _resolveDnsOverHttps(String domain) async {
    final url = 'https://223.5.5.5/resolve?name=$domain&type=A';
    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map;
        final answers = json['Answer'] as List?;
        if (answers != null && answers.isNotEmpty) {
          // Return the first A record
          return answers[0]['data'] as String;
        }
      }
      return null;
    } catch (e) {
      print('DoH resolve failed: $e');
      return null;
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
