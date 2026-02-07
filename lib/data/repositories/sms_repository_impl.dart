import 'package:drift/drift.dart';

import '../../datasources/local/database.dart';
import '../../../domain/entities/message.dart';
import '../../../domain/entities/thread.dart';
import '../../../domain/repositories/sms_repository.dart';
import '../../../services/encryption_service.dart';

/// Implementation of SMSRepository using Drift database
class SMSRepositoryImpl implements SMSRepository {
  final AppDatabase _database;
  final EncryptionService _encryptionService;

  SMSRepositoryImpl(this._database, this._encryptionService);

  // ============================================================================
  // Thread Operations
  // ============================================================================

  @override
  Future<List<ThreadEntity>> getAllThreads() async {
    final threads = await _database.getAllThreads();
    return threads.map(_mapThreadToEntity).toList();
  }

  @override
  Future<ThreadEntity?> getThreadByPhoneNumber(String phoneNumber) async {
    final thread = await _database.getThreadByPhoneNumber(phoneNumber);
    return thread != null ? _mapThreadToEntity(thread) : null;
  }

  @override
  Future<ThreadEntity> createThread(String phoneNumber, {String? contactName}) async {
    final id = await _database.insertThread(
      ThreadsCompanion.insert(
        phoneNumber: phoneNumber,
        contactName: Value(contactName),
      ),
    );
    
    final thread = await (
      _database.select(_database.threads)
        ..where((t) => t.id.equals(id))
    ).getSingle();
    
    return _mapThreadToEntity(thread);
  }

  @override
  Future<void> updateThreadLastMessage(int threadId, String lastMessage, DateTime timestamp) async {
    await (_database.update(_database.threads)
      ..where((t) => t.id.equals(threadId))
    ).write(ThreadsCompanion(
      lastMessage: Value(lastMessage),
      lastTimestamp: Value(timestamp),
      updatedAt: Value(DateTime.now()),
    ));
  }

  @override
  Future<void> archiveThread(int threadId) async {
    await (_database.update(_database.threads)
      ..where((t) => t.id.equals(threadId))
    ).write(const ThreadsCompanion(isArchived: Value(true)));
  }

  @override
  Future<void> unarchiveThread(int threadId) async {
    await (_database.update(_database.threads)
      ..where((t) => t.id.equals(threadId))
    ).write(const ThreadsCompanion(isArchived: Value(false)));
  }

  @override
  Future<void> deleteThread(int threadId) async {
    // Delete all messages first
    await _database.deleteMessagesForThread(threadId);
    // Then delete the thread
    await _database.deleteThread(threadId);
  }

  // ============================================================================
  // Message Operations
  // ============================================================================

  @override
  Future<List<MessageEntity>> getMessagesForThread(int threadId) async {
    final messages = await _database.getMessagesForThread(threadId);
    
    final entities = <MessageEntity>[];
    for (final message in messages) {
      entities.add(await _mapMessageToEntity(message));
    }
    return entities;
  }

  @override
  Future<MessageEntity> saveMessage(MessageEntity message) async {
    String? encryptedBody;
    bool isEncrypted = false;

    // Encrypt the message body if encryption service is initialized
    if (_encryptionService.isInitialized) {
      encryptedBody = await _encryptionService.encrypt(message.body);
      isEncrypted = true;
    }

    final id = await _database.insertMessage(
      MessagesCompanion.insert(
        threadId: message.threadId,
        sender: message.sender,
        body: isEncrypted ? '' : message.body, // Don't store plain text if encrypted
        encryptedBody: Value(encryptedBody),
        isEncrypted: Value(isEncrypted),
        isOutgoing: Value(message.isOutgoing),
        isRead: Value(message.isRead),
        status: Value(message.status),
        timestamp: message.timestamp,
      ),
    );

    // Update thread's last message
    await updateThreadLastMessage(
      message.threadId,
      message.body.length > 50 ? '${message.body.substring(0, 50)}...' : message.body,
      message.timestamp,
    );

    // Update unread count if incoming message
    if (!message.isOutgoing && !message.isRead) {
      await _incrementUnreadCount(message.threadId);
    }

    return message.copyWith(id: id, isEncrypted: isEncrypted);
  }

  @override
  Future<void> markMessageAsRead(int messageId) async {
    await _database.markMessageAsRead(messageId);
  }

  @override
  Future<void> markAllMessagesAsReadInThread(int threadId) async {
    await _database.markAllMessagesAsReadInThread(threadId);
    
    // Reset unread count
    await (_database.update(_database.threads)
      ..where((t) => t.id.equals(threadId))
    ).write(const ThreadsCompanion(unreadCount: Value(0)));
  }

  @override
  Future<void> deleteMessage(int messageId) async {
    await _database.deleteMessage(messageId);
  }

  @override
  Future<int> getTotalUnreadCount() async {
    final threads = await _database.getAllThreads();
    return threads.fold<int>(0, (sum, thread) => sum + thread.unreadCount);
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  ThreadEntity _mapThreadToEntity(Thread thread) {
    return ThreadEntity(
      id: thread.id,
      phoneNumber: thread.phoneNumber,
      contactName: thread.contactName,
      lastMessage: thread.lastMessage,
      lastTimestamp: thread.lastTimestamp,
      unreadCount: thread.unreadCount,
      isArchived: thread.isArchived,
      createdAt: thread.createdAt,
      updatedAt: thread.updatedAt,
    );
  }

  Future<MessageEntity> _mapMessageToEntity(Message message) async {
    String body = message.body;
    
    // Decrypt if encrypted
    if (message.isEncrypted && 
        message.encryptedBody != null && 
        _encryptionService.isInitialized) {
      try {
        body = await _encryptionService.decrypt(message.encryptedBody!);
      } catch (e) {
        body = '[Unable to decrypt message]';
      }
    }

    return MessageEntity(
      id: message.id,
      threadId: message.threadId,
      sender: message.sender,
      body: body,
      timestamp: message.timestamp,
      isRead: message.isRead,
      isOutgoing: message.isOutgoing,
      isEncrypted: message.isEncrypted,
      status: message.status,
    );
  }

  Future<void> _incrementUnreadCount(int threadId) async {
    final thread = await (
      _database.select(_database.threads)
        ..where((t) => t.id.equals(threadId))
    ).getSingle();
    
    await (_database.update(_database.threads)
      ..where((t) => t.id.equals(threadId))
    ).write(ThreadsCompanion(
      unreadCount: Value(thread.unreadCount + 1),
    ));
  }
}
