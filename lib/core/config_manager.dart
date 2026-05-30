import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Mihomo configuration generator
class ConfigManager {
  ConfigManager._();

  /// Generate complete mihomo config.yaml
  static Future<void> generateConfig({
    required String workDir,
    required int apiPort,
    required int mixedPort,
    required String secret,
    String? subscriptionContent,
  }) async {
    final configPath = p.join(workDir, 'config.yaml');
    
    Map<String, dynamic> config;
    
    if (subscriptionContent != null && subscriptionContent.isNotEmpty) {
      // Parse subscription content and merge
      config = _parseSubscription(subscriptionContent);
      // Override API and port settings
      config['external-controller'] = '127.0.0.1:$apiPort';
      config['secret'] = secret;
      config['mixed-port'] = mixedPort;
      config['allow-lan'] = false;
      config['log-level'] = 'info';
      config['mode'] = config['mode'] ?? 'rule';
    } else {
      // Generate default config
      config = _defaultConfig(
        apiPort: apiPort,
        mixedPort: mixedPort,
        secret: secret,
      );
    }

    final yamlContent = _encodeYaml(config);
    await File(configPath).writeAsString(yamlContent);
  }

  /// Default configuration with no proxies
  static Map<String, dynamic> _defaultConfig({
    required int apiPort,
    required int mixedPort,
    required String secret,
  }) {
    return {
      'mixed-port': mixedPort,
      'allow-lan': false,
      'log-level': 'info',
      'mode': 'rule',
      'external-controller': '127.0.0.1:$apiPort',
      'secret': secret,
      'dns': {
        'enable': true,
        'listen': '0.0.0.0:5353',
        'enhanced-mode': 'fake-ip',
        'fake-ip-range': '198.18.0.1/16',
        'fake-ip-filter': [
          '*.lan',
          '*.local',
          'localhost.ptlogin2.qq.com',
        ],
        'nameserver': [
          'https://223.5.5.5/dns-query',
          'https://dns.alidns.com/dns-query',
        ],
        'fallback': [
          'https://8.8.8.8/dns-query',
          'https://1.1.1.1/dns-query',
        ],
        'fallback-filter': {
          'geoip': true,
          'ipcidr': ['240.0.0.0/4'],
        },
      },
      'proxies': [],
      'proxy-groups': [
        {
          'name': '🚀 节点选择',
          'type': 'select',
          'proxies': ['DIRECT'],
        },
        {
          'name': '🐟 漏网之鱼',
          'type': 'select',
          'proxies': ['🚀 节点选择', 'DIRECT'],
        },
      ],
      'rules': [
        'GEOSITE,cn,DIRECT',
        'GEOIP,cn,DIRECT',
        'MATCH,🐟 漏网之鱼',
      ],
    };
  }

  /// Parse Clash/Mihomo subscription format
  static Map<String, dynamic> _parseSubscription(String content) {
    try {
      // Try to decode as base64 first (some subscriptions are base64 encoded)
      String decoded;
      try {
        decoded = utf8.decode(base64.decode(content.trim()));
        // If it decodes to valid YAML, use it
        loadYaml(decoded);
        content = decoded;
      } catch (_) {
        // Not base64, use as-is
      }

      final yaml = loadYaml(content);
      return _yamlToMap(yaml as YamlMap);
    } catch (e) {
      throw Exception('Failed to parse subscription: $e');
    }
  }

  /// Convert YamlMap to regular Map
  static Map<String, dynamic> _yamlToMap(YamlMap yaml) {
    final map = <String, dynamic>{};
    for (final entry in yaml.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is YamlMap) {
        map[key] = _yamlToMap(value);
      } else if (value is YamlList) {
        map[key] = value.map((e) {
          if (e is YamlMap) return _yamlToMap(e);
          if (e is YamlList) return _yamlListToList(e);
          return e;
        }).toList();
      } else if (value is YamlList) {
        map[key] = _yamlListToList(value);
      } else {
        map[key] = value;
      }
    }
    return map;
  }

  static List<dynamic> _yamlListToList(YamlList list) {
    return list.map((e) {
      if (e is YamlMap) return _yamlToMap(e);
      if (e is YamlList) return _yamlListToList(e);
      return e;
    }).toList();
  }

  /// Simple YAML encoder for basic config
  static String _encodeYaml(Map<String, dynamic> map, {int indent = 0}) {
    final buffer = StringBuffer();
    _encodeYamlValue(map, buffer, indent);
    return buffer.toString();
  }

  static void _encodeYamlValue(dynamic value, StringBuffer buffer, int indent) {
    final prefix = '  ' * indent;

    if (value is Map) {
      if ((value as Map).isEmpty) {
        buffer.writeln('{}');
        return;
      }
      var first = true;
      for (final entry in value.entries) {
        if (!first) buffer.writeln();
        first = false;
        if (entry.value is List || entry.value is Map) {
          buffer.write('$prefix${entry.key}:');
          buffer.writeln();
          _encodeYamlValue(entry.value, buffer, indent + 1);
        } else {
          buffer.write('$prefix${entry.key}: ${_formatValue(entry.value)}');
        }
      }
    } else if (value is List) {
      if (value.isEmpty) {
        buffer.writeln('[]');
        return;
      }
      for (final item in value) {
        if (item is Map) {
          var first = true;
          for (final entry in item.entries) {
            if (first) {
              buffer.write('$prefix- ${entry.key}: ${_formatValue(entry.value)}');
              buffer.writeln();
              first = false;
            } else {
              buffer.write('${'  ' * (indent + 1)}${entry.key}: ${_formatValue(entry.value)}');
              buffer.writeln();
            }
          }
        } else {
          buffer.writeln('$prefix- $_formatValue(item)');
        }
      }
    }
  }

  static String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return value.toString();
    if (value is String) {
      // Quote strings that contain special characters
      if (value.contains(':') || value.contains('#') || value.contains(',') ||
          value.contains('[') || value.contains(']') || value.contains('{') ||
          value.contains('}') || value.contains('"') || value.contains("'") ||
          value.contains(' ') || value.isEmpty) {
        return "'${value.replaceAll("'", "''")}'";
      }
      return value;
    }
    return value.toString();
  }
}
