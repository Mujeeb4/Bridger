import 'package:equatable/equatable.dart';

/// Represents a mirrored app notification entity in the domain layer
class AppNotificationEntity extends Equatable {
  final int id;
  final String appName;
  final String packageName;
  final String? title;
  final String? body;
  final String? iconBase64;
  final bool isRead;
  final DateTime timestamp;

  const AppNotificationEntity({
    required this.id,
    required this.appName,
    required this.packageName,
    this.title,
    this.body,
    this.iconBase64,
    this.isRead = false,
    required this.timestamp,
  });

  /// Get the display title (falls back to app name if no title)
  String get displayTitle => title ?? appName;

  AppNotificationEntity copyWith({
    int? id,
    String? appName,
    String? packageName,
    String? title,
    String? body,
    String? iconBase64,
    bool? isRead,
    DateTime? timestamp,
  }) {
    return AppNotificationEntity(
      id: id ?? this.id,
      appName: appName ?? this.appName,
      packageName: packageName ?? this.packageName,
      title: title ?? this.title,
      body: body ?? this.body,
      iconBase64: iconBase64 ?? this.iconBase64,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
        id,
        appName,
        packageName,
        title,
        body,
        iconBase64,
        isRead,
        timestamp,
      ];
}
