import 'dart:convert';

/// WebSocket connection state
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Extension for WebSocketState
extension WebSocketStateExtension on WebSocketState {
  static WebSocketState fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DISCONNECTED':
        return WebSocketState.disconnected;
      case 'CONNECTING':
        return WebSocketState.connecting;
      case 'CONNECTED':
        return WebSocketState.connected;
      case 'RECONNECTING':
        return WebSocketState.reconnecting;
      case 'ERROR':
        return WebSocketState.error;
      default:
        return WebSocketState.disconnected;
    }
  }

  String get displayName {
    switch (this) {
      case WebSocketState.disconnected:
        return 'Disconnected';
      case WebSocketState.connecting:
        return 'Connecting...';
      case WebSocketState.connected:
        return 'Connected';
      case WebSocketState.reconnecting:
        return 'Reconnecting...';
      case WebSocketState.error:
        return 'Error';
    }
  }
}

/// WebSocket message types for structured communication
enum MessageType {
  smsAlert,
  callAlert,
  appNotification,
  command,
  response,
  heartbeat,
  ack,
}

/// Extension for MessageType
extension MessageTypeExtension on MessageType {
  String get value {
    switch (this) {
      case MessageType.smsAlert:
        return 'SMS_ALERT';
      case MessageType.callAlert:
        return 'CALL_ALERT';
      case MessageType.appNotification:
        return 'APP_NOTIFICATION';
      case MessageType.command:
        return 'COMMAND';
      case MessageType.response:
        return 'RESPONSE';
      case MessageType.heartbeat:
        return 'HEARTBEAT';
      case MessageType.ack:
        return 'ACK';
    }
  }

  static MessageType fromString(String value) {
    switch (value) {
      case 'SMS_ALERT':
        return MessageType.smsAlert;
      case 'CALL_ALERT':
        return MessageType.callAlert;
      case 'APP_NOTIFICATION':
        return MessageType.appNotification;
      case 'COMMAND':
        return MessageType.command;
      case 'RESPONSE':
        return MessageType.response;
      case 'HEARTBEAT':
        return MessageType.heartbeat;
      case 'ACK':
        return MessageType.ack;
      default:
        return MessageType.command;
    }
  }
}

/// Structured WebSocket message
class WebSocketMessage {
  final String id;
  final MessageType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final bool encrypted;

  WebSocketMessage({
    required this.id,
    required this.type,
    required this.payload,
    DateTime? timestamp,
    this.encrypted = false,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Generate a unique message ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           '_${DateTime.now().microsecond}';
  }

  /// Create a new message with auto-generated ID
  factory WebSocketMessage.create({
    required MessageType type,
    required Map<String, dynamic> payload,
    bool encrypted = false,
  }) {
    return WebSocketMessage(
      id: generateId(),
      type: type,
      payload: payload,
      encrypted: encrypted,
    );
  }

  /// Encode to JSON string for transmission
  String encode() => jsonEncode(toJson());

  /// Decode from received JSON string
  static WebSocketMessage? decode(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return WebSocketMessage.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.value,
    'payload': payload,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'encrypted': encrypted,
  };

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      id: json['id'] as String? ?? '',
      type: MessageTypeExtension.fromString(json['type'] as String? ?? ''),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      encrypted: json['encrypted'] as bool? ?? false,
    );
  }
}

/// WebSocket event from native layer
class WebSocketEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  WebSocketEvent({
    required this.type,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebSocketEvent.fromMap(Map<dynamic, dynamic> map) {
    return WebSocketEvent(
      type: map['type'] as String? ?? '',
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

/// Server info for connection
class ServerInfo {
  final String host;
  final int port;
  
  ServerInfo({required this.host, this.port = 8765});
  
  String get url => 'ws://$host:$port';
}
