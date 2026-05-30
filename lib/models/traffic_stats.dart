/// Traffic statistics model
class TrafficStats {
  final int up;
  final int down;

  const TrafficStats({
    required this.up,
    required this.down,
  });

  factory TrafficStats.fromJson(Map<String, dynamic> json) {
    return TrafficStats(
      up: (json['up'] as num?)?.toInt() ?? 0,
      down: (json['down'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedUp => _formatBytes(up);
  String get formattedDown => _formatBytes(down);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  Map<String, dynamic> toJson() {
    return {'up': up, 'down': down};
  }
}

/// Connection info model
class ConnectionInfo {
  final String id;
  final String? upload;
  final String? download;
  final DateTime start;
  final Map<String, dynamic>? rule;
  final String? rulePayload;
  final Map<String, dynamic> metadata;

  const ConnectionInfo({
    required this.id,
    this.upload,
    this.download,
    required this.start,
    this.rule,
    this.rulePayload,
    required this.metadata,
  });

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionInfo(
      id: json['id'] as String? ?? '',
      upload: json['upload'] as String?,
      download: json['download'] as String?,
      start: DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime.now(),
      rule: json['rule'] as Map<String, dynamic>?,
      rulePayload: json['rulePayload'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}
