import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../utils/constants.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final apiPort = ref.watch(apiPortProvider);
    final mixedPort = ref.watch(mixedPortProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // App info
          _SectionHeader(title: '关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            subtitle: Text(AppConstants.appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('内核'),
            subtitle: const Text('Mihomo (Clash.Meta)'),
          ),
          const Divider(),

          // Proxy settings
          _SectionHeader(title: '代理设置'),
          ListTile(
            leading: const Icon(Icons.settings_ethernet),
            title: const Text('代理端口'),
            subtitle: Text('Mixed: $mixedPort'),
          ),
          ListTile(
            leading: const Icon(Icons.api),
            title: const Text('API 端口'),
            subtitle: Text('Controller: $apiPort'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.computer),
            title: const Text('系统代理'),
            subtitle: const Text('自动设置系统代理'),
            value: settings.systemProxy,
            onChanged: (v) {
              ref.read(settingsProvider.notifier).setSystemProxy(v);
            },
          ),
          const Divider(),

          // App behavior
          _SectionHeader(title: '应用行为'),
          SwitchListTile(
            secondary: const Icon(Icons.flash_on),
            title: const Text('开机自启'),
            subtitle: const Text('系统启动后自动连接'),
            value: settings.autoStart,
            onChanged: (v) {
              ref.read(settingsProvider.notifier).setAutoStart(v);
            },
          ),
          const Divider(),

          // Appearance
          _SectionHeader(title: '外观'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题'),
            subtitle: Text(_themeLabel(settings.themeMode)),
            trailing: DropdownButton<String>(
              value: settings.themeMode,
              items: const [
                DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                DropdownMenuItem(value: 'light', child: Text('浅色')),
                DropdownMenuItem(value: 'dark', child: Text('深色')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(v);
                }
              },
            ),
          ),
          const Divider(),

          // Platform specific info
          _SectionHeader(title: '平台信息'),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('当前平台'),
            subtitle: Text(_platformName()),
          ),
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('VPN 模式'),
              subtitle: const Text('VpnService + TUN'),
            ),
          if (Platform.isMacOS)
            ListTile(
              leading: const Icon(Icons.network_wifi),
              title: const Text('代理模式'),
              subtitle: const Text('系统 HTTP/SOCKS 代理'),
            ),
          const Divider(),

          // Actions
          _SectionHeader(title: '操作'),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('查看日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to log viewer
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('打开配置目录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Open config directory
            },
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('清除缓存'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _clearCache(context);
            },
          ),
          const SizedBox(height: 32),

          // Footer
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.shield, size: 32, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'PClash ${AppConstants.appVersion}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Modern Proxy Client',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(String mode) {
    switch (mode) {
      case 'light':
        return '浅色';
      case 'dark':
        return '深色';
      default:
        return '跟随系统';
    }
  }

  String _platformName() {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  void _clearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存吗？这将清除 DNS 缓存、FakeIP 映射和连接信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Clear cache via API
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
