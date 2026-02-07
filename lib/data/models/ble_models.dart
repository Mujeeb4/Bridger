/// BLE data models for communication between Flutter and native layer

/// Possible BLE connection states
enum BleConnectionState {
  idle,
  advertising,
  connected,
  disconnected,
  error,
}

/// Extension to parse state from string
extension BleConnectionStateExtension on BleConnectionState {
  static BleConnectionState fromString(String value) {
    switch (value.toUpperCase()) {
      case 'IDLE':
        return BleConnectionState.idle;
      case 'ADVERTISING':
        return BleConnectionState.advertising;
      case 'CONNECTED':
        return BleConnectionState.connected;
      case 'DISCONNECTED':
        return BleConnectionState.disconnected;
      case 'ERROR':
        return BleConnectionState.error;
      default:
        return BleConnectionState.idle;
    }
  }
}

/// BLE event types received from native layer
enum BleEventType {
  deviceConnected,
  deviceDisconnected,
  commandReceived,
  statusChanged,
  error,
  mtuChanged,
  // iOS-specific events
  deviceDiscovered,
  smsAlert,
  callAlert,
  appNotification,
}

/// Extension to parse event type from string
extension BleEventTypeExtension on BleEventType {
  static BleEventType fromString(String value) {
    switch (value) {
      case 'deviceConnected':
        return BleEventType.deviceConnected;
      case 'deviceDisconnected':
        return BleEventType.deviceDisconnected;
      case 'commandReceived':
        return BleEventType.commandReceived;
      case 'statusChanged':
        return BleEventType.statusChanged;
      case 'error':
        return BleEventType.error;
      case 'mtuChanged':
        return BleEventType.mtuChanged;
      case 'deviceDiscovered':
        return BleEventType.deviceDiscovered;
      case 'smsAlert':
        return BleEventType.smsAlert;
      case 'callAlert':
        return BleEventType.callAlert;
      case 'appNotification':
        return BleEventType.appNotification;
      default:
        return BleEventType.statusChanged;
    }
  }
}

/// Represents a BLE event from native layer
class BleEvent {
  final BleEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  BleEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  factory BleEvent.fromMap(Map<dynamic, dynamic> map) {
    return BleEvent(
      type: BleEventTypeExtension.fromString(map['type'] as String? ?? ''),
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

/// Data model for SMS alerts sent over BLE
class SmsAlertData {
  final String from;
  final String body;
  final int threadId;
  final DateTime timestamp;

  SmsAlertData({
    required this.from,
    required this.body,
    required this.threadId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': 'SMS_RECEIVED',
    'timestamp': timestamp.millisecondsSinceEpoch,
    'data': {
      'from': from,
      'body': body,
      'threadId': threadId,
    },
  };
}

/// Data model for call alerts sent over BLE
class CallAlertData {
  final String phoneNumber;
  final String? contactName;
  final String callType; // incoming, outgoing, missed, ended
  final int duration;
  final DateTime timestamp;

  CallAlertData({
    required this.phoneNumber,
    this.contactName,
    required this.callType,
    this.duration = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': 'CALL_${callType.toUpperCase()}',
    'timestamp': timestamp.millisecondsSinceEpoch,
    'data': {
      'phoneNumber': phoneNumber,
      'contactName': contactName,
      'callType': callType,
      'duration': duration,
    },
  };
}

/// Data model for app notifications sent over BLE
class AppNotificationData {
  final String appName;
  final String packageName;
  final String? title;
  final String? body;
  final DateTime timestamp;

  AppNotificationData({
    required this.appName,
    required this.packageName,
    this.title,
    this.body,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': 'APP_NOTIFICATION',
    'timestamp': timestamp.millisecondsSinceEpoch,
    'data': {
      'appName': appName,
      'packageName': packageName,
      'title': title,
      'body': body,
    },
  };
}

/// Command received from iPhone
class BleCommand {
  final String command;
  final Map<String, dynamic> payload;
  final String? requestId;

  BleCommand({
    required this.command,
    this.payload = const {},
    this.requestId,
  });

  factory BleCommand.fromJson(Map<String, dynamic> json) {
    return BleCommand(
      command: json['cmd'] as String? ?? '',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      requestId: json['requestId'] as String?,
    );
  }
}

/// Represents a connected BLE device
class BleDevice {
  final String address;
  final String name;
  final DateTime connectedAt;

  BleDevice({
    required this.address,
    required this.name,
    required this.connectedAt,
  });
}

/// Represents a discovered BLE device during scanning (iOS only)
class ScannedDevice {
  final String id;
  final String name;
  final int rssi;

  ScannedDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });

  /// Signal strength indicator
  String get signalStrength {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }
}

