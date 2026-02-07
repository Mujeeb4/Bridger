import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/models/call_models.dart';
import '../data/models/websocket_models.dart';
import '../data/models/call_models.dart';
import '../data/models/websocket_models.dart';
import 'communication_service.dart';
import 'audio_service.dart';

/// Service for call operations
/// - Android: Detect calls, read call log, control calls
/// - iOS: Show CallKit UI, relay controls to Android
class CallService {
  static const MethodChannel _methodChannel = MethodChannel('com.bridge.phone/call');
  static const EventChannel _eventChannel = EventChannel('com.bridge.phone/call_events');

  final CommunicationService? _communicationService;
  final AudioService? _audioService;

  Stream<CallEvent>? _eventStream;

  // Current call state
  CallInfo? _activeCall;
  CallInfo? get activeCall => _activeCall;

  // Cached call log
  List<CallLogEntry> _callLog = [];
  List<CallLogEntry> get callLog => List.unmodifiable(_callLog);

  // Stream controllers
  final _callStateController = StreamController<CallInfo?>.broadcast();
  Stream<CallInfo?> get callStateStream => _callStateController.stream;

  final _callLogController = StreamController<List<CallLogEntry>>.broadcast();
  Stream<List<CallLogEntry>> get callLogStream => _callLogController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  // Platform checks
  bool get isAndroid => Platform.isAndroid;
  bool get isIOS => Platform.isIOS;

  CallService({
    CommunicationService? communicationService,
    AudioService? audioService,
  })  : _communicationService = communicationService,
        _audioService = audioService;

  // ============================================================================
  // Initialization
  // ============================================================================

  Future<void> initialize() async {
    _subscribeToEvents();

    // Listen for call events from communication service (iOS)
    if (isIOS && _communicationService != null) {
      _communicationService!.messageStream.listen((wsMessage) {
        if (wsMessage.type == MessageType.callAlert) {
          _handleRemoteCallEvent(wsMessage.payload);
        }
      });
    }
  }

  void _subscribeToEvents() {
    if (!isAndroid) return;

    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => CallEvent.fromMap(event as Map<dynamic, dynamic>));

