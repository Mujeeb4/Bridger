import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'websocket_service.dart';

/// Service for managing real-time audio streaming
class AudioService {
  static const MethodChannel _methodChannel = MethodChannel('com.bridge.phone/audio');
  static const EventChannel _eventChannel = EventChannel('com.bridge.phone/audio_events');
  
  // Protocol byte for Audio packets
  static const int _audioProtocolId = 0x01;

  final WebSocketService _webSocketService;
  StreamSubscription? _audioSubscription;
  bool _isStreaming = false;

  AudioService({required WebSocketService webSocketService}) 
      : _webSocketService = webSocketService;

  bool get isStreaming => _isStreaming;

  /// Start bidirectional audio streaming
  Future<void> startAudioSession() async {
    if (_isStreaming) return;

    try {
      // 1. Subscribe to Native Mic Stream
      _audioSubscription = _eventChannel.receiveBroadcastStream().listen(_handleNativeAudioData, onError: (e) {
        print('Audio Stream Error: $e');
      });

      // 2. Start Native Audio (Capture & Playback)
      await _methodChannel.invokeMethod('startStreaming');
      
      _isStreaming = true;
    } catch (e) {
      print('Failed to start audio session: $e');
      _audioSubscription?.cancel();
      _audioSubscription = null;
    }
  }

  /// Stop audio streaming
  Future<void> stopAudioSession() async {
    if (!_isStreaming) return;

    try {
      await _methodChannel.invokeMethod('stopStreaming');
    } catch (e) {
      print('Error stopping native stream: $e');
    }

    _audioSubscription?.cancel();
    _audioSubscription = null;
    _isStreaming = false;
  }

  /// Handle raw PCM bytes from Native Mic
  void _handleNativeAudioData(dynamic data) {
    if (data is Uint8List) {
      // Create packet: [Protocol ID] + [PCM Data]
      final packet = Uint8List(data.length + 1);
      packet[0] = _audioProtocolId;
      packet.setRange(1, packet.length, data);

      // Send via WebSocket (Binary Frame)
      _webSocketService.sendBinary(packet);
    }
  }

  void dispose() {
    stopAudioSession();
  }
}
