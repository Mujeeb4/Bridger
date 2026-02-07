import 'dart:convert';

/// SMS message model
class SMSMessage {
  final int id;
  final int? threadId;
  final String address;
  final String body;
  final DateTime timestamp;
  final SMSType type;
  final bool isRead;

  SMSMessage({
    required this.id,
    this.threadId,
    required this.address,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  factory SMSMessage.fromJson(Map<String, dynamic> json) {
    return SMSMessage(
      id: json['id'] as int? ?? 0,
      threadId: json['threadId'] as int?,
      address: json['address'] as String? ?? '',
      body: json['body'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      type: SMSType.fromValue(json['type'] as int? ?? 1),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'threadId': threadId,
    'address': address,
    'body': body,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'type': type.value,
    'isRead': isRead,
  };

  /// Check if this is an incoming message
  bool get isIncoming => type == SMSType.inbox;

  /// Check if this is an outgoing message
  bool get isOutgoing => type == SMSType.sent;

  /// Format timestamp for display
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// SMS type (matches Android Telephony.Sms.TYPE_*)
enum SMSType {
  inbox(1),
  sent(2),
  draft(3),
  outbox(4),
  failed(5),
  queued(6);

  const SMSType(this.value);
  final int value;

  static SMSType fromValue(int value) {
    switch (value) {
      case 1:
        return SMSType.inbox;
      case 2:
        return SMSType.sent;
      case 3:
        return SMSType.draft;
      case 4:
        return SMSType.outbox;
      case 5:
        return SMSType.failed;
      case 6:
        return SMSType.queued;
      default:
        return SMSType.inbox;
    }
  }
}

/// SMS conversation thread
class SMSThread {
  final int threadId;
  final String address;
  final int messageCount;
  final String snippet;
  final DateTime timestamp;
  final String? contactName;

  SMSThread({
    required this.threadId,
    required this.address,
    required this.messageCount,
    required this.snippet,
    required this.timestamp,
    this.contactName,
  });

  factory SMSThread.fromJson(Map<String, dynamic> json) {
    return SMSThread(
      threadId: (json['threadId'] as num?)?.toInt() ?? 0,
      address: json['address'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
      snippet: json['snippet'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      contactName: json['contactName'] as String?,
    );
  }

  /// Display name (contact name or phone number)
  String get displayName => contactName ?? address;

  /// Format timestamp for display
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final threadDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (threadDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (threadDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

/// SMS event from native layer
class SMSEvent {
  final SMSEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SMSEvent({
    required this.type,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SMSEvent.fromMap(Map<dynamic, dynamic> map) {
    final typeStr = map['type'] as String? ?? '';
    SMSEventType type;
    
    switch (typeStr) {
      case 'smsReceived':
        type = SMSEventType.received;
        break;
      case 'smsSent':
        type = SMSEventType.sent;
        break;
      case 'smsFailed':
        type = SMSEventType.failed;
        break;
      default:
        type = SMSEventType.received;
    }

    return SMSEvent(
      type: type,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Parse SMS message from event data
  SMSMessage? get message {
    if (data.isEmpty) return null;
    return SMSMessage(
      id: 0,
      address: data['sender'] as String? ?? data['address'] as String? ?? '',
      body: data['body'] as String? ?? '',
      timestamp: timestamp,
      type: type == SMSEventType.received ? SMSType.inbox : SMSType.sent,
    );
  }
}

/// SMS event types
enum SMSEventType {
  received,
  sent,
  failed,
}
