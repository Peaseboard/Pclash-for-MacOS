/// Proxy node model
class Proxy {
  final String name;
  final String type;
  final String? now; // For groups: currently selected child
  final List<String>? all; // For groups: all child proxies
  final List<String>? history;
  final bool? alive;
  final int? delay;

  const Proxy({
    required this.name,
    required this.type,
    this.now,
    this.all,
    this.history,
    this.alive,
    this.delay,
  });

  factory Proxy.fromJson(Map<String, dynamic> json) {
    return Proxy(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'Unknown',
      now: json['now'] as String?,
      all: (json['all'] as List<dynamic>?)?.cast<String>(),
      history: (json['history'] as List<dynamic>?)?.cast<String>(),
      alive: json['alive'] as bool?,
      delay: json['delay'] as int?,
    );
  }

  bool get isGroup => type == 'Selector' || type == 'URLTest' || type == 'Fallback' || type == 'LoadBalance';

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'now': now,
      'all': all,
      'history': history,
      'alive': alive,
      'delay': delay,
    };
  }

  @override
  String toString() => 'Proxy($name, $type, delay: $delay)';
}
