import 'dart:convert';
import 'package:http/http.dart' as http;

/// Robust subscription fetcher with DNS over HTTPS fallback
/// Solves DNS pollution issues common in China by resolving IPs via DoH
/// when system DNS fails.
class RobustSubscriptionFetcher {
  // DoH providers
  static const List<Map<String, String>> dohProviders = [
    {
      'url': 'https://223.5.5.5/resolve', // AliDNS
      'name': 'AliDNS',
    },
    {
      'url': 'https://1.1.1.1/dns-query', // Cloudflare
      'name': 'Cloudflare',
    },
  ];

  /// Fetch subscription content with automatic DNS fallback
  static Future<String> fetch(String url) async {
    final uri = Uri.parse(url);
    final client = http.Client();

    try {
      // Attempt 1: Direct request using system DNS
      final response = await client.get(
        uri,
        headers: {
          'User-Agent': 'ClashX/1.0.0',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return response.body;
      }
      throw Exception('HTTP Error: ${response.statusCode}');
    } catch (e) {
      // If direct request fails (likely DNS issue), try DoH fallback
      print('Direct fetch failed: $e. Trying DoH fallback...');
      return await _fetchViaDoH(client, uri);
    } finally {
      client.close();
    }
  }

  /// Fetch using DoH resolved IP
  static Future<String> _fetchViaDoH(http.Client client, Uri uri) async {
    String? realIp;

    // Try each DoH provider
    for (final provider in dohProviders) {
      try {
        realIp = await _resolveViaDoH(provider['url']!, uri.host);
        if (realIp != null) {
          print('DoH (${provider['name']}) resolved ${uri.host} to $realIp');
          break;
        }
      } catch (e) {
        print('DoH ${provider['name']} failed: $e');
      }
    }

    if (realIp == null) {
      throw Exception('无法解析域名，请检查网络连接或域名是否有效');
    }

    // Construct IP-based URL
    final ipUrl = uri.replace(host: realIp).toString();

    // Request via IP with Host header
    final response = await client.get(
      Uri.parse(ipUrl),
      headers: {
        'User-Agent': 'ClashX/1.0.0',
        'Accept': '*/*',
        'Host': uri.host, // Crucial for virtual hosts
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return response.body;
    }
    throw Exception('IP 直连失败: HTTP ${response.statusCode}');
  }

  /// Resolve domain via DoH
  static Future<String?> _resolveViaDoH(String baseUrl, String domain) async {
    final url = '$baseUrl?name=$domain&type=A';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final answers = data['Answer'] as List?;
      if (answers != null && answers.isNotEmpty) {
        // Find the first A record (type 1)
        for (final answer in answers) {
          if (answer['type'] == 1) {
            return answer['data'] as String?;
          }
        }
      }
    }
    return null;
  }
}
