import 'package:equatable/equatable.dart';

/// Represents an SMS thread (conversation) entity in the domain layer
class ThreadEntity extends Equatable {
  final int id;
  final String phoneNumber;
  final String? contactName;
  final String? lastMessage;
  final DateTime? lastTimestamp;
  final int unreadCount;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ThreadEntity({
    required this.id,
    required this.phoneNumber,
    this.contactName,
    this.lastMessage,
    this.lastTimestamp,
    this.unreadCount = 0,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display name shows contact name if available, otherwise phone number
  String get displayName => contactName ?? phoneNumber;

  /// Check if thread has unread messages
  bool get hasUnread => unreadCount > 0;

  ThreadEntity copyWith({
    int? id,
    String? phoneNumber,
    String? contactName,
    String? lastMessage,
    DateTime? lastTimestamp,
    int? unreadCount,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ThreadEntity(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contactName: contactName ?? this.contactName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        phoneNumber,
        contactName,
        lastMessage,
        lastTimestamp,
        unreadCount,
        isArchived,
        createdAt,
        updatedAt,
      ];
}
