import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/subscription.dart';
import 'robust_subscription_fetcher.dart';

/// Subscription management: fetch, save as YAML, switch, delete
class SubscriptionManager {
  final Dio _dio = Dio();

  // Get directory for storing config files
  Future<String> get _configsDir async {
    final docDir = await getApplicationSupportDirectory();
    final configsDir = Directory(p.join(docDir.path, 'configs'));
    if (!configsDir.existsSync()) {
      configsDir.createSync(recursive: true);
    }
    return configsDir.path;
  }

  // Get path to the currently active config
  Future<String> get activeConfigPath async {
    final docDir = await getApplicationSupportDirectory();
    return p.join(docDir.path, 'config.yaml');
  }

  /// Load all subscriptions from local storage (metadata only)
  Future<List<Subscription>> loadSubscriptions() async {
    final configsDirPath = await _configsDir;
    final dir = Directory(configsDirPath);
    if (!dir.existsSync()) return [];

    final subscriptions = <Subscription>[];
    await for (final file in dir.list()) {
      if (file is File && file.path.endsWith('.yaml')) {
        final content = await file.readAsString();
        final name = _extractNameFromYaml(content) ?? file.path.split('/').last;
        final url = _extractUrlFromYaml(content);
        subscriptions.add(Subscription(
          name: name,
          url: url ?? '',
          lastUpdated: file.lastModifiedSync(),
          filePath: file.path,
        ));
      }
    }
    return subscriptions;
  }

  /// Add a new subscription: Download -> Save as YAML -> Update Active Config
  Future<void> addSubscription(String url, {String? name}) async {
    // 1. Fetch content using robust fetcher
    final content = await RobustSubscriptionFetcher.fetch(url);
    if (content.isEmpty) throw Exception('Empty subscription content');

    // 2. Save as YAML file
    final configsDirPath = await _configsDir;
    final safeName = name ?? url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').substring(0, 20);
    final fileName = '${safeName}_${DateTime.now().millisecondsSinceEpoch}.yaml';
    final file = File(p.join(configsDirPath, fileName));
    await file.writeAsString(content);

    // 3. Copy to active config path (so mihomo can load it)
    final activePath = await activeConfigPath;
    await file.copy(activePath);
  }

  /// Switch to a specific subscription: Copy YAML to active config
  Future<void> switchToSubscription(String filePath) async {
    final activePath = await activeConfigPath;
    final sourceFile = File(filePath);
    if (!sourceFile.existsSync()) throw Exception('Config file not found');
    await sourceFile.copy(activePath);
  }

  /// Delete a subscription file
  Future<void> deleteSubscription(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Update (refresh) a subscription
  Future<void> updateSubscription(String url, String filePath) async {
    final content = await RobustSubscriptionFetcher.fetch(url);
    if (content.isEmpty) throw Exception('Empty subscription content');
    final file = File(filePath);
    await file.writeAsString(content);
    
    // If this was the active config, copy again
    final activePath = await activeConfigPath;
    if (filePath == activePath || await file.lastModified().then((t) => t.isAfter(await File(activePath).lastModified()))) {
      await file.copy(activePath);
    }
  }

  // Helpers to extract info from YAML (simplified)
  String? _extractNameFromYaml(String content) {
    final match = RegExp(r'^name:\s*(.+)', multiLine: true).firstMatch(content);
    return match?.group(1)?.trim();
  }

  String? _extractUrlFromYaml(String content) {
    final match = RegExp(r'^# url:\s*(.+)', multiLine: true).firstMatch(content);
    return match?.group(1)?.trim();
  }
}
