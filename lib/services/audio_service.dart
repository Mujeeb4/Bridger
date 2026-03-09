import 'dart:async';

import 'package:flutter/services.dart';
import 'encryption_service.dart';

/// Service for managing real-time audio streaming.
///
/// Audio capture + send + receive + playback is handled ENTIRELY in native code
/// (Swift on iOS, Kotlin on Android) for minimum latency.
/// This Dart layer only controls start/stop and passes the encryption key.
class AudioService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.bridge.phone/audio');
  static const EventChannel _eventChannel =
      EventChannel('com.bridge.phone/audio_events');

  final EncryptionService? _encryptionService;
  StreamSubscription? _monitorSubscription;
  bool _isStreaming = false;

  AudioService({
    EncryptionService? encryptionService,
  }) : _encryptionService = encryptionService;

  bool get isStreaming => _isStreaming;

  /// Start bidirectional audio streaming.
  ///
  /// 1. Pushes the AES-256 encryption key to native for end-to-end encrypted audio.
  /// 2. Tells native to start capture → encrypt → WebSocket send (outgoing)
  ///    and WebSocket receive → decrypt → playback (incoming).
  /// 3. Optionally monitors the EventChannel for UI updates (non-critical).
  Future<void> startAudioSession() async {
    if (_isStreaming) return;

    try {
      // 1. Push encryption key to native layer for AES-256-GCM audio encryption
      await _pushEncryptionKeyToNative();

      // 2. Start Native Audio (Capture + Playback + WebSocket send/receive)
      // All audio flows natively — no Dart bounce
      await _methodChannel.invokeMethod('startStreaming');

      // 3. Optional: monitor audio events for UI (volume meters, etc.)
      // This does NOT send audio — native already does that.
      _monitorSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleAudioMonitorData,
        onError: (e) {
          print('Audio monitor stream error: $e');
        },
      );

      _isStreaming = true;
    } catch (e) {
      print('Failed to start audio session: $e');
      _monitorSubscription?.cancel();
      _monitorSubscription = null;
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

    _monitorSubscription?.cancel();
    _monitorSubscription = null;
    _isStreaming = false;
  }

  /// Push the AES-256 encryption key from secure storage to the native layer.
  /// Both iOS and Android use this key for AES-GCM audio encryption/decryption.
  Future<void> _pushEncryptionKeyToNative() async {
    if (_encryptionService == null || !_encryptionService.isInitialized) return;

    try {
      final keyBytes = await _encryptionService.exportKey();
      if (keyBytes != null && keyBytes.length == 32) {
        await _methodChannel.invokeMethod('setEncryptionKey', keyBytes);
        print(
            '[AudioService] Encryption key pushed to native (${keyBytes.length} bytes)');
      }
    } catch (e) {
      print('[AudioService] Failed to push encryption key: $e');
      // Audio will still work, just unencrypted
    }
  }

  /// Clear encryption key from native layer (on unpair)
  Future<void> clearNativeEncryptionKey() async {
    try {
      await _methodChannel.invokeMethod('clearEncryptionKey');
    } catch (e) {
      print('[AudioService] Failed to clear encryption key: $e');
    }
  }

  /// Handle audio data from native — used only for UI monitoring (volume meters, etc.)
  /// Audio is NOT re-sent to WebSocket from here. Native handles that directly.
  void _handleAudioMonitorData(dynamic data) {
    // Available for UI components that need audio level data
    // e.g., call screen volume indicator
  }

  void dispose() {
    stopAudioSession();
  }
}
