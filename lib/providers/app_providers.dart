import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/mihomo_manager.dart';
import '../core/mihomo_api.dart';
import '../core/subscription_manager.dart';
import '../core/platform/vpn_channel.dart';
import '../core/platform/system_proxy_channel.dart';
import '../models/proxy.dart';
import '../models/traffic_stats.dart';
import '../models/subscription.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

// --- Config Providers ---

final apiPortProvider = StateProvider<int>((ref) => AppConstants.defaultApiPort);
final mixedPortProvider = StateProvider<int>((ref) => AppConstants.defaultMixedPort);
final apiSecretProvider = StateProvider<String>((ref) => AppConstants.defaultApiSecret);

// --- Connection State ---

final isConnectedProvider = StateNotifierProvider<ConnectionNotifier, bool>((ref) {
  return ConnectionNotifier(ref);
});

class ConnectionNotifier extends StateNotifier<bool> {
  final Ref _ref;
  MihomoManager? _manager;
  StreamSubscription<TrafficStats>? _trafficSubscription;

  ConnectionNotifier(this._ref) : super(false);

  bool get _isTunMode => Platform.isAndroid;

  Future<void> connect() async {
    if (state) return;

    try {
      AppLogger.info('Starting connection...');

      final apiPort = _ref.read(apiPortProvider);
      final mixedPort = _ref.read(mixedPortProvider);
      final secret = _ref.read(apiSecretProvider);

      _manager = MihomoManager(
        apiPort: apiPort,
        mixedPort: mixedPort,
        secret: secret,
      );

      // Get active config path
      final subManager = SubscriptionManager();
      final configPath = await subManager.activeConfigPath;
      final configFile = File(configPath);
      
      String? configContent;
      if (configFile.existsSync()) {
        configContent = await configFile.readAsString();
        AppLogger.info('Loaded config from: $configPath');
      } else {
        AppLogger.warning('No active config found, using default');
      }

      final started = await _manager!.start(subscriptionContent: configContent);
      if (!started) throw Exception('Mihomo failed to start');

      AppLogger.info('Mihomo started successfully');

      if (_isTunMode) {
        await _startVpn(mixedPort, apiPort, secret);
      } else if (SystemProxyChannel.isSupported) {
        AppLogger.info('Setting system proxy on ${SystemProxyChannel.platformName}...');
        await SystemProxyChannel.setSystemProxy(enabled: true, port: mixedPort);
      }

      _setupTrafficStream();
      await _loadProxies();

      state = true;
      AppLogger.info('Connection established');

    } catch (e, st) {
      AppLogger.error('Connection failed', 'CONNECT', e as Exception?);
      await _manager?.stop();
      _manager = null;
      state = false;
      rethrow;
    }
  }

