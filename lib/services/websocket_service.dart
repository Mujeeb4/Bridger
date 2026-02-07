import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/models/websocket_models.dart';

/// Service for WebSocket communication
/// - Android: Hosts WebSocket server
/// - iOS: Connects as WebSocket client
class WebSocketService {
  static const MethodChannel _methodChannel = MethodChannel('com.bridge.phone/websocket');
  static const EventChannel _eventChannel = EventChannel('com.bridge.phone/websocket_events');

  Stream<WebSocketEvent>? _eventStream;

  // Current state
  WebSocketState _state = WebSocketState.disconnected;
  WebSocketState get state => _state;

  // Server info (Android)
  int? _serverPort;
  int? get serverPort => _serverPort;

  // Connected clients (Android) or connection status (iOS)
  final List<String> _connectedClients = [];
  List<String> get connectedClients => List.unmodifiable(_connectedClients);

  // Stream controllers
  final _stateController = StreamController<WebSocketState>.broadcast();
  Stream<WebSocketState> get stateStream => _stateController.stream;

  final _messageController = StreamController<WebSocketMessage>.broadcast();
  Stream<WebSocketMessage> get messageStream => _messageController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  // Platform checks
  bool get isAndroid => Platform.isAndroid;
  bool get isIOS => Platform.isIOS;

  // ============================================================================
  // Initialization
  // ============================================================================

  Future<bool> initialize() async {
    try {
      _subscribeToEvents();
      return true;
    } catch (e) {
      _errorController.add('Failed to initialize: $e');
      return false;
    }
  }

  void _subscribeToEvents() {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => WebSocketEvent.fromMap(event as Map<dynamic, dynamic>));

    _eventStream!.listen(_handleEvent);
  }

  void _handleEvent(WebSocketEvent event) {
    switch (event.type) {
      case 'serverStarted':
        _state = WebSocketState.connected;
        _serverPort = event.data['port'] as int?;
        break;

      case 'serverStopped':
        _state = WebSocketState.disconnected;
        _serverPort = null;
        _connectedClients.clear();
        break;

      case 'clientConnected':
        final clientId = event.data['clientId'] as String?;
        if (clientId != null) _connectedClients.add(clientId);
        break;

      case 'clientDisconnected':
        final clientId = event.data['clientId'] as String?;
        if (clientId != null) _connectedClients.remove(clientId);
        break;

      case 'connected':
        _state = WebSocketState.connected;
        break;

      case 'disconnected':
        _state = WebSocketState.disconnected;
        break;

      case 'messageReceived':
        final messageStr = event.data['message'] as String?;
        if (messageStr != null) {
          final message = WebSocketMessage.decode(messageStr);
          if (message != null) {
            _messageController.add(message);
          }
        }
        break;

      case 'error':
        _state = WebSocketState.error;
        final error = event.data['message'] as String? ?? 'Unknown error';
        _errorController.add(error);
        break;
    }

    _stateController.add(_state);
  }

  // ============================================================================
  // Android: Server Control
  // ============================================================================

  /// Start WebSocket server (Android only)
  Future<int?> startServer({int port = 8765}) async {
    if (!isAndroid) return null;

    try {
      _updateState(WebSocketState.connecting);
      final result = await _methodChannel.invokeMethod<int>('startServer', {
        'port': port,
      });
      
      if (result != null) {
        _serverPort = result;
        _updateState(WebSocketState.connected);
      }
      return result;
    } on PlatformException catch (e) {
      _errorController.add('Failed to start server: ${e.message}');
      _updateState(WebSocketState.error);
      return null;
    }
  }

  /// Stop WebSocket server (Android only)
  Future<void> stopServer() async {
    if (!isAndroid) return;

    try {
      await _methodChannel.invokeMethod('stopServer');
      _serverPort = null;
      _connectedClients.clear();
      _updateState(WebSocketState.disconnected);
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop server: ${e.message}');
    }
  }

  /// Send message to specific client (Android only)
  Future<bool> sendToClient(String clientId, WebSocketMessage message) async {
    if (!isAndroid) return false;

    try {
      await _methodChannel.invokeMethod('sendMessage', {
        'clientId': clientId,
        'message': message.encode(),
      });
      return true;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send message: ${e.message}');
      return false;
    }
  }

  /// Broadcast message to all clients (Android only)
  Future<bool> broadcast(WebSocketMessage message) async {
    if (!isAndroid) return false;

    try {
      await _methodChannel.invokeMethod('broadcast', {
        'message': message.encode(),
      });
      return true;
    } on PlatformException catch (e) {
      _errorController.add('Failed to broadcast: ${e.message}');
      return false;
    }
  }

  /// Get Android's IP address for clients to connect
  Future<String?> getServerAddress() async {
    if (!isAndroid) return null;

    try {
      return await _methodChannel.invokeMethod<String>('getServerAddress');
    } on PlatformException {
      return null;
    }
  }

  // ============================================================================
  // iOS: Client Control
  // ============================================================================

  /// Connect to Android WebSocket server (iOS only)
  Future<bool> connect(String host, {int port = 8765}) async {
    if (!isIOS) return false;

    try {
      _updateState(WebSocketState.connecting);
      final success = await _methodChannel.invokeMethod<bool>('connect', {
        'host': host,
        'port': port,
      }) ?? false;

      if (success) {
        _updateState(WebSocketState.connected);
      } else {
        _updateState(WebSocketState.error);
      }
      return success;
    } on PlatformException catch (e) {
      _errorController.add('Failed to connect: ${e.message}');
      _updateState(WebSocketState.error);
      return false;
    }
  }

  /// Disconnect from server (iOS only)
  Future<void> disconnect() async {
    if (!isIOS) return;

    try {
      await _methodChannel.invokeMethod('disconnect');
      _updateState(WebSocketState.disconnected);
    } on PlatformException catch (e) {
      _errorController.add('Failed to disconnect: ${e.message}');
    }
  }

  /// Send message to server (iOS only)
  Future<bool> send(WebSocketMessage message) async {
    if (!isIOS) return false;

    try {
      await _methodChannel.invokeMethod('send', {
        'message': message.encode(),
      });
      return true;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send: ${e.message}');
      return false;
    }
  }

  /// Send binary data (Android & iOS)
  /// Used for audio streaming
  Future<bool> sendBinary(Uint8List data) async {
    try {
      if (isAndroid) {
        // Broadcast binary to all clients (Server mode)
        await _methodChannel.invokeMethod('broadcastBinary', {
          'data': data,
        });
      } else if (isIOS) {
        // Send binary to server (Client mode)
        await _methodChannel.invokeMethod('send', {
          'data': data,
        });
      }
      return true;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send binary: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // Common
  // ============================================================================

  void _updateState(WebSocketState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    _stateController.close();
    _messageController.close();
    _errorController.close();
  }
}
