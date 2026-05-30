/// Subscription model
class Subscription {
  final String name;
  final String url;
  final String? filePath; // Local YAML file path
  final DateTime lastUpdated;

  const Subscription({
    required this.name,
    required this.url,
    this.filePath,
    required this.lastUpdated,
  });

  factory Subscription.fromFile(String filePath) {
    final fileName = filePath.split('/').last;
    return Subscription(
      name: fileName.replaceAll('.yaml', ''),
      url: '',
      filePath: filePath,
      lastUpdated: DateTime.now(),
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      name: json['name'] as String? ?? 'Unknown',
      url: json['url'] as String? ?? '',
      filePath: json['filePath'] as String?,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'filePath': filePath,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