  Future<void> _startVpn(int mixedPort, int apiPort, String secret) async {
    try {
      final workDir = _manager?.workDir;
      await VpnChannel.startVpn(
        mihomoPort: mixedPort,
        apiPort: apiPort,
        secret: secret,
        configPath: workDir != null ? '$workDir/config.yaml' : null,
      );
    } catch (e) {
      AppLogger.error('Failed to start VPN', 'VPN', e as Exception?);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (!state) return;

    try {
      AppLogger.info('Disconnecting...');

      if (_isTunMode) {
        try { await VpnChannel.stopVpn(); } catch (e) { AppLogger.error('Failed to stop VPN', 'DISCONNECT', e as Exception?); }
      } else if (SystemProxyChannel.isSupported) {
        try { await SystemProxyChannel.disableProxy(); } catch (e) { AppLogger.error('Failed to disable system proxy', 'DISCONNECT', e as Exception?); }
      }

      await _trafficSubscription?.cancel();
      _trafficSubscription = null;
      await _manager?.stop();
      _manager = null;

      _ref.read(proxiesProvider.notifier).state = {};
      _ref.read(proxyGroupsProvider.notifier).state = [];
      _ref.read(trafficProvider.notifier).state = const TrafficStats(up: 0, down: 0);

      state = false;
      AppLogger.info('Disconnected');
    } catch (e) {
      AppLogger.error('Disconnect failed', 'DISCONNECT', e as Exception?);
      state = false;
    }
  }

  void _setupTrafficStream() {
    if (_manager?.api == null) return;
    _trafficSubscription = _manager!.api!.trafficStream().listen(
      (traffic) => _ref.read(trafficProvider.notifier).state = traffic,
      onError: (e) => AppLogger.error('Traffic stream error', 'TRAFFIC', e as Exception?),
      cancelOnError: false,
    );
  }

  Future<void> _loadProxies() async {
    if (_manager?.api == null) return;
    try {
      final proxies = await _manager!.api!.getProxies();
      final groups = <Proxy>[];
      final allProxies = <String, Proxy>{};

      for (final entry in proxies.entries) {
        final proxy = entry.value;
        allProxies[entry.key] = proxy;
        if (proxy.isGroup) groups.add(proxy);
      }

      _ref.read(proxiesProvider.notifier).state = allProxies;
      _ref.read(proxyGroupsProvider.notifier).state = groups;
      AppLogger.info('Loaded ${allProxies.length} proxies, ${groups.length} groups');
    } catch (e) {
      AppLogger.error('Failed to load proxies', 'PROXIES', e as Exception?);
    }
  }

  Future<void> testGroupDelay(String groupName) async {
    if (_manager?.api == null) return;
    try {
      await _manager!.api!.testGroupDelay(groupName);
      await _loadProxies();
    } catch (e) {
      AppLogger.error('Group delay test failed', 'DELAY', e as Exception?);
    }
  }

  Future<void> selectProxy(String groupName, String proxyName) async {
    if (_manager?.api == null) return;
    try {
      await _manager!.api!.selectProxy(groupName, proxyName);
      _ref.read(selectedProxyProvider.notifier).state = {
        ..._ref.read(selectedProxyProvider),
        groupName: proxyName,
      };
    } catch (e) {
      AppLogger.error('Failed to select proxy', 'PROXY', e as Exception?);
    }
  }

  Future<void> changeMode(String mode) async {
    if (_manager?.api == null) return;
    try {
      await _manager!.api!.setMode(mode);
      _ref.read(proxyModeProvider.notifier).state = mode;
    } catch (e) {
      AppLogger.error('Failed to change mode', 'MODE', e as Exception?);
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

// --- Traffic Provider ---
final trafficProvider = StateNotifierProvider<TrafficNotifier, TrafficStats>((ref) => TrafficNotifier());
class TrafficNotifier extends StateNotifier<TrafficStats> {
  TrafficNotifier() : super(const TrafficStats(up: 0, down: 0));
}

// --- Proxies Provider ---
final proxiesProvider = StateNotifierProvider<ProxiesNotifier, Map<String, Proxy>>((ref) => ProxiesNotifier());
class ProxiesNotifier extends StateNotifier<Map<String, Proxy>> {
  ProxiesNotifier() : super({});
}

final proxyGroupsProvider = StateNotifierProvider<ProxyGroupsNotifier, List<Proxy>>((ref) => ProxyGroupsNotifier());
class ProxyGroupsNotifier extends StateNotifier<List<Proxy>> {
  ProxyGroupsNotifier() : super([]);
}

final selectedProxyProvider = StateProvider<Map<String, String>>((ref) => {});

// --- Mode Provider ---
final proxyModeProvider = StateNotifierProvider<ModeNotifier, String>((ref) => ModeNotifier());
class ModeNotifier extends StateNotifier<String> {
  ModeNotifier() : super('rule');
  void changeMode(String mode) => state = mode;
}

// --- Subscriptions Provider ---
final subscriptionsProvider = StateNotifierProvider<SubscriptionNotifier, AsyncValue<List<Subscription>>>((ref) {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends StateNotifier<AsyncValue<List<Subscription>>> {
  final SubscriptionManager _manager = SubscriptionManager();
  SubscriptionNotifier() : super(const AsyncValue.data([])) {
    _load();
  }

  Future<void> _load() async {
    try {
      final subs = await _manager.loadSubscriptions();
      state = AsyncValue.data(subs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(String url, {String? name}) async {
    state = const AsyncValue.loading();
    try {
      await _manager.addSubscription(url, name: name);
      await _load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> remove(String filePath) async {
    state = const AsyncValue.loading();
    try {
      await _manager.deleteSubscription(filePath);
      await _load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// --- Persistent Settings ---
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());
class AppSettings {
  final bool systemProxy;
  final bool autoStart;
  final String themeMode;
  const AppSettings({this.autoStart = false, this.themeMode = 'system', this.systemProxy = false});
  AppSettings copyWith({bool? autoStart, String? themeMode, bool? systemProxy}) => AppSettings(autoStart: autoStart ?? this.autoStart, themeMode: themeMode ?? this.themeMode, systemProxy: systemProxy ?? this.systemProxy);
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) { _load(); }
  Future<void> _load() async {}
  Future<void> setAutoStart(bool value) async {
    if (SystemProxyChannel.isSupported) await SystemProxyChannel.setAutoStart(value);
    state = state.copyWith(autoStart: value);
  }
  Future<void> setThemeMode(String value) async => state = state.copyWith(themeMode: value);
  Future<void> setSystemProxy(bool value) async => state = state.copyWith(systemProxy: value);
}
