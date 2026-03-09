import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get_it/get_it.dart';
import '../data/models/ble_models.dart';
import '../data/models/websocket_models.dart';
import 'encryption_service.dart';
import 'websocket_service.dart';
import 'ble_service.dart';
import 'call_service.dart';
import 'sms_service.dart';

/// Unified communication service that abstracts WebSocket and BLE.
/// Automatically chooses the best available transport.
class CommunicationService {
  final WebSocketService _webSocketService;
  final BleService _bleService;
  final EncryptionService? _encryptionService;

  CommunicationService({
    required WebSocketService webSocketService,
    required BleService bleService,
    EncryptionService? encryptionService,
  })  : _webSocketService = webSocketService,
        _bleService = bleService,
        _encryptionService = encryptionService;

  // Current transport
  TransportType _currentTransport = TransportType.none;
  TransportType get currentTransport => _currentTransport;

  // Prevent duplicate initialization
  bool _initialized = false;

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
    if (_initialized) return;
    _initialized = true;

    await _webSocketService.initialize();

    // Listen to WebSocket messages — decrypt if needed
    _webSocketService.messageStream.listen((message) async {
      final decrypted = await _decryptMessage(message);
      _messageController.add(decrypted);
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
      if (state == BleConnectionState.connected &&
          _currentTransport == TransportType.none) {
        _setTransport(TransportType.ble);
      } else if (state == BleConnectionState.disconnected &&
          _currentTransport == TransportType.ble) {
        _setTransport(TransportType.none);
      }
    });

    // ---- Bridge BLE alert streams into messageStream ----
    // When iOS receives BLE notifications from Android, convert them
    // to WebSocketMessage so downstream services (SMS, Call, Notification)
    // can process them uniformly via CommunicationService.messageStream.

