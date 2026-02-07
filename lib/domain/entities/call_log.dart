import 'package:equatable/equatable.dart';

/// Call type enumeration
enum CallType {
  incoming,
  outgoing,
  missed,
  rejected,
}

/// Represents a call log entry entity in the domain layer
class CallLogEntity extends Equatable {
  final int id;
  final String phoneNumber;
  final String? contactName;
  final CallType callType;
  final int duration; // in seconds
  final DateTime timestamp;
  final bool isNew;

  const CallLogEntity({
    required this.id,
    required this.phoneNumber,
    this.contactName,
    required this.callType,
    this.duration = 0,
    required this.timestamp,
    this.isNew = true,
  });

  /// Display name shows contact name if available, otherwise phone number
  String get displayName => contactName ?? phoneNumber;

  /// Check if this is a missed or rejected call
  bool get isMissed => callType == CallType.missed || callType == CallType.rejected;

  /// Format call duration as mm:ss or hh:mm:ss
  String get formattedDuration {
    if (duration == 0) return '0:00';
    
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Convert string to CallType enum
  static CallType callTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'incoming':
        return CallType.incoming;
      case 'outgoing':
        return CallType.outgoing;
      case 'missed':
        return CallType.missed;
      case 'rejected':
        return CallType.rejected;
      default:
        return CallType.incoming;
    }
  }

  /// Convert CallType enum to string
  static String callTypeToString(CallType type) {
    return type.name;
  }

  CallLogEntity copyWith({
    int? id,
    String? phoneNumber,
    String? contactName,
    CallType? callType,
    int? duration,
    DateTime? timestamp,
    bool? isNew,
  }) {
    return CallLogEntity(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contactName: contactName ?? this.contactName,
      callType: callType ?? this.callType,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      isNew: isNew ?? this.isNew,
    );
  }

  @override
  List<Object?> get props => [
        id,
        phoneNumber,
        contactName,
        callType,
        duration,
        timestamp,
        isNew,
      ];
}
