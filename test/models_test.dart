import 'package:flutter_test/flutter_test.dart';
import 'package:pclash/models/proxy.dart';
import 'package:pclash/models/traffic_stats.dart';
import 'package:pclash/models/subscription.dart';

void main() {
  group('Proxy Model', () {
    test('should parse proxy from JSON', () {
      final json = {
        'name': 'US Node',
        'type': 'vmess',
        'now': null,
        'all': null,
        'history': [],
        'alive': true,
        'delay': 150,
      };

      final proxy = Proxy.fromJson(json);

      expect(proxy.name, 'US Node');
      expect(proxy.type, 'vmess');
      expect(proxy.alive, true);
      expect(proxy.delay, 150);
      expect(proxy.isGroup, false);
    });

    test('should detect group proxies', () {
      final group = Proxy(
        name: '🚀 节点选择',
        type: 'Selector',
        now: 'US Node',
        all: ['US Node', 'JP Node', 'DIRECT'],
      );

      expect(group.isGroup, true);
      expect(group.now, 'US Node');
      expect(group.all?.length, 3);
    });

    test('should serialize to JSON', () {
      final proxy = const Proxy(
        name: 'Test',
        type: 'ss',
        delay: 100,
      );

      final json = proxy.toJson();

      expect(json['name'], 'Test');
      expect(json['type'], 'ss');
      expect(json['delay'], 100);
    });
  });

  group('TrafficStats Model', () {
    test('should format bytes correctly', () {
      expect(const TrafficStats(up: 1024, down: 0).formattedUp, '1.0 KB/s');
      expect(
          const TrafficStats(up: 1048576, down: 0).formattedUp, '1.0 MB/s');
      expect(
          const TrafficStats(up: 1073741824, down: 0).formattedUp, '1.00 GB/s');
    });

    test('should parse from JSON', () {
      final json = {'up': 512, 'down': 1024};
      final stats = TrafficStats.fromJson(json);

      expect(stats.up, 512);
      expect(stats.down, 1024);
    });
  });

  group('Subscription Model', () {
    test('should create from URL', () {
      const url = 'https://example.com/subscribe?token=abc123';
      final sub = Subscription.fromUrl(url, 'Test Sub');

      expect(sub.name, 'Test Sub');
      expect(sub.url, url);
      expect(sub.lastUpdated, isNotNull);
    });

    test('should extract name from URL when not provided', () {
      const url = 'https://example.com/subscribe?token=abc123';
      final sub = Subscription.fromUrl(url, null);

      expect(sub.name, isNotEmpty);
    });

    test('should calculate progress correctly', () {
      final sub = Subscription(
        name: 'Test',
        url: 'https://example.com',
        totalBytes: 1073741824, // 1GB
        uploadBytes: 107374182, // 100MB
        downloadBytes: 214748364, // 200MB
        lastUpdated: DateTime.now(),
      );

      expect(sub.progressText, contains('300 MB'));
      expect(sub.progressPercent, closeTo(0.3, 0.01));
    });

    test('should detect expired subscriptions', () {
      final sub = Subscription(
        name: 'Expired',
        url: 'https://example.com',
        expire: DateTime.now().subtract(const Duration(days: 1)),
        lastUpdated: DateTime.now(),
      );

      expect(sub.isExpired, true);
    });

    test('should handle unlimited subscriptions', () {
      final sub = Subscription(
        name: 'Unlimited',
        url: 'https://example.com',
        totalBytes: null,
        lastUpdated: DateTime.now(),
      );

      expect(sub.progressText, '无限制');
      expect(sub.progressPercent, 0);
    });

    test('should serialize to JSON and back', () {
      final original = Subscription(
        name: 'Test',
        url: 'https://example.com',
        expire: DateTime(2025, 12, 31),
        totalBytes: 1073741824,
        lastUpdated: DateTime.now(),
      );

      final json = original.toJson();
      final restored = Subscription.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.url, original.url);
      expect(restored.expire, original.expire);
    });
  });
}
