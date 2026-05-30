import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/proxy.dart';
import '../providers/app_providers.dart';

/// Proxy/Node list screen
class ProxyScreen extends ConsumerWidget {
  const ProxyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxies = ref.watch(proxiesProvider);
    final groups = ref.watch(proxyGroupsProvider);
    final selected = ref.watch(selectedProxyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('节点管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: '全部测速',
            onPressed: () {
              // TODO: Trigger group delay test
            },
          ),
        ],
      ),
      body: proxies.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined, size: 64),
                  SizedBox(height: 16),
                  Text('暂无节点'),
                  SizedBox(height: 8),
                  Text(
                    '请先添加订阅',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.isEmpty ? proxies.length : groups.length + 1,
              itemBuilder: (context, index) {
                // Show groups first
                if (groups.isNotEmpty) {
                  if (index < groups.length) {
                    final group = groups[index];
                    return _ProxyGroupCard(
                      group: group,
                      selected: selected,
                    );
                  } else {
                    // "DIRECT" at the end
                    return _ProxyGroupCard(
                      group: const Proxy(
                        name: '🌐 全球直连',
                        type: 'Selector',
                        all: ['DIRECT'],
                        now: 'DIRECT',
                      ),
                      selected: selected,
                    );
                  }
                }

                // Fallback: flat list
                final entry = proxies.entries.toList()[index];
                final proxy = entry.value;
                return _ProxyTile(proxy: proxy);
              },
            ),
    );
  }
}

class _ProxyGroupCard extends ConsumerWidget {
  final Proxy group;
  final Map<String, String> selected;

  const _ProxyGroupCard({
    required this.group,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = group.all ?? [];
    final currentNow = group.now ?? selected[group.name];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.folder_outlined),
        title: Text(group.name),
        subtitle: Text(currentNow ?? '未选择'),
        children: children.map((name) {
          final isNowSelected = name == currentNow;
          return RadioListTile<String>(
            title: Text(name),
            value: name,
            groupValue: currentNow,
            onChanged: (value) {
              if (value != null) {
                ref.read(selectedProxyProvider.notifier).state = {
                  ...selected,
                  group.name: value,
                };
              }
            },
            secondary: isNowSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  )
                : null,
          );
        }).toList(),
      ),
    );
  }
}

class _ProxyTile extends StatelessWidget {
  final Proxy proxy;

  const _ProxyTile({required this.proxy});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _ProtocolIcon(proxy.type),
        title: Text(proxy.name),
        subtitle: Text(proxy.type),
        trailing: proxy.delay != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _delayColor(proxy.delay!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${proxy.delay}ms',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(Icons.timer_outlined, size: 20),
      ),
    );
  }

  Color _delayColor(int delay) {
    if (delay < 200) return Colors.green;
    if (delay < 500) return Colors.orange;
    return Colors.red;
  }
}

class _ProtocolIcon extends StatelessWidget {
  final String type;

  const _ProtocolIcon(this.type);

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color color;

    switch (type.toLowerCase()) {
      case 'ss':
      case 'shadowsocks':
        iconData = Icons.shield;
        color = Colors.blue;
        break;
      case 'vmess':
        iconData = Icons.vpn_key;
        color = Colors.green;
        break;
      case 'vless':
        iconData = Icons.security;
        color = Colors.teal;
        break;
      case 'trojan':
        iconData = Icons.lock;
        color = Colors.purple;
        break;
      case 'hysteria':
      case 'hysteria2':
        iconData = Icons.flash_on;
        color = Colors.orange;
        break;
      case 'tuic':
        iconData = Icons.airplanemode_active;
        color = Colors.indigo;
        break;
      case 'selector':
      case 'urltest':
      case 'fallback':
        iconData = Icons.group_work;
        color = Theme.of(context).colorScheme.primary;
        break;
      default:
        iconData = Icons.public;
        color = Colors.grey;
    }

    return Icon(iconData, color: color);
  }
}
