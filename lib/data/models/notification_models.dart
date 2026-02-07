/// Notification model
class BridgerNotification {
  final String id;
  final String packageName;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? appName;

  BridgerNotification({
    required this.id,
    required this.packageName,
    required this.title,
    required this.body,
    required this.timestamp,
    this.appName,
  });

  factory BridgerNotification.fromMap(Map<String, dynamic> map) {
    return BridgerNotification(
      id: (map['id'] as int?)?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      packageName: map['packageName'] as String? ?? 'unknown',
      title: map['title'] as String? ?? 'No Title',
      body: map['text'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      appName: map['appName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'title': title,
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'appName': appName,
    };
  }

  factory BridgerNotification.fromJson(Map<String, dynamic> json) {
    return BridgerNotification(
      id: json['id'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      appName: json['appName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toMap();
}

/// Notification event types
enum NotificationEventType {
  posted,
  removed,
}
