import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Service to manage Android foreground service and app lifecycle
/// for background persistence.
class BackgroundService {
  static const _channel = MethodChannel('com.bridge.phone/background');

  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Start the background service (Android only)
  Future<bool> startService() async {
    if (!Platform.isAndroid) return true; // iOS uses background modes

    try {
      final result = await _channel.invokeMethod<bool>('startService');
      _isRunning = result ?? false;
      return _isRunning;
    } on PlatformException catch (e) {
      print('Failed to start background service: ${e.message}');
      return false;
    }
  }

  /// Stop the background service (Android only)
  Future<bool> stopService() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('stopService');
      _isRunning = !(result ?? true);
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to stop background service: ${e.message}');
      return false;
    }
  }

  /// Check if service is running (Android only)
  Future<bool> checkServiceRunning() async {
    if (!Platform.isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('isServiceRunning');
      _isRunning = result ?? false;
      return _isRunning;
    } on PlatformException catch (e) {
      print('Failed to check service status: ${e.message}');
      return false;
    }
  }
}
