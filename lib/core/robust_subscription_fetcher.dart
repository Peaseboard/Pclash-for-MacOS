import 'dart:convert';
import 'package:http/http.dart' as http;

/// Robust subscription fetcher: Direct -> Multi-DoH Fallback (No external proxy needed)
class RobustSubscriptionFetcher {
  // Domestic & International DoH providers to bypass DNS pollution
  static const List<String> dohProviders = [
    'https://223.5.5.5/resolve',       // AliDNS
    'https://doh.pub/dns-query',       // Tencent DNSPod
    'https://dns.alidns.com/dns-query', // AliDNS HTTPS
    'https://dns.google/resolve',      // Google
    'https://1.1.1.1/dns-query',       // Cloudflare
  ];

  static Future<String> fetch(String url) async {
    url = url.trim();
    if (url.isEmpty) throw Exception('URL 为空');
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://' + url;
    }
    final uri = Uri.parse(url);
    String? lastError;
    final headers = {'User-Agent': 'ClashX/1.0.0', 'Accept': '*/*'};

    // 1. Direct (System DNS)
    try {
      print('Attempting direct fetch...');
      final res = await http.get(uri, headers: headers).timeout(Duration(seconds: 10));
      if (res.statusCode == 200) return res.body;
    } catch (e) {
      print('Direct fetch failed: $e');
      lastError = 'Direct: $e';
    }

    // 2. DoH Fallbacks (Try multiple providers until one works)
    for (final providerUrl in dohProviders) {
      try {
        print('Attempting DoH via $providerUrl...');
        final ip = await _resolveViaDoh(providerUrl, uri.host);
        if (ip != null) {
          print('✅ Resolved ${uri.host} to $ip via DoH. Fetching via IP...');
          final ipUri = uri.replace(host: ip);
          // Crucial: Host header must be the original domain, otherwise the CDN rejects it
          final ipHeaders = {...headers, 'Host': uri.host};
          final res = await http.get(ipUri, headers: ipHeaders).timeout(Duration(seconds: 15));
          if (res.statusCode == 200) return res.body;
        }
      } catch (e) {
        print('DoH via $providerUrl failed: $e');
        lastError = 'DoH(${Uri.parse(providerUrl).host}): $e';
      }
    }

    throw Exception('订阅导入失败: 无法解析域名或连接被拒绝。\n请尝试在浏览器中打开链接并手动导入本地文件。\n错误详情: $lastError');
  }

  static Future<String?> _resolveViaDoh(String baseUrl, String domain) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'name': domain, 'type': 'A'});
    final res = await http.get(uri, headers: {'Accept': 'application/dns-json'}).timeout(Duration(seconds: 5));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map;
      final answers = json['Answer'] as List?;
      if (answers != null && answers.isNotEmpty) {
        return answers[0]['data'] as String;
      }
    }
    return null;
  }
}
