import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../providers/app_providers.dart';
import '../core/subscription_manager.dart';
import '../models/subscription.dart';
import '../utils/logger.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  final _urlController = TextEditingController();
  final SubscriptionManager _manager = SubscriptionManager();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionsAsync = ref.watch(subscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('配置管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadConfigs,
            tooltip: '刷新',
          ),
        ],
      ),
      body: subscriptionsAsync.when(
        data: (subscriptions) {
          if (subscriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text('暂无配置', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('点击下方按钮导入订阅', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final sub = subscriptions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.file_copy_outlined),
                  title: Text(sub.name),
                  subtitle: Text(
                    '更新: ${_formatDate(sub.lastUpdated)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: '应用此配置',
                        onPressed: () => _applyConfig(sub),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteConfig(sub),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'url',
            onPressed: _showImportDialog,
            child: const Icon(Icons.link),
            tooltip: '导入远程订阅',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'file',
            onPressed: _importLocalFile,
            child: const Icon(Icons.folder),
            tooltip: '导入本地文件',
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    _urlController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入远程订阅'),
        content: TextField(
          controller: _urlController,
          decoration: const InputDecoration(hintText: 'https://...', border: OutlineInputBorder()),
          keyboardType: TextInputType.url,
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _importRemote(_urlController.text.trim());
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<void> _importRemote(String url) async {
    if (url.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      await _manager.addSubscription(url);
      await _reloadConfigs();
      
      // Apply immediately
      final subs = await _manager.loadSubscriptions();
      if (subs.isNotEmpty) {
        await _applyConfig(subs.last);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 导入并应用成功'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(' 导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importLocalFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml', 'conf'],
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        setState(() => _isLoading = true);
        try {
          final content = await File(path).readAsString();
          final sub = Subscription(name: path.split('/').last, url: '', lastUpdated: DateTime.now(), filePath: path);
          // For local files, we copy to active config directly
          await _manager.addSubscription('file://$path'); // Hack: reuse logic
          await _reloadConfigs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 本地文件导入成功'), backgroundColor: Colors.green));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 导入失败: $e'), backgroundColor: Colors.red));
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _applyConfig(Subscription sub) async {
    setState(() => _isLoading = true);
    try {
      await _manager.switchToSubscription(sub.filePath!);
      // Restart Mihomo with new config
      await ref.read(isConnectedProvider.notifier).disconnect();
      await ref.read(isConnectedProvider.notifier).connect();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ 已切换到: ${sub.name}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 切换失败: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteConfig(Subscription sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除配置'),
        content: Text('确定要删除 "${sub.name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _manager.deleteSubscription(sub.filePath!);
        await _reloadConfigs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 已删除')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 删除失败: $e')));
        }
      }
    }
  }

  Future<void> _reloadConfigs() async {
    try {
      final subs = await _manager.loadSubscriptions();
      ref.read(subscriptionsProvider.notifier).state = AsyncValue.data(subs);
    } catch (e, st) {
      ref.read(subscriptionsProvider.notifier).state = AsyncValue.error(e, st);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
