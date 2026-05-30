import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../models/subscription.dart';
import '../core/subscription_manager.dart' as subscription_manager;

/// Subscription management screen
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  bool _showAddForm = false;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionsAsync = ref.watch(subscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅管理'),
        actions: [
          IconButton(
            icon: Icon(_showAddForm ? Icons.close : Icons.add),
            tooltip: _showAddForm ? '取消' : '添加订阅',
            onPressed: () {
              setState(() => _showAddForm = !_showAddForm);
              if (!_showAddForm) {
                _urlController.clear();
                _nameController.clear();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showAddForm) _AddSubscriptionForm(
            urlController: _urlController,
            nameController: _nameController,
            onAdd: () => _addSubscription(),
          ),
          Expanded(
            child: subscriptionsAsync.when(
              data: (subscriptions) {
                if (subscriptions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无订阅',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击上方 + 添加订阅 URL',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: subscriptions.length,
                  itemBuilder: (context, index) {
                    final sub = subscriptions[index];
                    return _SubscriptionCard(
                      subscription: sub,
                      onUpdate: () => _updateSubscription(sub),
                      onDelete: () => _deleteSubscription(sub),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('加载失败: $e'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSubscription() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入订阅 URL')),
      );
      return;
    }

    final name = _nameController.text.trim().isEmpty ? null : _nameController.text.trim();
    final notifier = ref.read(subscriptionsProvider.notifier);
    
    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在获取订阅配置...')),
      );
    }

    try {
      await notifier.add(url, name: name);
      
      // Immediately fetch content to validate
      final subs = ref.read(subscriptionsProvider).when(
        data: (s) => s,
        loading: () => [],
        error: (_, __) => [],
      );
      final targetSub = subs.firstWhere((s) => s.url == url);
      
      final subManager = subscription_manager.SubscriptionManager();
      final content = await subManager.fetchSubscription(targetSub);
      
      if (content == null || content.isEmpty) {
        throw Exception('订阅内容为空');
      }

      setState(() {
        _showAddForm = false;
        _urlController.clear();
        _nameController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 订阅添加并验证成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 添加失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateSubscription(Subscription sub) async {
    final notifier = ref.read(subscriptionsProvider.notifier);
    final content = await subscription_manager.SubscriptionManager().fetchSubscription(sub);

    if (content != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${sub.name} 更新成功')),
      );
      // TODO: Reload config with new subscription content
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新失败')),
      );
    }
  }

  Future<void> _deleteSubscription(Subscription sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除订阅'),
        content: Text('确定要删除 "${sub.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(subscriptionsProvider.notifier).remove(sub.url);
    }
  }
}

class _AddSubscriptionForm extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController nameController;
  final VoidCallback onAdd;

  const _AddSubscriptionForm({
    required this.urlController,
    required this.nameController,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '添加订阅',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称（可选）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '订阅 URL',
                hintText: 'https://example.com/api/v1/client/subscribe?token=xxx',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const _SubscriptionCard({
    required this.subscription,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: subscription.isExpired
              ? Colors.red.shade100
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            subscription.isExpired ? Icons.warning : Icons.cloud_done,
            color: subscription.isExpired
                ? Colors.red
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(subscription.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subscription.progressText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (subscription.expire != null)
              Text(
                '到期: ${subscription.expire!.year}-${subscription.expire!.month.toString().padLeft(2, '0')}-${subscription.expire!.day.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onUpdate,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
