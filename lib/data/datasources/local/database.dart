import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/constants/app_constants.dart';

part 'database.g.dart';

// ============================================================================
// Table Definitions
// ============================================================================

/// SMS Threads (conversations)
class Threads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get phoneNumber => text()();
  TextColumn get contactName => text().nullable()();
  TextColumn get lastMessage => text().nullable()();
  DateTimeColumn get lastTimestamp => dateTime().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// SMS Messages
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get threadId => integer().references(Threads, #id)();
  TextColumn get sender => text()();
  TextColumn get body => text()();
  TextColumn get encryptedBody => text().nullable()();
  BoolColumn get isEncrypted => boolean().withDefault(const Constant(false))();
  BoolColumn get isOutgoing => boolean().withDefault(const Constant(false))();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('sent'))(); // sent, delivered, failed
  DateTimeColumn get timestamp => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Call Logs
class CallLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get phoneNumber => text()();
  TextColumn get contactName => text().nullable()();
  TextColumn get callType => text()(); // incoming, outgoing, missed, rejected
  IntColumn get duration => integer().withDefault(const Constant(0))(); // in seconds
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isNew => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// App Notifications (mirrored from Android)
class AppNotifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get appName => text()();
  TextColumn get packageName => text()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get iconBase64 => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Contacts
class Contacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phoneNumber => text()();
  TextColumn get photoUrl => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastContactedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Settings (key-value store)
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Connection Logs (for debugging/history)
class ConnectionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get eventType => text()(); // connected, disconnected, error, pairing
  TextColumn get deviceId => text().nullable()();
  TextColumn get details => text().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

// ============================================================================
// Database Class
// ============================================================================

@DriftDatabase(tables: [
  Threads,
  Messages,
  CallLogs,
  AppNotifications,
  Contacts,
  Settings,
  ConnectionLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // For testing
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // ============================================================================
  // Thread Operations
  // ============================================================================

  Future<List<Thread>> getAllThreads() => (select(threads)
        ..orderBy([(t) => OrderingTerm.desc(t.lastTimestamp)]))
      .get();

  Future<Thread?> getThreadByPhoneNumber(String phoneNumber) =>
      (select(threads)..where((t) => t.phoneNumber.equals(phoneNumber)))
          .getSingleOrNull();

  Future<int> insertThread(ThreadsCompanion thread) =>
      into(threads).insert(thread);

  Future<bool> updateThread(Thread thread) => update(threads).replace(thread);

  Future<int> deleteThread(int id) =>
      (delete(threads)..where((t) => t.id.equals(id))).go();

  // ============================================================================
  // Message Operations
  // ============================================================================

  Future<List<Message>> getMessagesForThread(int threadId) => (select(messages)
        ..where((m) => m.threadId.equals(threadId))
        ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
      .get();

  Future<int> insertMessage(MessagesCompanion message) =>
      into(messages).insert(message);

  Future<void> markMessageAsRead(int id) =>
      (update(messages)..where((m) => m.id.equals(id)))
          .write(const MessagesCompanion(isRead: Value(true)));

  Future<void> markAllMessagesAsReadInThread(int threadId) =>
      (update(messages)..where((m) => m.threadId.equals(threadId)))
          .write(const MessagesCompanion(isRead: Value(true)));

  Future<int> deleteMessage(int id) =>
      (delete(messages)..where((m) => m.id.equals(id))).go();

  Future<int> deleteMessagesForThread(int threadId) =>
      (delete(messages)..where((m) => m.threadId.equals(threadId))).go();

  // ============================================================================
  // Call Log Operations
  // ============================================================================

  Future<List<CallLog>> getAllCallLogs() => (select(callLogs)
        ..orderBy([(c) => OrderingTerm.desc(c.timestamp)]))
      .get();

  Future<int> insertCallLog(CallLogsCompanion log) =>
      into(callLogs).insert(log);

  Future<void> markCallLogAsRead(int id) =>
      (update(callLogs)..where((c) => c.id.equals(id)))
          .write(const CallLogsCompanion(isNew: Value(false)));

  Future<int> deleteCallLog(int id) =>
      (delete(callLogs)..where((c) => c.id.equals(id))).go();

  Future<int> clearAllCallLogs() => delete(callLogs).go();

  // ============================================================================
  // Notification Operations
  // ============================================================================

  Future<List<AppNotification>> getAllNotifications() =>
      (select(appNotifications)
            ..orderBy([(n) => OrderingTerm.desc(n.timestamp)]))
          .get();

  Future<List<AppNotification>> getUnreadNotifications() =>
      (select(appNotifications)
            ..where((n) => n.isRead.equals(false))
            ..orderBy([(n) => OrderingTerm.desc(n.timestamp)]))
          .get();

  Future<int> insertNotification(AppNotificationsCompanion notification) =>
      into(appNotifications).insert(notification);

  Future<void> markNotificationAsRead(int id) =>
      (update(appNotifications)..where((n) => n.id.equals(id)))
          .write(const AppNotificationsCompanion(isRead: Value(true)));

  Future<int> deleteNotification(int id) =>
      (delete(appNotifications)..where((n) => n.id.equals(id))).go();

  Future<int> clearAllNotifications() => delete(appNotifications).go();

  // ============================================================================
  // Contact Operations
  // ============================================================================

  Future<List<Contact>> getAllContacts() => (select(contacts)
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .get();

  Future<List<Contact>> getFavoriteContacts() => (select(contacts)
        ..where((c) => c.isFavorite.equals(true))
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .get();

  Future<Contact?> getContactByPhoneNumber(String phoneNumber) =>
      (select(contacts)..where((c) => c.phoneNumber.equals(phoneNumber)))
          .getSingleOrNull();

  Future<int> insertContact(ContactsCompanion contact) =>
      into(contacts).insert(contact);

  Future<bool> updateContact(Contact contact) =>
      update(contacts).replace(contact);

  Future<int> deleteContact(int id) =>
      (delete(contacts)..where((c) => c.id.equals(id))).go();

  // ============================================================================
  // Settings Operations
  // ============================================================================

  Future<String?> getSetting(String key) async {
    final result = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return result?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(
        key: key,
        value: value,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteSetting(String key) =>
      (delete(settings)..where((s) => s.key.equals(key))).go();

  // ============================================================================
  // Connection Log Operations
  // ============================================================================

  Future<List<ConnectionLog>> getConnectionLogs({int limit = 100}) =>
      (select(connectionLogs)
            ..orderBy([(c) => OrderingTerm.desc(c.timestamp)])
            ..limit(limit))
          .get();

  Future<int> insertConnectionLog(ConnectionLogsCompanion log) =>
      into(connectionLogs).insert(log);

  Future<int> clearConnectionLogs() => delete(connectionLogs).go();
}

// ============================================================================
// Database Connection Helper
// ============================================================================

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.databaseName));
    return NativeDatabase.createInBackground(file);
  });
}
