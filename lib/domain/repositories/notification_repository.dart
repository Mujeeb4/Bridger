import '../entities/app_notification.dart';

/// Repository interface for notification operations
abstract class NotificationRepository {
  /// Get all notifications sorted by most recent
  Future<List<AppNotificationEntity>> getAllNotifications();

  /// Get unread notifications
  Future<List<AppNotificationEntity>> getUnreadNotifications();

  /// Get notifications for a specific app
  Future<List<AppNotificationEntity>> getNotificationsForApp(String packageName);

  /// Save a new notification
  Future<AppNotificationEntity> saveNotification(AppNotificationEntity notification);

  /// Mark a notification as read
  Future<void> markNotificationAsRead(int id);

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead();

  /// Delete a specific notification
  Future<void> deleteNotification(int id);

  /// Clear all notifications
  Future<void> clearAllNotifications();

  /// Get unread notification count
  Future<int> getUnreadCount();
}
