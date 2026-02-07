import 'package:drift/drift.dart';

import '../../datasources/local/database.dart';
import '../../../domain/entities/app_notification.dart';
import '../../../domain/repositories/notification_repository.dart';

/// Implementation of NotificationRepository using Drift database
class NotificationRepositoryImpl implements NotificationRepository {
  final AppDatabase _database;

  NotificationRepositoryImpl(this._database);

  @override
  Future<List<AppNotificationEntity>> getAllNotifications() async {
    final notifications = await _database.getAllNotifications();
    return notifications.map(_mapToEntity).toList();
  }

  @override
  Future<List<AppNotificationEntity>> getUnreadNotifications() async {
    final notifications = await _database.getUnreadNotifications();
    return notifications.map(_mapToEntity).toList();
  }

  @override
  Future<List<AppNotificationEntity>> getNotificationsForApp(String packageName) async {
    final notifications = await (_database.select(_database.appNotifications)
      ..where((n) => n.packageName.equals(packageName))
      ..orderBy([(n) => OrderingTerm.desc(n.timestamp)])
    ).get();
    return notifications.map(_mapToEntity).toList();
  }

  @override
  Future<AppNotificationEntity> saveNotification(AppNotificationEntity notification) async {
    final id = await _database.insertNotification(
      AppNotificationsCompanion.insert(
        appName: notification.appName,
        packageName: notification.packageName,
        title: Value(notification.title),
        body: Value(notification.body),
        iconBase64: Value(notification.iconBase64),
        isRead: Value(notification.isRead),
        timestamp: notification.timestamp,
      ),
    );
    return notification.copyWith(id: id);
  }

  @override
  Future<void> markNotificationAsRead(int id) async {
    await _database.markNotificationAsRead(id);
  }

  @override
  Future<void> markAllNotificationsAsRead() async {
    await (_database.update(_database.appNotifications))
        .write(const AppNotificationsCompanion(isRead: Value(true)));
  }

  @override
  Future<void> deleteNotification(int id) async {
    await _database.deleteNotification(id);
  }

  @override
  Future<void> clearAllNotifications() async {
    await _database.clearAllNotifications();
  }

  @override
  Future<int> getUnreadCount() async {
    final unread = await _database.getUnreadNotifications();
    return unread.length;
  }

  AppNotificationEntity _mapToEntity(AppNotification notification) {
    return AppNotificationEntity(
      id: notification.id,
      appName: notification.appName,
      packageName: notification.packageName,
      title: notification.title,
      body: notification.body,
      iconBase64: notification.iconBase64,
      isRead: notification.isRead,
      timestamp: notification.timestamp,
    );
  }
}
