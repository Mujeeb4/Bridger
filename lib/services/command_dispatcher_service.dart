import 'dart:async';
import 'dart:io';

import '../data/models/websocket_models.dart';
import 'communication_service.dart';
import 'sms_service.dart';
import 'call_service.dart';
import 'hotspot_service.dart';
import 'notification_service.dart';

/// Dispatches incoming commands from iOS to Android native handlers.
///
/// On Android, this listens to [CommunicationService.messageStream] for
/// [MessageType.command] messages and routes them to the appropriate service
/// (SMS, Call, Hotspot, etc.). Sends a [MessageType.response] back to iOS with the
/// result.
class CommandDispatcherService {
  final CommunicationService _communicationService;
  final SMSService _smsService;
  final CallService _callService;
  final HotspotService _hotspotService;
  final NotificationService _notificationService;

  StreamSubscription<WebSocketMessage>? _messageSubscription;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  CommandDispatcherService({
    required CommunicationService communicationService,
    required SMSService smsService,
    required CallService callService,
    required HotspotService hotspotService,
    required NotificationService notificationService,
  })  : _communicationService = communicationService,
        _smsService = smsService,
        _callService = callService,
        _hotspotService = hotspotService,
        _notificationService = notificationService;

  /// Start listening for commands. Only runs on Android.
  void initialize() {
    if (!Platform.isAndroid) return;

    _messageSubscription?.cancel();
    _messageSubscription =
        _communicationService.messageStream.listen(_handleMessage);
  }

  void _handleMessage(WebSocketMessage message) {
    if (message.type != MessageType.command) return;
    _dispatchCommand(message);
  }

  Future<void> _dispatchCommand(WebSocketMessage message) async {
    final payload = message.payload;
    final action = payload['action'] as String? ?? '';

    bool success = false;
    String? error;
    Map<String, dynamic>? responseData;

    try {
      switch (action) {
        case 'SEND_SMS':
          final phoneNumber = payload['phoneNumber'] as String? ?? '';
          final body = payload['message'] as String? ?? '';
          if (phoneNumber.isEmpty || body.isEmpty) {
            error = 'Missing phoneNumber or message';
            break;
          }
          success = await _smsService.sendSMS(phoneNumber, body);
          if (!success) error = 'sendSMS returned false';
          break;

        case 'CALL_CONTROL':
          final control = payload['control'] as String? ?? '';
          switch (control) {
            case 'ANSWER':
              success = await _callService.answerCall();
              break;
            case 'END':
              success = await _callService.endCall();
              break;
            case 'SPEAKER_ON':
              await _callService.setSpeakerphone(true);
              success = true;
              break;
            case 'SPEAKER_OFF':
              await _callService.setSpeakerphone(false);
              success = true;
              break;
            case 'MUTE':
              await _callService.setMuted(true);
              success = true;
              break;
            case 'UNMUTE':
              await _callService.setMuted(false);
              success = true;
              break;
            default:
              error = 'Unknown call control: $control';
          }
          break;

        case 'HOTSPOT_CONTROL':
          final control = payload['control'] as String? ?? '';
          switch (control) {
            case 'START':
              final result = await _hotspotService.startHotspot();
              if (result != null) {
                success = true;
                responseData = {
                  'ssid': result.ssid,
                  'password': result.password,
                };
              } else {
                error = 'Failed to start hotspot';
              }
              break;
            case 'STOP':
              await _hotspotService.stopHotspot();
              success = true;
              break;
            case 'GET_CREDENTIALS':
              final result = await _hotspotService.getCredentials();
              if (result != null) {
                success = true;
                responseData = {
                  'ssid': result.ssid,
                  'password': result.password,
                };
              } else {
                error = 'Hotspot not active or credentials unavailable';
              }
              break;
            default:
              error = 'Unknown hotspot control: $control';
          }
          break;

        case 'MAKE_CALL':
          final phoneNumber = payload['phoneNumber'] as String? ?? '';
          if (phoneNumber.isEmpty) {
            error = 'Missing phoneNumber';
            break;
          }
          success = await _callService.makeCall(phoneNumber);
          if (!success) error = 'Failed to initiate call';
          break;

        case 'SYNC_REQUEST':
          // 1. Calculate today's start timestamp
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

          // 2. Fetch and filter Call Logs (Today only)
          final allCalls = await _callService.loadCallLog(limit: 100); // Fetch enough to cover today
          final todaysCalls = allCalls.where((c) => c.timestamp.millisecondsSinceEpoch >= startOfDay).toList();
          final callsJson = todaysCalls.map((c) => {
            'id': c.id,
            'number': c.number,
            'name': c.name,
            'type': c.type.value,
            'timestamp': c.timestamp.millisecondsSinceEpoch,
            'duration': c.durationSeconds,
          }).toList();

          // 3. Fetch and filter SMS Threads (Today only)
          final allThreads = await _smsService.loadThreads();
          final todaysThreads = allThreads.where((t) => t.timestamp.millisecondsSinceEpoch >= startOfDay).toList();
          final threadsJson = todaysThreads.map((t) => {
            'threadId': t.threadId,
            'address': t.address,
            'messageCount': t.messageCount,
            'snippet': t.snippet,
            'timestamp': t.timestamp.millisecondsSinceEpoch,
            'contactName': t.contactName,
          }).toList();

          // 4. Trigger Active Notification Sync (Fire and forget, handled via events)
          _notificationService.syncActiveNotifications();

          // 5. Build response
          success = true;
          responseData = {
            'calls': callsJson,
            'sms_threads': threadsJson,
          };
          break;

        default:
          error = 'Unknown command action: $action';
      }
    } catch (e) {
      error = 'Exception executing $action: $e';
      success = false;
    }

    // Send response back to iOS
    _sendResponse(message.id, action, success, error, responseData);
  }

  void _sendResponse(String requestId, String action, bool success,
      String? error, Map<String, dynamic>? responseData) {
    final response = WebSocketMessage.create(
      type: MessageType.response,
      payload: {
        'requestId': requestId,
        'action': action,
        'success': success,
        if (error != null) 'error': error,
        if (responseData != null) ...responseData,
      },
    );

    _communicationService.send(response).catchError((e) {
      _errorController.add('Failed to send response for $action: $e');
      return false;
    });
  }

  void dispose() {
    _messageSubscription?.cancel();
    _errorController.close();
  }
}
