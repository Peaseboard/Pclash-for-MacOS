/// Subscription model
class Subscription {
  final String name;
  final String url;
  final String? filePath;
  final DateTime lastUpdated;
  final DateTime? expire;
  final int? total;
  final int? used;

  const Subscription({
    required this.name,
    required this.url,
    this.filePath,
    required this.lastUpdated,
    this.expire,
    this.total,
    this.used,
  });

  bool get isExpired {
    if (expire == null) return false;
    return expire!.isBefore(DateTime.now());
  }

  String get progressText {
    if (total == null || used == null) return "未知流量";
    final usedGB = (used! / 1024 / 1024 / 1024).toStringAsFixed(2);
    final totalGB = (total! / 1024 / 1024 / 1024).toStringAsFixed(2);
    final pct = ((used! / total!) * 100).toStringAsFixed(1);
    return "$usedGB GB / $totalGB GB ($pct%)";
  }

  factory Subscription.fromFile(String filePath) {
    final fileName = filePath.split("/").last;
    return Subscription(
      name: fileName.replaceAll(".yaml", ""),
      url: "",
      filePath: filePath,
      lastUpdated: DateTime.now(),
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      name: json["name"] as String? ?? "Unknown",
      url: json["url"] as String? ?? "",
      filePath: json["filePath"] as String?,
      lastUpdated: DateTime.parse(json["lastUpdated"] as String? ?? DateTime.now().toIso8601String()),
      expire: json["expire"] != null ? DateTime.fromMillisecondsSinceEpoch((json["expire"] as int) * 1000) : null,
      total: json["total"] as int?,
      used: json["used"] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "url": url,
      "filePath": filePath,
      "lastUpdated": lastUpdated.toIso8601String(),
      "expire": expire != null ? expire!.millisecondsSinceEpoch ~/ 1000 : null,
      "total": total,
      "used": used,
    };
  }
}