    _eventStream!.listen(_handleEvent);
  }

  void _handleEvent(CallEvent event) {
    final phoneNumber = event.data['phoneNumber'] as String? ?? '';

    switch (event.type) {
      case CallEventType.incoming:
        _activeCall = CallInfo(
          phoneNumber: phoneNumber,
          type: CallType.incoming,
          state: CallState.ringing,
          startTime: DateTime.now(),
        );
        _callStateController.add(_activeCall);
        // Forward to iOS
        _forwardCallEventToIOS('incomingCall', {'phoneNumber': phoneNumber});
        break;

      case CallEventType.outgoing:
        _activeCall = CallInfo(
          phoneNumber: phoneNumber,
          type: CallType.outgoing,
          state: CallState.active,
          startTime: DateTime.now(),
        );
        _callStateController.add(_activeCall);
        break;

      case CallEventType.answered:
        if (_activeCall != null) {
          _activeCall = _activeCall!.copyWith(
            state: CallState.active,
            startTime: DateTime.now(),
          );
          _callStateController.add(_activeCall);
          
          // Forward to iOS
          _forwardCallEventToIOS('callAnswered', {'phoneNumber': phoneNumber});
          
          // Start Audio Streaming
          _audioService?.startAudioSession();
        }
        break;

      case CallEventType.ended:
      case CallEventType.missed:
        _activeCall = null;
        _activeCall = null;
        _callStateController.add(null);
        _forwardCallEventToIOS('callEnded', {'phoneNumber': phoneNumber});
        
        // Stop Audio Streaming
        _audioService?.stopAudioSession();
        
        // Refresh call log
        loadCallLog();
        break;
    }
  }

  void _handleRemoteCallEvent(Map<String, dynamic> payload) {
    final action = payload['action'] as String?;
    final phoneNumber = payload['phoneNumber'] as String? ?? '';

    switch (action) {
      case 'INCOMING':
        _activeCall = CallInfo(
          phoneNumber: phoneNumber,
          type: CallType.incoming,
          state: CallState.ringing,
          startTime: DateTime.now(),
        );
        _callStateController.add(_activeCall);
        // Trigger CallKit on iOS
        _showCallKitUI(phoneNumber);
        _showCallKitUI(phoneNumber);
        break;

      case 'ANSWERED':
        if (_activeCall != null) {
          _activeCall = _activeCall!.copyWith(
            state: CallState.active,
            startTime: DateTime.now(),
          );
          _callStateController.add(_activeCall);
          
          // Start Audio Streaming
          _audioService?.startAudioSession();
        }
        break;

      case 'ENDED':
        _activeCall = null;
        _callStateController.add(null);
        _endCallKitUI();
        
        // Stop Audio Streaming
        _audioService?.stopAudioSession();
        break;
    }
  }

  Future<void> _forwardCallEventToIOS(String eventType, Map<String, dynamic> data) async {
    if (_communicationService == null) return;

    final wsMessage = WebSocketMessage.create(
      type: MessageType.callAlert,
      payload: {
        'action': eventType.toUpperCase().replaceAll('CALL', ''),
        ...data,
      },
    );

    await _communicationService!.send(wsMessage);
  }

  // ============================================================================
  // iOS CallKit
  // ============================================================================

  Future<void> _showCallKitUI(String phoneNumber) async {
    if (!isIOS) return;

    try {
      await _methodChannel.invokeMethod('reportIncomingCall', {
        'phoneNumber': phoneNumber,
      });
    } on PlatformException catch (e) {
      _errorController.add('CallKit error: ${e.message}');
    }
  }

  Future<void> _endCallKitUI() async {
    if (!isIOS) return;

    try {
      await _methodChannel.invokeMethod('endCall');
    } on PlatformException {
      // Ignore
    }
  }

  // ============================================================================
  // Call Log
  // ============================================================================

  /// Load call log
  Future<List<CallLogEntry>> loadCallLog({int limit = 100}) async {
    if (!isAndroid) return _callLog;

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getCallLog', {
        'limit': limit,
      });

      if (result != null) {
        _callLog = result
            .cast<Map<dynamic, dynamic>>()
            .map((e) => CallLogEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _callLogController.add(_callLog);
      }
      return _callLog;
    } on PlatformException catch (e) {
      _errorController.add('Failed to load call log: ${e.message}');
      return [];
    }
  }

  // ============================================================================
  // Call Controls
  // ============================================================================

  /// Answer incoming call
  Future<bool> answerCall() async {
    if (isAndroid) {
      return _answerCallAndroid();
    } else if (isIOS) {
      return _sendCallControlToAndroid('ANSWER');
    }
    return false;
  }

  /// End/reject current call
  Future<bool> endCall() async {
    if (isAndroid) {
      return _endCallAndroid();
    } else if (isIOS) {
      return _sendCallControlToAndroid('END');
    }
    return false;
  }

  /// Toggle speakerphone
  Future<void> setSpeakerphone(bool enabled) async {
    if (isAndroid) {
      await _methodChannel.invokeMethod('setSpeakerphone', {'enabled': enabled});
    } else if (isIOS) {
      await _sendCallControlToAndroid(enabled ? 'SPEAKER_ON' : 'SPEAKER_OFF');
    }

    if (_activeCall != null) {
      _activeCall = _activeCall!.copyWith(isSpeakerOn: enabled);
      _callStateController.add(_activeCall);
    }
  }

  /// Toggle mute
  Future<void> setMuted(bool muted) async {
    if (isAndroid) {
      await _methodChannel.invokeMethod('setMuted', {'muted': muted});
    } else if (isIOS) {
      await _sendCallControlToAndroid(muted ? 'MUTE' : 'UNMUTE');
    }

    if (_activeCall != null) {
      _activeCall = _activeCall!.copyWith(isMuted: muted);
      _callStateController.add(_activeCall);
    }
  }

  Future<bool> _answerCallAndroid() async {
    try {
      return await _methodChannel.invokeMethod<bool>('answerCall') ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to answer call: ${e.message}');
      return false;
    }
  }

  Future<bool> _endCallAndroid() async {
    try {
      return await _methodChannel.invokeMethod<bool>('endCall') ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to end call: ${e.message}');
      return false;
    }
  }

  Future<bool> _sendCallControlToAndroid(String action) async {
    if (_communicationService == null || !_communicationService!.isConnected) {
      _errorController.add('Not connected to Android device');
      return false;
    }

    final wsMessage = WebSocketMessage.create(
      type: MessageType.command,
      payload: {
        'action': 'CALL_CONTROL',
        'control': action,
      },
    );

    return await _communicationService!.send(wsMessage);
  }

  /// Check if there's an active call
  bool get hasActiveCall => _activeCall != null;

  void dispose() {
    _callStateController.close();
    _callLogController.close();
    _errorController.close();
  }
}
