import 'dart:convert';

/// Call state enum
enum CallState {
  idle,
  ringing,
  active,
  onHold,
  ended,
}

extension CallStateExtension on CallState {
  static CallState fromString(String value) {
    switch (value.toLowerCase()) {
      case 'idle':
        return CallState.idle;
      case 'ringing':
        return CallState.ringing;
      case 'active':
        return CallState.active;
      case 'onhold':
        return CallState.onHold;
      case 'ended':
        return CallState.ended;
      default:
        return CallState.idle;
    }
  }

  String get displayName {
    switch (this) {
      case CallState.idle:
        return 'Idle';
      case CallState.ringing:
        return 'Ringing';
      case CallState.active:
        return 'Active';
      case CallState.onHold:
        return 'On Hold';
      case CallState.ended:
        return 'Ended';
    }
  }
}

/// Call type enum
enum CallType {
  incoming(1),
  outgoing(2),
  missed(3),
  rejected(4),
  blocked(5),
  voicemail(6);

  const CallType(this.value);
  final int value;

  static CallType fromValue(int value) {
    switch (value) {
      case 1:
        return CallType.incoming;
      case 2:
        return CallType.outgoing;
      case 3:
        return CallType.missed;
      case 4:
        return CallType.rejected;
      case 5:
        return CallType.blocked;
      case 6:
        return CallType.voicemail;
      default:
        return CallType.incoming;
    }
  }

  String get displayName {
    switch (this) {
      case CallType.incoming:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
      case CallType.rejected:
        return 'Rejected';
      case CallType.blocked:
        return 'Blocked';
      case CallType.voicemail:
        return 'Voicemail';
    }
  }
}

/// Active call information
class CallInfo {
  final String phoneNumber;
  final String? contactName;
  final CallType type;
  final CallState state;
  final DateTime startTime;
  final bool isMuted;
  final bool isSpeakerOn;

  CallInfo({
    required this.phoneNumber,
    this.contactName,
    required this.type,
    required this.state,
    required this.startTime,
    this.isMuted = false,
    this.isSpeakerOn = false,
  });

  /// Display name (contact name or phone number)
  String get displayName => contactName ?? phoneNumber;

  /// Call duration from start time
  Duration get duration => DateTime.now().difference(startTime);

  /// Format duration as mm:ss
  String get formattedDuration {
    final d = duration;
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  CallInfo copyWith({
    String? phoneNumber,
    String? contactName,
    CallType? type,
    CallState? state,
    DateTime? startTime,
    bool? isMuted,
    bool? isSpeakerOn,
  }) {
    return CallInfo(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contactName: contactName ?? this.contactName,
      type: type ?? this.type,
      state: state ?? this.state,
      startTime: startTime ?? this.startTime,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
    );
  }
}

/// Call log entry
class CallLogEntry {
  final int id;
  final String number;
  final String? name;
  final CallType type;
  final DateTime timestamp;
  final int durationSeconds;

  CallLogEntry({
    required this.id,
    required this.number,
    this.name,
    required this.type,
    required this.timestamp,
    required this.durationSeconds,
  });

  factory CallLogEntry.fromJson(Map<String, dynamic> json) {
    return CallLogEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      number: json['number'] as String? ?? '',
      name: json['name'] as String?,
      type: CallType.fromValue((json['type'] as num?)?.toInt() ?? 1),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
    );
  }

  /// Display name (contact name or phone number)
  String get displayName => (name != null && name!.isNotEmpty) ? name! : number;

  /// Format duration for display
  String get formattedDuration {
    if (durationSeconds == 0) return '';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Format timestamp for display
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (entryDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (entryDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

/// Call event from native layer
class CallEvent {
  final CallEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  CallEvent({
    required this.type,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory CallEvent.fromMap(Map<dynamic, dynamic> map) {
    final typeStr = map['type'] as String? ?? '';
    CallEventType type;
    
    switch (typeStr) {
      case 'incomingCall':
        type = CallEventType.incoming;
        break;
      case 'outgoingCall':
        type = CallEventType.outgoing;
        break;
      case 'callAnswered':
        type = CallEventType.answered;
        break;
      case 'callEnded':
        type = CallEventType.ended;
        break;
      case 'missedCall':
        type = CallEventType.missed;
        break;
      default:
        type = CallEventType.ended;
    }

    return CallEvent(
      type: type,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

/// Call event types
enum CallEventType {
  incoming,
  outgoing,
  answered,
  ended,
  missed,
}