    _bleService.smsAlertStream.listen((jsonStr) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final nestedData = data['data'] as Map<String, dynamic>? ?? {};
        final msg = WebSocketMessage.create(
          type: MessageType.smsAlert,
          payload: {
            'from':
                nestedData['from'] as String? ?? data['from'] as String? ?? '',
            'sender':
                nestedData['from'] as String? ?? data['from'] as String? ?? '',
            'body':
                nestedData['body'] as String? ?? data['body'] as String? ?? '',
            'threadId':
                nestedData['threadId'] as int? ?? data['threadId'] as int? ?? 0,
            'timestamp': data['timestamp'],
          },
        );
        _messageController.add(msg);
      } catch (e) {
        _errorController.add('Failed to parse BLE SMS alert: $e');
      }
    });

    _bleService.callAlertStream.listen((jsonStr) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final typeStr = data['type'] as String? ?? '';
        // Map BLE type strings to action names expected by _handleRemoteCallEvent
        String action;
        if (typeStr.contains('INCOMING')) {
          action = 'INCOMING';
        } else if (typeStr.contains('ANSWERED') ||
            typeStr.contains('OUTGOING')) {
          action = 'ANSWERED';
        } else if (typeStr.contains('ENDED') || typeStr.contains('MISSED')) {
          action = 'ENDED';
        } else {
          action = typeStr.replaceFirst('CALL_', '');
        }
        final msg = WebSocketMessage.create(
          type: MessageType.callAlert,
          payload: {
            'action': action,
            'phoneNumber': data['data']?['phoneNumber'] as String? ??
                data['phoneNumber'] as String? ??
                '',
            'contactName': data['data']?['contactName'] as String? ??
                data['contactName'] as String?,
          },
        );
        _messageController.add(msg);
      } catch (e) {
        _errorController.add('Failed to parse BLE call alert: $e');
      }
    });

    _bleService.appNotificationStream.listen((jsonStr) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final nested = data['data'] as Map<String, dynamic>? ?? {};
        final msg = WebSocketMessage.create(
          type: MessageType.appNotification,
          payload: {
            'id': nested['id'] ?? data['id'] ?? '',
            'packageName': nested['packageName'] ?? data['packageName'] ?? '',
            'appName': nested['appName'] ?? data['appName'] ?? '',
            'title': nested['title'] ?? data['title'] ?? '',
            'body': nested['body'] ?? data['body'] ?? '',
            'timestamp': nested['timestamp'] ?? data['timestamp'],
          },
        );
        _messageController.add(msg);
      } catch (e) {
        _errorController.add('Failed to parse BLE notification: $e');
      }
    });

    // ---- Bridge BLE commands into messageStream (Android only) ----
    // When Android receives BLE commands from iOS (e.g., CALL_CONTROL, SEND_SMS),
    // convert them to WebSocketMessage so CommandDispatcherService can process them.
    _bleService.commandStream.listen((bleCommand) {
      // Inject the command name as 'action' into the payload
      // because CommandDispatcherService expects payload['action']
      final newPayload = Map<String, dynamic>.from(bleCommand.payload);
      if (!newPayload.containsKey('action')) {
        newPayload['action'] = bleCommand.command;
      }

      // Preserve the original request ID from the BLE command so the response
      // can be correlated back to the iOS request (sendRequest waits for matching ID).
      final msg = WebSocketMessage(
        id: bleCommand.requestId ?? WebSocketMessage.generateId(),
        type: MessageType.command,
        payload: newPayload,
      );
      _messageController.add(msg);
    });

    // ---- Bridge BLE bulk data messages into messageStream ----
    // When iOS receives bulk data responses from Android (e.g., SYNC_REQUEST response),
    // parse them as WebSocketMessage and inject into messageStream.
    _bleService.bulkMessageStream.listen((wsMessage) {
      _messageController.add(wsMessage);
    });
  }

  // ============================================================================
  // Transport Management
  // ============================================================================

  void _setTransport(TransportType transport) {
    final wasConnected = _currentTransport != TransportType.none;
    _currentTransport = transport;
    _transportController.add(transport);

    // Trigger sync if we just connected (iOS only)
    if (transport != TransportType.none && !wasConnected && isIOS) {
      requestDataSync();
    }
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
      // If already connected to this specific device, just set transport
      if (isIOS && 
          _bleService.connectedDeviceId == bleDeviceId && 
          await _bleService.isConnected()) {
         _setTransport(TransportType.ble);
         return true;
      }

      // Otherwise try to connect
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
        // Android: If no clients are connected to WebSocket, fallback to BLE.
        // This ensures alerts (e.g. incoming call) are delivered via BLE
        // while waiting for iOS to connect to the WebSocket server.
        if (isAndroid && _webSocketService.connectedClients.isEmpty) {
          return await _sendViaBle(message);
        }

        // Encrypt payload for WebSocket transport
        final encrypted = await _encryptMessage(message);
        if (isAndroid) {
          if (targetClientId != null) {
            return await _webSocketService.sendToClient(
                targetClientId, encrypted);
          } else {
            return await _webSocketService.broadcast(encrypted);
          }
        } else {
          return await _webSocketService.send(encrypted);
        }

      case TransportType.ble:
        // BLE path uses plaintext — short-range, point-to-point connection.
        // Encryption is only applied on the WebSocket/Wi-Fi path.
        return await _sendViaBle(message);

      case TransportType.none:
        _errorController.add('No transport available');
        return false;
    }
  }

  /// Send a request and wait for a response
  Future<WebSocketMessage?> sendRequest(WebSocketMessage message,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final completer = Completer<WebSocketMessage?>();

    // Listen for response with matching request ID in payload
    final subscription = messageStream.listen((response) {
      if (response.type == MessageType.response &&
          response.payload['requestId'] == message.id) {
        if (!completer.isCompleted) completer.complete(response);
      }
    });

    // Send request
    final success = await send(message);
    if (!success) {
      await subscription.cancel();
      return null;
    }

    // Wait for response or timeout
    try {
      final response = await completer.future.timeout(timeout);
      await subscription.cancel();
      return response;
    } catch (e) {
      await subscription.cancel();
      _errorController.add('Request timed out: ${message.id}');
      return null;
    }
  }

  // ============================================================================
  // WebSocket Payload Encryption
  // ============================================================================

  /// Encrypt the payload of a WebSocket message before transmission.
  /// Only encrypts content-bearing messages (SMS, notifications, commands).
  /// Heartbeats and acks are not encrypted.
  Future<WebSocketMessage> _encryptMessage(WebSocketMessage message) async {
    if (_encryptionService == null || !_encryptionService.isInitialized) {
      return message;
    }

    // Only encrypt content-bearing messages
    if (message.type == MessageType.heartbeat ||
        message.type == MessageType.ack) {
      return message;
    }

    try {
      final payloadJson = jsonEncode(message.payload);
      final encryptedPayload = await _encryptionService.encrypt(payloadJson);
      return WebSocketMessage(
        id: message.id,
        type: message.type,
        payload: {'_enc': encryptedPayload},
        timestamp: message.timestamp,
        encrypted: true,
      );
    } catch (e) {
      _errorController.add('Encryption failed, sending unencrypted: $e');
      return message;
    }
  }

  /// Decrypt the payload of a received WebSocket message.
  Future<WebSocketMessage> _decryptMessage(WebSocketMessage message) async {
    if (!message.encrypted ||
        _encryptionService == null ||
        !_encryptionService.isInitialized) {
      return message;
    }

    try {
      final encryptedPayload = message.payload['_enc'] as String?;
      if (encryptedPayload == null) return message;

      final decryptedJson = await _encryptionService.decrypt(encryptedPayload);
      final payload = jsonDecode(decryptedJson) as Map<String, dynamic>;
      return WebSocketMessage(
        id: message.id,
        type: message.type,
        payload: payload,
        timestamp: message.timestamp,
        encrypted: false,
      );
    } catch (e) {
      _errorController.add('Decryption failed: $e');
      return message;
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

  // ============================================================================
  // BLE Message Routing
  // ============================================================================

  /// Route a WebSocketMessage over BLE based on its type.
  /// Android uses the alert characteristics; iOS uses the command characteristic.
  Future<bool> _sendViaBle(WebSocketMessage message) async {
    try {
      final payload = message.payload;

      switch (message.type) {
        // Android → iOS: alert-style messages sent over dedicated BLE characteristics
        case MessageType.smsAlert:
          if (!isAndroid) {
            _errorController.add('SMS alerts can only be sent from Android');
            return false;
          }
          return await _bleService.sendSmsAlert(SmsAlertData(
            from: payload['from'] as String? ??
                payload['sender'] as String? ??
                payload['data']?['from'] as String? ??
                '',
            body: payload['body'] as String? ??
                payload['data']?['body'] as String? ??
                '',
            threadId: payload['threadId'] as int? ??
                payload['data']?['threadId'] as int? ??
                0,
            timestamp: message.timestamp,
          ));

        case MessageType.callAlert:
          if (!isAndroid) {
            _errorController.add('Call alerts can only be sent from Android');
            return false;
          }
          // Derive callType from 'action' field if 'callType' is not set,
          // since CallService sets 'action' (e.g. INCOMING, ANSWERED, ENDED)
          final action = payload['action'] as String? ?? '';
          String resolvedCallType = payload['callType'] as String? ??
              payload['data']?['callType'] as String? ??
              '';
          if (resolvedCallType.isEmpty && action.isNotEmpty) {
            resolvedCallType = action.toLowerCase();
          }
          if (resolvedCallType.isEmpty) resolvedCallType = 'incoming';

          return await _bleService.sendCallAlert(CallAlertData(
            phoneNumber: payload['phoneNumber'] as String? ??
                payload['data']?['phoneNumber'] as String? ??
                '',
            contactName: payload['contactName'] as String? ??
                payload['data']?['contactName'] as String?,
            callType: resolvedCallType,
            duration: payload['duration'] as int? ??
                payload['data']?['duration'] as int? ??
                0,
            timestamp: message.timestamp,
          ));

        case MessageType.appNotification:
          if (!isAndroid) {
            _errorController
                .add('App notifications can only be sent from Android');
            return false;
          }
          return await _bleService.sendAppNotification(AppNotificationData(
            appName: payload['appName'] as String? ??
                payload['data']?['appName'] as String? ??
                '',
            packageName: payload['packageName'] as String? ??
                payload['data']?['packageName'] as String? ??
                '',
            title: payload['title'] as String? ??
                payload['data']?['title'] as String?,
            body: payload['body'] as String? ??
                payload['data']?['body'] as String?,
            timestamp: message.timestamp,
          ));

        // iOS → Android: commands sent over CHAR_COMMAND
        case MessageType.command:
          if (!isIOS) {
            _errorController.add('Commands via BLE can only be sent from iOS');
            return false;
          }
          return await _bleService.sendCommand({
            'cmd': payload['cmd'] ?? payload['command'] ?? message.type.value,
            ...payload,
            'id': message.id,
          });

        // Generic: response / heartbeat / ack — send as JSON command payload
        case MessageType.response:
        case MessageType.heartbeat:
        case MessageType.ack:
          // Use the command characteristic (works on iOS) or bulk data (Android)
          if (isIOS) {
            return await _bleService.sendCommand({
              'type': message.type.value,
              ...payload,
              'id': message.id,
            });
          } else {
            // Android: encode the full message and send as bulk data
            final encoded = utf8.encode(message.encode());
            return await _bleService.sendBulkData(encoded);
          }
      }
    } catch (e) {
      _errorController.add('BLE send failed: $e');
      return false;
    }
  }

  void dispose() {
    _transportController.close();
    _messageController.close();
    _errorController.close();
    _webSocketService.dispose();
  }

  // ============================================================================
  // Data Sync (iOS)
  // ============================================================================

  /// Request data sync from Android (iOS only)
  /// Triggers a SYNC_REQUEST and updates Call/SMS services with the response.
  Future<void> requestDataSync() async {
    if (!isIOS) return;

    final getIt = GetIt.instance;
    // Use try-catch for service retrieval as they might not be registered in tests
    CallService? callService;
    SMSService? smsService;
    try {
      callService = getIt<CallService>();
      smsService = getIt<SMSService>();
    } catch (_) {
      // Services not registered
      return;
    }

    // Set UI state to syncing
    callService.setSyncing(true);
    smsService.setSyncing(true);

    try {
      // ignore: avoid_print
      print('[CommunicationService] Requesting data sync...');

      // Create sync request
      final request = WebSocketMessage.create(
        type: MessageType.command,
        payload: {'action': 'SYNC_REQUEST'},
      );

      // Send and wait for response
      final response =
          await sendRequest(request, timeout: const Duration(seconds: 30));

      if (response != null && response.payload['success'] == true) {
        // ignore: avoid_print
        print('[CommunicationService] Sync response received');

        // Update Call Logs
        if (response.payload.containsKey('calls')) {
          final calls = response.payload['calls'] as List;
          callService.updateCallLogFromSync(calls);
        }

        // Update SMS Threads
        if (response.payload.containsKey('sms_threads')) {
          final threads = response.payload['sms_threads'] as List;
          smsService.updateThreadsFromSync(threads);
        }
      } else {
        // ignore: avoid_print
        print('[CommunicationService] Sync failed or timed out');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CommunicationService] Sync error: $e');
    } finally {
      // Clear UI state
      callService.setSyncing(false);
      smsService.setSyncing(false);
    }
  }
}

/// Transport type enum
enum TransportType {
  none,
  webSocket,
  ble,
}
