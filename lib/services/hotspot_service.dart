import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/models/hotspot_models.dart';

/// Service for managing Wi-Fi hotspot functionality
/// - Android: Creates local-only hotspot and shares credentials
/// - iOS: Connects to Android's hotspot using received credentials
class HotspotService {
  static const MethodChannel _methodChannel = MethodChannel('com.bridge.phone/hotspot');
  static const EventChannel _eventChannel = EventChannel('com.bridge.phone/hotspot_events');

  Stream<HotspotEvent>? _eventStream;

  // Current state
  HotspotState _state = HotspotState.idle;
  HotspotState get state => _state;

  // Credentials (Android: generated, iOS: received)
  HotspotCredentials? _credentials;
  HotspotCredentials? get credentials => _credentials;

  // Stream controllers
  final _stateController = StreamController<HotspotState>.broadcast();
  Stream<HotspotState> get stateStream => _stateController.stream;

  final _credentialsController = StreamController<HotspotCredentials>.broadcast();
  Stream<HotspotCredentials> get credentialsStream => _credentialsController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  // Platform checks
  bool get isAndroid => Platform.isAndroid;
  bool get isIOS => Platform.isIOS;

  // ============================================================================
  // Initialization
  // ============================================================================

  /// Initialize hotspot service
  Future<bool> initialize() async {
    try {
      final supported = await _methodChannel.invokeMethod<bool>('isSupported') ?? false;
      if (supported) {
        _subscribeToEvents();
      }
      return supported;
    } on PlatformException catch (e) {
      _errorController.add('Failed to initialize: ${e.message}');
      return false;
    }
  }

  void _subscribeToEvents() {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => HotspotEvent.fromMap(event as Map<dynamic, dynamic>));

    _eventStream!.listen(_handleEvent);
  }

  void _handleEvent(HotspotEvent event) {
    switch (event.type) {
      case HotspotEventType.started:
        _state = HotspotState.active;
        final ssid = event.data['ssid'] as String?;
        final password = event.data['password'] as String?;
        if (ssid != null && password != null) {
          _credentials = HotspotCredentials(ssid: ssid, password: password);
          _credentialsController.add(_credentials!);
        }
        break;

      case HotspotEventType.stopped:
        _state = HotspotState.idle;
        _credentials = null;
        break;

      case HotspotEventType.connectionInitiated:
        _state = HotspotState.connecting;
        break;

      case HotspotEventType.connected:
        _state = HotspotState.connected;
        break;

      case HotspotEventType.disconnected:
        _state = HotspotState.idle;
        break;

      case HotspotEventType.error:
        _state = HotspotState.error;
        final message = event.data['message'] as String? ?? 'Unknown error';
        _errorController.add(message);
        break;
    }

    _stateController.add(_state);
  }

  // ============================================================================
  // Android: Hotspot Control
  // ============================================================================

  /// Start local-only hotspot (Android only)
  Future<HotspotCredentials?> startHotspot() async {
    if (!isAndroid) return null;

    try {
      _updateState(HotspotState.starting);
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('startHotspot');
      
      if (result != null) {
        final ssid = result['ssid'] as String?;
        final password = result['password'] as String?;
        
        if (ssid != null && password != null) {
          _credentials = HotspotCredentials(ssid: ssid, password: password);
          _updateState(HotspotState.active);
          _credentialsController.add(_credentials!);
          return _credentials;
        }
      }
      
      _updateState(HotspotState.error);
      return null;
    } on PlatformException catch (e) {
      _errorController.add('Failed to start hotspot: ${e.message}');
      _updateState(HotspotState.error);
      return null;
    }
  }

  /// Stop local-only hotspot (Android only)
  Future<void> stopHotspot() async {
    if (!isAndroid) return;

    try {
      _updateState(HotspotState.stopping);
      await _methodChannel.invokeMethod('stopHotspot');
      _credentials = null;
      _updateState(HotspotState.idle);
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop hotspot: ${e.message}');
      _updateState(HotspotState.error);
    }
  }

  /// Get current hotspot credentials (Android only)
  Future<HotspotCredentials?> getCredentials() async {
    if (!isAndroid) return _credentials;

    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getCredentials');
      
      if (result != null) {
        final ssid = result['ssid'] as String?;
        final password = result['password'] as String?;
        
        if (ssid != null && password != null) {
          _credentials = HotspotCredentials(ssid: ssid, password: password);
          return _credentials;
        }
      }
      return null;
    } on PlatformException {
      return null;
    }
  }

  // ============================================================================
  // iOS: Connect to Android Hotspot
  // ============================================================================

  /// Connect to Android hotspot using credentials (iOS only)
  Future<bool> connectToHotspot(HotspotCredentials credentials) async {
    if (!isIOS) return false;

    try {
      _credentials = credentials;
      _updateState(HotspotState.connecting);
      
      final success = await _methodChannel.invokeMethod<bool>('connectToHotspot', {
        'ssid': credentials.ssid,
        'password': credentials.password,
      }) ?? false;

      if (success) {
        _updateState(HotspotState.connected);
      } else {
        _updateState(HotspotState.error);
      }
      return success;
    } on PlatformException catch (e) {
      _errorController.add('Failed to connect: ${e.message}');
      _updateState(HotspotState.error);
      return false;
    }
  }

  /// Disconnect from hotspot (iOS only)
  Future<void> disconnectFromHotspot() async {
    if (!isIOS) return;

    try {
      await _methodChannel.invokeMethod('disconnectFromHotspot');
      _updateState(HotspotState.idle);
    } on PlatformException catch (e) {
      _errorController.add('Failed to disconnect: ${e.message}');
    }
  }

  // ============================================================================
  // Common
  // ============================================================================

  /// Check if hotspot is active (Android) or connected (iOS)
  Future<bool> isActive() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isActive') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if hotspot feature is supported on this device
  Future<bool> isSupported() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    }
  }

  void _updateState(HotspotState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    _stateController.close();
    _credentialsController.close();
    _errorController.close();
  }
}
