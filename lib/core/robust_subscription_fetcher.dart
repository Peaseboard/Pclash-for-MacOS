import 'dart:convert';
import 'dart:io';

/// Robust subscription fetcher with DNS over HTTPS fallback and Proxy support
/// Solves DNS pollution issues common in China by resolving IPs via DoH
/// when system DNS fails, and falls back to system proxy if needed.
class RobustSubscriptionFetcher {
  static const List<Map<String, String>> dohProviders = [
    {'url': 'https://223.5.5.5/resolve', 'name': 'AliDNS'},
    {'url': 'https://1.1.1.1/dns-query', 'name': 'Cloudflare'},
  ];

  static Future<String> fetch(String url) async {
    final uri = Uri.parse(url);
    String? lastError;

    try {
      print('[Fetcher] Attempting direct fetch...');
      final content = await _fetchDirect(uri);
      if (content.isNotEmpty) return content;
    } catch (e) { lastError = e.toString(); }

    try {
      print('[Fetcher] Attempting proxy fallback (127.0.0.1:7890)...');
      final content = await _fetchViaProxy(uri, '127.0.0.1', 7890);
      if (content.isNotEmpty) return content;
    } catch (e) { lastError = e.toString(); }

    try {
      print('[Fetcher] Attempting proxy fallback (127.0.0.1:7891)...');
      final content = await _fetchViaProxy(uri, '127.0.0.1', 7891);
      if (content.isNotEmpty) return content;
    } catch (e) { lastError = e.toString(); }

    try {
      print('[Fetcher] Attempting DoH fallback...');
      final content = await _fetchViaDoH(uri);
      if (content.isNotEmpty) return content;
    } catch (e) { lastError = e.toString(); }

    throw Exception('Import failed. Please check network or proxy status.');
  }

  static Future<String> _fetchDirect(Uri uri) async {
    final client = HttpClient();
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
    try {
      client.findProxy = (url) => 'PROXY $host:$port';
      client.badCertificateCallback = (c, h, p) => true;
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'ClashX/1.0.0');
      final response = await request.close();
      if (response.statusCode == 200) return await response.transform(utf8.decoder).join();
      throw Exception('HTTP ${response.statusCode}');
    } finally { client.close(); }
  }

  static Future<String> _fetchViaDoH(Uri uri) async {
    String? realIp;
    for (final p in dohProviders) {
      try {
        realIp = await _resolveViaDoH(p['url']!, uri.host);
        if (realIp != null) break;
      } catch (e) {}
    }
    if (realIp == null) throw Exception('DoH resolution failed');
    
    final ipUri = uri.replace(host: realIp);
    final client = HttpClient();
    try {
      final request = await client.getUrl(ipUri);
      request.headers.set('User-Agent', 'ClashX/1.0.0');
      request.headers.set('Host', uri.host);
      final response = await request.close();
      if (response.statusCode == 200) return await response.transform(utf8.decoder).join();
      throw Exception('HTTP ${response.statusCode}');
    } finally { client.close(); }
  }

  static Future<String?> _resolveViaDoH(String baseUrl, String domain) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse("$baseUrl?name=$domain&type=A"));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final answers = dat['Answer'] as List?;
        if (answers != null) {
          for (final a in answers) {
            if (a['type'] == 1) return a['data'] as String?;
          }
        }
      }
      return null;
    } finally { client.close(); }
  }
}
