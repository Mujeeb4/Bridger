import '../entities/message.dart';
import '../entities/thread.dart';

/// Repository interface for SMS operations
abstract class SMSRepository {
  /// Get all SMS threads sorted by most recent
  Future<List<ThreadEntity>> getAllThreads();

  /// Get a specific thread by phone number
  Future<ThreadEntity?> getThreadByPhoneNumber(String phoneNumber);

  /// Get all messages for a specific thread
  Future<List<MessageEntity>> getMessagesForThread(int threadId);

  /// Save a new message
  Future<MessageEntity> saveMessage(MessageEntity message);

  /// Mark a message as read
  Future<void> markMessageAsRead(int messageId);

  /// Mark all messages in a thread as read
  Future<void> markAllMessagesAsReadInThread(int threadId);

  /// Delete a specific message
  Future<void> deleteMessage(int messageId);

  /// Delete an entire thread and its messages
  Future<void> deleteThread(int threadId);

  /// Create a new thread
  Future<ThreadEntity> createThread(String phoneNumber, {String? contactName});

  /// Update thread's last message info
  Future<void> updateThreadLastMessage(int threadId, String lastMessage, DateTime timestamp);

  /// Archive a thread
  Future<void> archiveThread(int threadId);

  /// Unarchive a thread
  Future<void> unarchiveThread(int threadId);

  /// Get unread message count
  Future<int> getTotalUnreadCount();
}
