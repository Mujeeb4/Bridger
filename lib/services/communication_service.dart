import 'dart:async';
import 'dart:io';

import '../data/models/websocket_models.dart';
import 'websocket_service.dart';
import 'ble_service.dart';

/// Unified communication service that abstracts WebSocket and BLE.
/// Automatically chooses the best available transport.
class CommunicationService {
  final WebSocketService _webSocketService;
  final BleService _bleService;

  CommunicationService({
    required WebSocketService webSocketService,
    required BleService bleService,
  })  : _webSocketService = webSocketService,
        _bleService = bleService;

  // Current transport
  TransportType _currentTransport = TransportType.none;
  TransportType get currentTransport => _currentTransport;

  // Stream controllers
  final _transportController = StreamController<TransportType>.broadcast();
  Stream<TransportType> get transportStream => _transportController.stream;

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

  Future<void> initialize() async {
    await _webSocketService.initialize();
    
    // Listen to WebSocket messages
    _webSocketService.messageStream.listen((message) {
      _messageController.add(message);
    });

    // Listen to connection state changes
    _webSocketService.stateStream.listen((state) {
      if (state == WebSocketState.connected) {
        _setTransport(TransportType.webSocket);
      } else if (state == WebSocketState.disconnected && 
                 _currentTransport == TransportType.webSocket) {
        _fallbackToBLE();
      }
    });

    // Listen to BLE connection changes
    _bleService.connectionStateStream.listen((state) {
      if (_currentTransport == TransportType.ble) {
        // Already using BLE
      }
    });
  }

  // ============================================================================
  // Transport Management
  // ============================================================================

  void _setTransport(TransportType transport) {
    _currentTransport = transport;
    _transportController.add(transport);
  }

  Future<void> _fallbackToBLE() async {
    // If WebSocket disconnected, try to use BLE
    if (await _bleService.isConnected()) {
      _setTransport(TransportType.ble);
    } else {
      _setTransport(TransportType.none);
    }
  }

  // ============================================================================
  // Android: Start Services
  // ============================================================================

  /// Start communication services (Android)
  /// Starts WebSocket server and BLE advertising
  Future<bool> startServices({int wsPort = 8765}) async {
    if (!isAndroid) return false;

    // Start WebSocket server
    final port = await _webSocketService.startServer(port: wsPort);
    
    // Start BLE advertising
    await _bleService.startAdvertising();

    if (port != null) {
      _setTransport(TransportType.webSocket);
      return true;
    }
    
    // Fallback to BLE only
    _setTransport(TransportType.ble);
    return true;
  }

  /// Stop all services (Android)
  Future<void> stopServices() async {
    if (!isAndroid) return;

    await _webSocketService.stopServer();
    await _bleService.stopAdvertising();
    _setTransport(TransportType.none);
  }

  // ============================================================================
  // iOS: Connect to Android
  // ============================================================================

  /// Connect to Android device (iOS)
  /// Tries WebSocket first, falls back to BLE
  Future<bool> connect({
    String? webSocketHost,
    String? bleDeviceId,
  }) async {
    if (!isIOS) return false;

    // Try WebSocket first if host provided
    if (webSocketHost != null) {
      final success = await _webSocketService.connect(webSocketHost);
      if (success) {
        _setTransport(TransportType.webSocket);
        return true;
      }
    }

    // Fall back to BLE
    if (bleDeviceId != null) {
      await _bleService.connect(bleDeviceId);
      if (await _bleService.isConnected()) {
        _setTransport(TransportType.ble);
        return true;
      }
    }

    return false;
  }

  /// Disconnect from Android (iOS)
  Future<void> disconnect() async {
    if (!isIOS) return;

    if (_currentTransport == TransportType.webSocket) {
      await _webSocketService.disconnect();
    }
    await _bleService.disconnect();
    _setTransport(TransportType.none);
  }

  // ============================================================================
  // Messaging
  // ============================================================================

  /// Send a message using the best available transport
  Future<bool> send(WebSocketMessage message, {String? targetClientId}) async {
    switch (_currentTransport) {
      case TransportType.webSocket:
        if (isAndroid) {
          if (targetClientId != null) {
            return await _webSocketService.sendToClient(targetClientId, message);
          } else {
            return await _webSocketService.broadcast(message);
          }
        } else {
          return await _webSocketService.send(message);
        }

      case TransportType.ble:
        // Encode message and send via BLE
        // For now, we use a simplified approach
        _errorController.add('BLE messaging not yet implemented for structured messages');
        return false;

      case TransportType.none:
        _errorController.add('No transport available');
        return false;
    }
  }

  /// Check if connected
  bool get isConnected => _currentTransport != TransportType.none;

  /// Get connection details
  Map<String, dynamic> getConnectionInfo() {
    return {
      'transport': _currentTransport.name,
      'webSocketState': _webSocketService.state.name,
      'webSocketPort': _webSocketService.serverPort,
      'connectedClients': _webSocketService.connectedClients,
    };
  }

  void dispose() {
    _transportController.close();
    _messageController.close();
    _errorController.close();
    _webSocketService.dispose();
  }
}

/// Transport type enum
enum TransportType {
  none,
  webSocket,
  ble,
}
