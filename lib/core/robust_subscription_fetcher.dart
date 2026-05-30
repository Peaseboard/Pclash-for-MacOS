import "dart:convert";
import "package:dio/dio.dart";

/// Robust subscription fetcher with DNS over HTTPS fallback
/// Solves DNS pollution issues common in China by resolving IPs via DoH
/// when system DNS fails.
class RobustSubscriptionFetcher {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      "User-Agent": "ClashX/1.120.0",
      "Accept": "*/*",
    },
  ));

  // DoH providers - multiple fallback options
  static const List<Map<String, String>> dohProviders = [
    {"url": "https://223.5.5.5/resolve", "name": "AliDNS"},
    {"url": "https://dns.alidns.com/resolve", "name": "AliDNS-HTTPS"},
    {"url": "https://1.1.1.1/dns-query", "name": "Cloudflare"},
    {"url": "https://dns.pub/dns-query", "name": "DNSPod"},
    {"url": "https://8.8.8.8/resolve", "name": "GoogleDNS"},
  ];

  /// Fetch subscription content with automatic DNS fallback
  static Future<String> fetch(String url) async {
    final uri = Uri.parse(url);
    print("[RobustFetcher] Attempting to fetch: ${uri.host}");

    // Attempt 1: Direct request using system DNS
    try {
      print("[RobustFetcher] Attempt 1: Direct request via system DNS...");
      final response = await _dio.get<String>(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        print("[RobustFetcher] Direct fetch succeeded (${response.data!.length} bytes)");
        return _decodeSubscription(response.data!);
      }
      throw Exception("HTTP ${response.statusCode}");
    } catch (e) {
      print("[RobustFetcher] Direct fetch failed: $e");
      print("[RobustFetcher] Attempt 2: DoH fallback...");
    }

    // Attempt 2: DoH fallback - resolve IP then connect directly
    try {
      return await _fetchViaDoH(uri);
    } catch (e) {
      print("[RobustFetcher] DoH fallback failed: $e");
    }

    // Attempt 3: Try with different User-Agent and headers
    try {
      print("[RobustFetcher] Attempt 3: Alternative headers...");
      final response = await _dio.get<String>(
        url,
        options: Options(
          headers: {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Accept": "application/json, text/plain, */*",
          },
        ),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        print("[RobustFetcher] Alternative headers succeeded");
        return _decodeSubscription(response.data!);
      }
    } catch (e) {
      print("[RobustFetcher] Alternative headers failed: $e");
    }

    throw Exception("订阅导入失败: 所有连接方式均失败。请检查:\n1. 网络连接是否正常\n2. 订阅 URL 是否有效\n3. 是否需要代理才能访问该订阅");
  }

  /// Fetch using DoH resolved IP
  static Future<String> _fetchViaDoH(Uri uri) async {
    String? realIp;
    String? usedProvider;

    for (final provider in dohProviders) {
      try {
        realIp = await _resolveViaDoH(provider["url"]!, uri.host);
        if (realIp != null) {
          usedProvider = provider["name"];
          print("[RobustFetcher] DoH ($usedProvider) resolved ${uri.host} -> $realIp");
          break;
        }
      } catch (e) {
        print("[RobustFetcher] DoH ${provider["name"]} failed: $e");
      }
    }

    if (realIp == null) {
      throw Exception("DoH 解析失败: 所有 DNS 提供商均无法解析 ${uri.host}");
    }

    // Construct IP-based URL preserving path and query
    final ipUrl = uri.replace(host: realIp).toString();
    print("[RobustFetcher] Attempting IP direct connect: $ipUrl");

    final response = await _dio.get<String>(
      ipUrl,
      options: Options(
        headers: {
          "Host": uri.host, // Crucial for virtual hosts / CDN
          "User-Agent": "ClashX/1.120.0",
        },
      ),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
      print("[RobustFetcher] IP direct connect succeeded via $usedProvider");
      return _decodeSubscription(response.data!);
    }
    throw Exception("IP 直连失败: HTTP ${response.statusCode}");
  }

  /// Resolve domain via DoH
  static Future<String?> _resolveViaDoH(String baseUrl, String domain) async {
    final url = "$baseUrl?name=$domain&type=A";
    final response = await _dio.get<String>(url).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200 && response.data != null) {
      final data = jsonDecode(response.data!) as Map<String, dynamic>;
      final answers = data["Answer"] as List<dynamic>?;
      if (answers != null && answers.isNotEmpty) {
        for (final answer in answers) {
          if (answer["type"] == 1) {
            return answer["data"] as String?;
          }
        }
      }
    }
    return null;
  }

  /// Decode subscription content (handle Base64 and plain text)
  static String _decodeSubscription(String content) {
    // Try Base64 decode first (common for subscriptions)
    try {
      final decoded = utf8.decode(base64Decode(content.trim()));
      if (decoded.contains("proxies:") || decoded.contains("Proxy Group:")) {
        print("[RobustFetcher] Base64 decoded successfully");
        return decoded;
      }
    } catch (_) {
      // Not Base64, return as-is
    }

    // Return original content (should be YAML)
    return content;
  }
}
