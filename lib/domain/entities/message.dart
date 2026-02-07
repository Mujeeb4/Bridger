import 'package:equatable/equatable.dart';

/// Represents an SMS message entity in the domain layer
class MessageEntity extends Equatable {
  final int id;
  final int threadId;
  final String sender;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final bool isOutgoing;
  final bool isEncrypted;
  final String status; // sent, delivered, failed

  const MessageEntity({
    required this.id,
    required this.threadId,
    required this.sender,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.isOutgoing = false,
    this.isEncrypted = false,
    this.status = 'sent',
  });

  MessageEntity copyWith({
    int? id,
    int? threadId,
    String? sender,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    bool? isOutgoing,
    bool? isEncrypted,
    String? status,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        threadId,
        sender,
        body,
        timestamp,
        isRead,
        isOutgoing,
        isEncrypted,
        status,
      ];
}
