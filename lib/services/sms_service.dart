import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/models/sms_models.dart';
import 'communication_service.dart';
import '../data/models/websocket_models.dart';

/// Service for SMS operations
/// - Android: Read inbox, send SMS, receive incoming
/// - iOS: Display synced messages, send via Android relay
class SMSService {
  static const MethodChannel _methodChannel = MethodChannel('com.bridge.phone/sms');
  static const EventChannel _eventChannel = EventChannel('com.bridge.phone/sms_events');

  final CommunicationService? _communicationService;

  Stream<SMSEvent>? _eventStream;

  // Cached data
  List<SMSThread> _threads = [];
  List<SMSThread> get threads => List.unmodifiable(_threads);

  final Map<int, List<SMSMessage>> _messagesByThread = {};

  // Stream controllers
  final _newMessageController = StreamController<SMSMessage>.broadcast();
  Stream<SMSMessage> get newMessageStream => _newMessageController.stream;

  final _threadsController = StreamController<List<SMSThread>>.broadcast();
  Stream<List<SMSThread>> get threadsStream => _threadsController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  // Platform checks
  bool get isAndroid => Platform.isAndroid;
  bool get isIOS => Platform.isIOS;

  SMSService({CommunicationService? communicationService})
      : _communicationService = communicationService;

  // ============================================================================
  // Initialization
  // ============================================================================

  Future<void> initialize() async {
    _subscribeToEvents();
    
    // Listen for messages from communication service (iOS)
    if (isIOS && _communicationService != null) {
      _communicationService!.messageStream.listen((wsMessage) {
        if (wsMessage.type == MessageType.smsAlert) {
          final smsMessage = SMSMessage(
            id: 0,
            address: wsMessage.payload['sender'] as String? ?? '',
            body: wsMessage.payload['body'] as String? ?? '',
            timestamp: wsMessage.timestamp,
            type: SMSType.inbox,
          );
          _handleNewMessage(smsMessage);
        }
      });
    }
  }

  void _subscribeToEvents() {
    if (!isAndroid) return;

    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => SMSEvent.fromMap(event as Map<dynamic, dynamic>));

    _eventStream!.listen(_handleEvent);
  }

  void _handleEvent(SMSEvent event) {
    switch (event.type) {
      case SMSEventType.received:
        final message = event.message;
        if (message != null) {
          _handleNewMessage(message);
          // Forward to iOS via communication service
          _forwardToIOS(message);
        }
        break;

      case SMSEventType.sent:
        // Refresh thread if needed
        break;

      case SMSEventType.failed:
        final error = event.data['error'] as String? ?? 'Failed to send SMS';
        _errorController.add(error);
        break;
    }
  }

  void _handleNewMessage(SMSMessage message) {
    _newMessageController.add(message);
    // Refresh threads
    loadThreads();
  }

  Future<void> _forwardToIOS(SMSMessage message) async {
    if (_communicationService == null) return;

    final wsMessage = WebSocketMessage.create(
      type: MessageType.smsAlert,
      payload: {
        'sender': message.address,
        'body': message.body,
        'timestamp': message.timestamp.millisecondsSinceEpoch,
      },
    );

    await _communicationService!.send(wsMessage);
  }

  // ============================================================================
  // Read SMS (Android)
  // ============================================================================

  /// Load conversation threads
  Future<List<SMSThread>> loadThreads() async {
    if (!isAndroid) return _threads;

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getConversations');
      
      if (result != null) {
        _threads = result
            .cast<Map<dynamic, dynamic>>()
            .map((e) => SMSThread.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _threadsController.add(_threads);
      }
      return _threads;
    } on PlatformException catch (e) {
      _errorController.add('Failed to load threads: ${e.message}');
      return [];
    }
  }

  /// Load messages for a thread
  Future<List<SMSMessage>> loadMessages(int threadId, {int limit = 50}) async {
    if (!isAndroid) return _messagesByThread[threadId] ?? [];

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getMessages', {
        'threadId': threadId,
        'limit': limit,
      });

      if (result != null) {
        final messages = result
            .cast<Map<dynamic, dynamic>>()
            .map((e) => SMSMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _messagesByThread[threadId] = messages;
        return messages;
      }
      return [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to load messages: ${e.message}');
      return [];
    }
  }

  /// Get recent messages for sync
  Future<List<SMSMessage>> getRecentMessages({int count = 100}) async {
    if (!isAndroid) return [];

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getRecentMessages', {
        'count': count,
      });

      if (result != null) {
        return result
            .cast<Map<dynamic, dynamic>>()
            .map((e) => SMSMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } on PlatformException catch (e) {
      _errorController.add('Failed to get recent messages: ${e.message}');
      return [];
    }
  }

  // ============================================================================
  // Send SMS
  // ============================================================================

  /// Send SMS message
  /// - Android: Send directly via SmsManager
  /// - iOS: Relay to Android via communication service
  Future<bool> sendSMS(String phoneNumber, String message) async {
    if (isAndroid) {
      return _sendSMSAndroid(phoneNumber, message);
    } else if (isIOS) {
      return _sendSMSViaiOS(phoneNumber, message);
    }
    return false;
  }

  Future<bool> _sendSMSAndroid(String phoneNumber, String message) async {
    try {
      final success = await _methodChannel.invokeMethod<bool>('sendSMS', {
        'phoneNumber': phoneNumber,
        'message': message,
      }) ?? false;

      if (success) {
        // Refresh threads
        loadThreads();
      }
      return success;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send SMS: ${e.message}');
      return false;
    }
  }

  Future<bool> _sendSMSViaiOS(String phoneNumber, String message) async {
    if (_communicationService == null || !_communicationService!.isConnected) {
      _errorController.add('Not connected to Android device');
      return false;
    }

    final wsMessage = WebSocketMessage.create(
      type: MessageType.command,
      payload: {
        'action': 'SEND_SMS',
        'phoneNumber': phoneNumber,
        'message': message,
      },
    );

    return await _communicationService!.send(wsMessage);
  }

  // ============================================================================
  // Sync
  // ============================================================================

  /// Sync messages to iOS
  Future<void> syncToIOS() async {
    if (!isAndroid || _communicationService == null) return;

    final messages = await getRecentMessages(count: 50);
    
    for (final message in messages) {
      final wsMessage = WebSocketMessage.create(
        type: MessageType.smsAlert,
        payload: message.toJson(),
      );
      await _communicationService!.send(wsMessage);
    }
  }

  void dispose() {
    _newMessageController.close();
    _threadsController.close();
    _errorController.close();
  }
}
