/// Hotspot data models

/// Hotspot credentials for Wi-Fi connection
class HotspotCredentials {
  final String ssid;
  final String password;
  final DateTime receivedAt;

  HotspotCredentials({
    required this.ssid,
    required this.password,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'ssid': ssid,
    'password': password,
    'receivedAt': receivedAt.toIso8601String(),
  };

  factory HotspotCredentials.fromJson(Map<String, dynamic> json) {
    return HotspotCredentials(
      ssid: json['ssid'] as String,
      password: json['password'] as String,
      receivedAt: json['receivedAt'] != null 
          ? DateTime.parse(json['receivedAt'] as String)
          : null,
    );
  }
}

/// Hotspot state enum
enum HotspotState {
  idle,
  starting,
  active,
  connecting,
  connected,
  stopping,
  error,
}

/// Extension to parse state from string
extension HotspotStateExtension on HotspotState {
  static HotspotState fromString(String value) {
    switch (value.toUpperCase()) {
      case 'IDLE':
        return HotspotState.idle;
      case 'STARTING':
        return HotspotState.starting;
      case 'ACTIVE':
        return HotspotState.active;
      case 'CONNECTING':
        return HotspotState.connecting;
      case 'CONNECTED':
        return HotspotState.connected;
      case 'STOPPING':
        return HotspotState.stopping;
      case 'ERROR':
        return HotspotState.error;
      default:
        return HotspotState.idle;
    }
  }

  String get name {
    switch (this) {
      case HotspotState.idle:
        return 'Idle';
      case HotspotState.starting:
        return 'Starting...';
      case HotspotState.active:
        return 'Active';
      case HotspotState.connecting:
        return 'Connecting...';
      case HotspotState.connected:
        return 'Connected';
      case HotspotState.stopping:
        return 'Stopping...';
      case HotspotState.error:
        return 'Error';
    }
  }
}

/// Hotspot event types
enum HotspotEventType {
  started,
  stopped,
  connectionInitiated,
  connected,
  disconnected,
  error,
}

/// Hotspot event from native layer
class HotspotEvent {
  final HotspotEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  HotspotEvent({
    required this.type,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory HotspotEvent.fromMap(Map<dynamic, dynamic> map) {
    final typeStr = map['type'] as String? ?? '';
    HotspotEventType type;
    
    switch (typeStr) {
      case 'started':
        type = HotspotEventType.started;
        break;
      case 'stopped':
        type = HotspotEventType.stopped;
        break;
      case 'connectionInitiated':
        type = HotspotEventType.connectionInitiated;
        break;
      case 'connected':
        type = HotspotEventType.connected;
        break;
      case 'disconnected':
        type = HotspotEventType.disconnected;
        break;
      case 'error':
        type = HotspotEventType.error;
        break;
      default:
        type = HotspotEventType.error;
    }

    return HotspotEvent(
      type: type,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
