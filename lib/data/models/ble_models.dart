/// BLE data models for communication between Flutter and native layer
library;

/// Possible BLE connection states
enum BleConnectionState {
  idle,
  scanning,
  connecting,
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
      case 'SCANNING':
        return BleConnectionState.scanning;
      case 'CONNECTING':
        return BleConnectionState.connecting;
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
  statusUpdate,
  pairingResponse,
  bulkData,
  servicesReady,
  log,
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
      case 'statusUpdate':
        return BleEventType.statusUpdate;
      case 'pairingResponse':
        return BleEventType.pairingResponse;
      case 'bulkData':
        return BleEventType.bulkData;
      case 'servicesReady':
        return BleEventType.servicesReady;
      case 'log':
        return BleEventType.log;
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
    required this.callType, required this.timestamp, this.contactName,
    this.duration = 0,
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
    required this.timestamp, this.title,
    this.body,
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
    // The command JSON from BLE has all fields at the top level:
    //   { "cmd": "...", "action": "CALL_CONTROL", "control": "ANSWER", "id": "..." }
    // Extract 'cmd' as the command name, and use the rest as payload.
    // Also support an explicit 'payload' key for structured messages.
    final cmd = json['cmd'] as String? ?? '';
    final requestId = json['requestId'] as String? ?? json['id'] as String?;

    Map<String, dynamic> payload;
    if (json.containsKey('payload') && json['payload'] is Map) {
      payload = Map<String, dynamic>.from(json['payload'] as Map);
    } else {
      // Use all top-level fields (excluding meta keys) as the payload
      payload = Map<String, dynamic>.from(json);
      payload.remove('cmd');
      payload.remove('requestId');
      payload.remove('id');
    }

    return BleCommand(
      command: cmd,
      payload: payload,
      requestId: requestId,
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
