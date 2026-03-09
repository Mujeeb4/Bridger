import 'dart:async';

import 'dart:io';

import 'package:flutter/services.dart';

import '../data/models/sms_models.dart';
import 'communication_service.dart';
import '../data/models/websocket_models.dart';

/// Service for SMS operations
/// - Android: Read inbox, send SMS, receive incoming
/// - iOS: Display synced messages, send via Android relay
class SMSService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.bridge.phone/sms');
  static const EventChannel _eventChannel =
      EventChannel('com.bridge.phone/sms_events');

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

  // Sync state stream
  final _syncStateController = StreamController<bool>.broadcast();
  Stream<bool> get syncStateStream => _syncStateController.stream;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SMSService({CommunicationService? communicationService})
      : _communicationService = communicationService;

  void setSyncing(bool syncing) {
    _isSyncing = syncing;
    _syncStateController.add(syncing);
  }

  void updateThreadsFromSync(List<dynamic> data) {
    try {
      _threads = data
          .map((e) => SMSThread.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // Sort by timestamp descending
      _threads.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _threadsController.add(_threads);
    } catch (e) {
      _errorController.add("Error parsing sync data: $e");
    }
  }

  // ============================================================================
  // Initialization
  // ============================================================================

  Future<void> initialize() async {
    _subscribeToEvents();

    // Listen for messages from communication service (iOS)
    if (isIOS && _communicationService != null) {
      _communicationService.messageStream.listen((wsMessage) {
        if (wsMessage.type == MessageType.smsAlert) {
          final smsMessage = SMSMessage(
            id: 0,
            address: wsMessage.payload['from'] as String? ??
                wsMessage.payload['sender'] as String? ??
                '',
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

    if (isAndroid) {
      // On Android, loadThreads() reads from native inbox
      loadThreads();
    } else {
      // On iOS, update the cached thread list directly since we can't read
      // the Android inbox. Find the matching thread and update its snippet,
      // or create a new thread entry if one doesn't exist.
      final threadId = message.threadId ?? 0;
      final existingIndex = _threads.indexWhere(
        (t) => t.address == message.address || t.threadId == threadId,
      );

      if (existingIndex >= 0) {
        final existing = _threads[existingIndex];
        _threads[existingIndex] = SMSThread(
          threadId: existing.threadId,
          address: existing.address,
          messageCount: existing.messageCount + 1,
          snippet: message.body,
          timestamp: message.timestamp,
          contactName: existing.contactName,
        );
      } else {
        _threads.insert(
          0,
          SMSThread(
            threadId: threadId,
            address: message.address,
            messageCount: 1,
            snippet: message.body,
            timestamp: message.timestamp,
            contactName: null,
          ),
        );
      }

      // Re-sort by timestamp descending and emit
      _threads.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _threadsController.add(_threads);
    }
  }

  Future<void> _forwardToIOS(SMSMessage message) async {
    if (_communicationService == null) return;

    final wsMessage = WebSocketMessage.create(
      type: MessageType.smsAlert,
      payload: {
        'from': message.address,
        'sender': message.address, // alias for WebSocket receivers
        'body': message.body,
        'threadId': message.threadId ?? 0,
        'timestamp': message.timestamp.millisecondsSinceEpoch,
      },
    );

    await _communicationService.send(wsMessage);
  }

  // ============================================================================
  // Read SMS (Android)
  // ============================================================================

  /// Load conversation threads
  Future<List<SMSThread>> loadThreads() async {
    if (!isAndroid) return _threads;

    try {
      final result =
          await _methodChannel.invokeMethod<List<dynamic>>('getConversations');

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
      final result =
          await _methodChannel.invokeMethod<List<dynamic>>('getMessages', {
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
      final result = await _methodChannel
          .invokeMethod<List<dynamic>>('getRecentMessages', {
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
          }) ??
          false;

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
    if (_communicationService == null || !_communicationService.isConnected) {
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

    return await _communicationService.send(wsMessage);
  }

  // ============================================================================
  // Sync
  // ============================================================================

  // Track last sync timestamp to avoid resending the same messages
  int _lastSyncTimestamp = 0;

  /// Sync messages to iOS (incremental — only messages newer than last sync)
  Future<void> syncToIOS() async {
    if (!isAndroid || _communicationService == null) return;

    final messages = await getRecentMessages(count: 50);

    // Filter to only messages after last sync
    final newMessages = messages
        .where(
          (m) => m.timestamp.millisecondsSinceEpoch > _lastSyncTimestamp,
        )
        .toList();

    if (newMessages.isEmpty) return;

    for (final message in newMessages) {
      // Use same payload format as _forwardToIOS for consistency
      final wsMessage = WebSocketMessage.create(
        type: MessageType.smsAlert,
        payload: {
          'from': message.address,
          'sender': message.address,
          'body': message.body,
          'threadId': message.threadId ?? 0,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
          'isSync': true, // Flag so iOS can distinguish bulk sync from live
        },
      );
      await _communicationService.send(wsMessage);
    }

    // Update watermark
    _lastSyncTimestamp = newMessages
        .map((m) => m.timestamp.millisecondsSinceEpoch)
        .reduce((a, b) => a > b ? a : b);
  }

  void dispose() {
    _newMessageController.close();
    _threadsController.close();
    _errorController.close();
    _syncStateController.close();
  }
}
