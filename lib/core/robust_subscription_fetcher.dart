import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Robust subscription fetcher: Direct -> System Proxy -> Hardcoded Proxy -> DoH
class RobustSubscriptionFetcher {
  static Future<String> fetch(String url) async {
    // Normalize URL
    url = url.trim();
    if (url.isEmpty) throw Exception('URL 为空');
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://' + url;
    }
    final uri = Uri.parse(url);
    String? lastError;

    final headers = {'User-Agent': 'ClashX/1.0.0', 'Accept': '*/*'};

    // 1. Direct
    try {
      print('Attempting direct...');
      final res = await http.get(uri, headers: headers).timeout(Duration(seconds: 10));
      if (res.statusCode == 200) return res.body;
    } catch (e) { lastError = 'Direct: $e'; }

    // 2. System Proxy (Env Vars) - Checks http_proxy env var set by ClashX
    try {
      print('Attempting System Proxy (Env)...');
      final client = _createEnvProxyClient();
      if (client != null) {
        final res = await client.get(uri, headers: headers).timeout(Duration(seconds: 10));
        if (res.statusCode == 200) return res.body;
      }
    } catch (e) { lastError = 'System Proxy: $e'; }

    // 3. Hardcoded Proxy (ClashX 7890) - IOClient is more robust than raw HttpClient
    try {
      print('Attempting Local Proxy (7890)...');
      if (await _isPortOpen('127.0.0.1', 7890)) {
        final client = _createHardcodedProxyClient('127.0.0.1', 7890);
        final res = await client.get(uri, headers: headers).timeout(Duration(seconds: 15));
        if (res.statusCode == 200) return res.body;
      }
    } catch (e) { lastError = 'Local Proxy: $e'; }

    // 4. DoH (AliDNS)
    try {
      print('Attempting DoH (AliDNS)...');
      final ip = await _resolveDnsOverHttps('https://223.5.5.5/resolve', uri.host);
      if (ip != null) {
        final ipUri = uri.replace(host: ip);
        final client = http.Client();
        final res = await client.get(ipUri, headers: {...headers, 'Host': uri.host}).timeout(Duration(seconds: 10));
        if (res.statusCode == 200) return res.body;
      }
    } catch (e) { lastError = 'DoH(AliDNS): $e'; }

    // 5. DoH (Cloudflare)
    try {
      print('Attempting DoH (Cloudflare)...');
      final ip = await _resolveDnsOverHttps('https://1.1.1.1/dns-query', uri.host);
      if (ip != null) {
        final ipUri = uri.replace(host: ip);
        final client = http.Client();
        final res = await client.get(ipUri, headers: {...headers, 'Host': uri.host}).timeout(Duration(seconds: 10));
        if (res.statusCode == 200) return res.body;
      }
    } catch (e) { lastError = 'DoH(CF): $e'; }

    throw Exception('导入失败: $lastError');
  }

  static http.Client? _createEnvProxyClient() {
    final proxyEnv = Platform.environment['http_proxy'] ?? Platform.environment['HTTP_PROXY'];
    if (proxyEnv == null) return null;
    try {
      final uri = Uri.parse(proxyEnv);
      final ioClient = HttpClient();
      ioClient.findProxy = (url) => 'PROXY ${uri.host}:${uri.port}';
      ioClient.badCertificateCallback = (cert, host, port) => true;
      return IOClient(ioClient);
    } catch (e) { return null; }
  }

  static http.Client _createHardcodedProxyClient(String host, int port) {
    final ioClient = HttpClient();
    ioClient.findProxy = (url) => 'PROXY $host:$port';
    ioClient.badCertificateCallback = (cert, host, port) => true;
    return IOClient(ioClient);
  }

  static Future<bool> _isPortOpen(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port, timeout: Duration(seconds: 1));
      socket.destroy();
      return true;
    } catch (_) { return false; }
  }

  static Future<String?> _resolveDnsOverHttps(String baseUrl, String domain) async {
    final url = '$baseUrl?name=$domain&type=A';
    final client = http.Client();
    try {
      final res = await client.get(Uri.parse(url), headers: {'accept': 'application/dns-json'}).timeout(Duration(seconds: 5));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map;
        final answers = json['Answer'] as List?;
        if (answers != null && answers.isNotEmpty) {
          return answers[0]['data'] as String;
        }
      }
    } catch (e) { print('DoH error: $e'); } finally { client.close(); }
    return null;
  }
}
