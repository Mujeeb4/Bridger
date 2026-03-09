import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/models/notification_models.dart';
import '../data/models/websocket_models.dart';
import 'communication_service.dart';

/// Service for managing notification mirroring
class NotificationService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.bridge.phone/notification');
  static const EventChannel _eventChannel =
      EventChannel('com.bridge.phone/notification_events');

  final CommunicationService? _communicationService;

  StreamSubscription? _eventSubscription;
  StreamSubscription? _remoteMessageSubscription;

  // Stream for UI updates
  final _notificationStreamController =
      StreamController<BridgerNotification>.broadcast();
  Stream<BridgerNotification> get notificationStream =>
      _notificationStreamController.stream;

  // Sync state stream
  final _syncStateController = StreamController<bool>.broadcast();
  Stream<bool> get syncStateStream => _syncStateController.stream;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  void setSyncing(bool syncing) {
    _isSyncing = syncing;
    _syncStateController.add(syncing);
  }

  bool get isAndroid => Platform.isAndroid;
  bool get isIOS => Platform.isIOS;

  NotificationService({CommunicationService? communicationService})
      : _communicationService = communicationService;

  // ============================================================================
  // Initialization
  // ============================================================================

  Future<void> initialize() async {
    if (isAndroid) {
      _startListeningToNativeEvents();
    } else if (isIOS) {
      _startListeningToRemoteEvents();
    }
  }

  // ============================================================================
  // Android: Listen to local notifications
  // ============================================================================

  void _startListeningToNativeEvents() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
      final map = event as Map<dynamic, dynamic>;
      final type = map['type'] as String?;
      final data = Map<String, dynamic>.from(map['data'] as Map);

      if (type == 'notificationPosted') {
        _handleNotificationPosted(data);
      } else if (type == 'notificationRemoved') {
        _handleNotificationRemoved(data);
      }
    });
  }

  void _handleNotificationPosted(Map<String, dynamic> data) async {
    final notification = BridgerNotification.fromMap(data);

    // Add to stream for local UI (if needed)
    _notificationStreamController.add(notification);

    // Forward to iOS
    await _mirrorToIOS(notification);
  }

  void _handleNotificationRemoved(Map<String, dynamic> data) async {
    final id = (data['id'] as int?)?.toString() ?? '';

    // Forward removal to iOS
    _sendRemovalToIOS(id);
  }

  /// Sync active notifications from Android to iOS
  Future<void> syncActiveNotifications() async {
    if (!isAndroid) return;

    try {
      final List<dynamic>? result =
          await _methodChannel.invokeMethod('getActiveNotifications');

      if (result != null) {
        for (final item in result) {
          if (item is Map) {
            final data = Map<String, dynamic>.from(item);
            final notification = BridgerNotification.fromMap(data);
            await _mirrorToIOS(notification);
          }
        }
      }
    } on PlatformException catch (e) {
      print("Error syncing active notifications: ${e.message}");
    }
  }

  Future<void> _mirrorToIOS(BridgerNotification notification) async {
    if (_communicationService == null) return;

    final wsMessage = WebSocketMessage.create(
      type: MessageType.appNotification,
      payload: notification.toMap(),
    );

    await _communicationService.send(wsMessage);
  }

  Future<void> _sendRemovalToIOS(String id) async {
    if (_communicationService == null) return;

    final wsMessage = WebSocketMessage.create(
      type: MessageType.appNotification,
      payload: {
        'action': 'REMOVE',
        'id': id,
      },
    );

    await _communicationService.send(wsMessage);
  }

  // ============================================================================
  // iOS: Listen to remote notifications
  // ============================================================================

  void _startListeningToRemoteEvents() async {
    if (_communicationService == null) return;

    _remoteMessageSubscription =
        _communicationService.messageStream.listen((wsMessage) {
      if (wsMessage.type == MessageType.appNotification) {
        final payload = wsMessage.payload;

        if (payload['action'] == 'REMOVE') {
          final id = payload['id'] as String?;
          if (id != null) {
            _removeLocalNotification(id);
          }
        } else {
          // New notification
          final notification = BridgerNotification.fromJson(payload);
          _notificationStreamController.add(notification);
          _showLocalNotification(notification);
        }
      }
    });

    // Request permission on init
    await _methodChannel.invokeMethod('requestPermission');
  }

  Future<void> _showLocalNotification(BridgerNotification notification) async {
    // Show using platform channel to native NotificationHandler
    // Use appName for subtitle if available, otherwise fall back to packageName
    final displayTitle =
        notification.appName != null && notification.appName!.isNotEmpty
            ? '${notification.appName}: ${notification.title}'
            : notification.title;
    try {
      await _methodChannel.invokeMethod('showNotification', {
        'id': notification.id,
        'title': displayTitle,
        'body': notification.body,
        'packageName': notification.packageName,
        'appName': notification.appName ?? notification.packageName,
      });
    } on PlatformException catch (e) {
      print("Error showing notification: ${e.message}");
    }
  }

  Future<void> _removeLocalNotification(String id) async {
    try {
      await _methodChannel.invokeMethod('removeNotification', {'id': id});
    } on PlatformException {
      // Ignore
    }
  }

  // ============================================================================
  // Permissions
  // ============================================================================

  Future<bool> isPermissionGranted() async {
    if (!isAndroid) return true; // iOS permission handled via request
    try {
      return await _methodChannel.invokeMethod<bool>('isPermissionGranted') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      return await _methodChannel.invokeMethod<bool>('requestPermission') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _remoteMessageSubscription?.cancel();
    _notificationStreamController.close();
    _syncStateController.close();
  }
}
