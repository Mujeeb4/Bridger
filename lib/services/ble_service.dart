import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/models/ble_models.dart';

/// Service for managing BLE functionality
/// - Android: Acts as BLE Peripheral (GATT Server) - Advertises and accepts connections
/// - iOS: Acts as BLE Central - Scans for and connects to Android peripheral
class BleService {
  static const MethodChannel _methodChannel = MethodChannel('com.bridge.phone/ble');
  static const EventChannel _eventChannel = EventChannel('com.bridge.phone/ble_events');

  /// Stream of BLE events from native layer
  Stream<BleEvent>? _eventStream;
  
  /// Current connection state
  BleConnectionState _connectionState = BleConnectionState.idle;
  BleConnectionState get connectionState => _connectionState;

  /// Connected devices (Android) or connected device ID (iOS)
  final List<BleDevice> _connectedDevices = [];
  List<BleDevice> get connectedDevices => List.unmodifiable(_connectedDevices);
  
  /// Discovered devices (iOS only)
  final List<ScannedDevice> _discoveredDevices = [];
  List<ScannedDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  /// Stream controllers
  final _connectionStateController = StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;

  final _commandController = StreamController<BleCommand>.broadcast();
  Stream<BleCommand> get commandStream => _commandController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;
  
  /// iOS-specific: Discovered devices stream
  final _discoveredDevicesController = StreamController<ScannedDevice>.broadcast();
  Stream<ScannedDevice> get discoveredDevicesStream => _discoveredDevicesController.stream;
  
  /// iOS-specific: Received alerts streams
  final _smsAlertController = StreamController<String>.broadcast();
  Stream<String> get smsAlertStream => _smsAlertController.stream;
  
  final _callAlertController = StreamController<String>.broadcast();
  Stream<String> get callAlertStream => _callAlertController.stream;
  
  final _appNotificationController = StreamController<String>.broadcast();
  Stream<String> get appNotificationStream => _appNotificationController.stream;

  /// Current MTU size
  int _mtu = 23;
  int get mtu => _mtu;
  
  /// Platform check
  bool get isAndroid => Platform.isAndroid;
  bool get isIOS => Platform.isIOS;

  // ============================================================================
  // Initialization
  // ============================================================================

  /// Initialize BLE
  /// Returns true if successful
  Future<bool> initialize() async {
    try {
      final success = await _methodChannel.invokeMethod<bool>('initialize') ?? false;
      
      if (success) {
        _subscribeToEvents();
      }
      
      return success;
    } on PlatformException catch (e) {
      _errorController.add('Failed to initialize BLE: ${e.message}');
      return false;
    }
  }

  void _subscribeToEvents() {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => BleEvent.fromMap(event as Map<dynamic, dynamic>));

    _eventStream!.listen(_handleEvent);
  }

  void _handleEvent(BleEvent event) {
    switch (event.type) {
      case BleEventType.statusChanged:
        final status = event.data['status'] as String? ?? '';
        _connectionState = BleConnectionStateExtension.fromString(status);
        _connectionStateController.add(_connectionState);
        break;

      case BleEventType.deviceConnected:
        final device = BleDevice(
          address: event.data['address'] as String? ?? '',
          name: event.data['name'] as String? ?? 'Unknown',
          connectedAt: event.timestamp,
        );
        _connectedDevices.add(device);
        break;

      case BleEventType.deviceDisconnected:
        final address = event.data['address'] as String? ?? '';
        _connectedDevices.removeWhere((d) => d.address == address);
        break;

      case BleEventType.commandReceived:
        final commandJson = event.data['command'] as String? ?? '{}';
        try {
          final json = jsonDecode(commandJson) as Map<String, dynamic>;
          final command = BleCommand.fromJson(json);
          _commandController.add(command);
        } catch (e) {
          _errorController.add('Failed to parse command: $e');
        }
        break;

      case BleEventType.error:
        final message = event.data['message'] as String? ?? 'Unknown error';
        _errorController.add(message);
        break;

      case BleEventType.mtuChanged:
        _mtu = event.data['mtu'] as int? ?? 23;
        break;
        
      case BleEventType.deviceDiscovered:
        final device = ScannedDevice(
          id: event.data['id'] as String? ?? '',
          name: event.data['name'] as String? ?? 'Unknown',
          rssi: event.data['rssi'] as int? ?? 0,
        );
        _discoveredDevices.add(device);
        _discoveredDevicesController.add(device);
        break;
        
      case BleEventType.smsAlert:
        final data = event.data['data'] as String? ?? '';
        _smsAlertController.add(data);
        break;
        
      case BleEventType.callAlert:
        final data = event.data['data'] as String? ?? '';
        _callAlertController.add(data);
        break;
        
      case BleEventType.appNotification:
        final data = event.data['data'] as String? ?? '';
        _appNotificationController.add(data);
        break;
    }
  }

  // ============================================================================
  // Android-only: Advertising (Peripheral Mode)
  // ============================================================================

  /// Start BLE advertising (Android only)
  Future<void> startAdvertising() async {
    if (!isAndroid) return;
    
    try {
      await _methodChannel.invokeMethod('startAdvertising');
    } on PlatformException catch (e) {
      _errorController.add('Failed to start advertising: ${e.message}');
    }
  }

  /// Stop BLE advertising (Android only)
  Future<void> stopAdvertising() async {
    if (!isAndroid) return;
    
    try {
      await _methodChannel.invokeMethod('stopAdvertising');
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop advertising: ${e.message}');
    }
  }

  /// Check if currently advertising (Android only)
  Future<bool> isAdvertising() async {
    if (!isAndroid) return false;
    
    try {
      return await _methodChannel.invokeMethod<bool>('isAdvertising') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ============================================================================
  // iOS-only: Scanning and Connection (Central Mode)
  // ============================================================================

  /// Start scanning for devices (iOS only)
  Future<void> startScanning() async {
    if (!isIOS) return;
    
    try {
      _discoveredDevices.clear();
      await _methodChannel.invokeMethod('startScanning');
    } on PlatformException catch (e) {
      _errorController.add('Failed to start scanning: ${e.message}');
    }
  }

  /// Stop scanning (iOS only)
  Future<void> stopScanning() async {
    if (!isIOS) return;
    
    try {
      await _methodChannel.invokeMethod('stopScanning');
    } on PlatformException catch (e) {
      _errorController.add('Failed to stop scanning: ${e.message}');
    }
  }

  /// Connect to a device by ID (iOS only)
  Future<void> connect(String deviceId) async {
    if (!isIOS) return;
    
    try {
      await _methodChannel.invokeMethod('connect', {'deviceId': deviceId});
    } on PlatformException catch (e) {
      _errorController.add('Failed to connect: ${e.message}');
    }
  }

  /// Disconnect from current device (iOS only)
  Future<void> disconnect() async {
    if (!isIOS) return;
    
    try {
      await _methodChannel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      _errorController.add('Failed to disconnect: ${e.message}');
    }
  }
  
  /// Send SMS via Android (iOS only)
  Future<bool> sendSmsViaAndroid(String to, String body) async {
    if (!isIOS) return false;
    
    try {
      return await _methodChannel.invokeMethod<bool>('sendSMS', {
        'to': to,
        'body': body,
      }) ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send SMS: ${e.message}');
      return false;
    }
  }
  
  /// Make call via Android (iOS only)
  Future<bool> makeCallViaAndroid(String phoneNumber) async {
    if (!isIOS) return false;
    
    try {
      return await _methodChannel.invokeMethod<bool>('makeCall', {
        'phoneNumber': phoneNumber,
      }) ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to make call: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // Common: Connection State
  // ============================================================================

  /// Check if any device is connected
  Future<bool> isConnected() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isConnected') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Get list of connected device addresses (Android) or single device ID (iOS)
  Future<List<String>> getConnectedDeviceAddresses() async {
    try {
      if (isIOS) {
        final deviceId = await _methodChannel.invokeMethod<String>('getConnectedDeviceId');
        return deviceId != null ? [deviceId] : [];
      }
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getConnectedDevices');
      return result?.cast<String>() ?? [];
    } on PlatformException {
      return [];
    }
  }

  // ============================================================================
  // Android-only: Send Alerts to iPhone
  // ============================================================================

  /// Send SMS alert to connected device (Android only)
  Future<bool> sendSmsAlert(SmsAlertData data) async {
    if (!isAndroid) return false;
    
    try {
      final json = jsonEncode(data.toJson());
      return await _methodChannel.invokeMethod<bool>('sendSmsAlert', {'data': json}) ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send SMS alert: ${e.message}');
      return false;
    }
  }

  /// Send call alert to connected device (Android only)
  Future<bool> sendCallAlert(CallAlertData data) async {
    if (!isAndroid) return false;
    
    try {
      final json = jsonEncode(data.toJson());
      return await _methodChannel.invokeMethod<bool>('sendCallAlert', {'data': json}) ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send call alert: ${e.message}');
      return false;
    }
  }

  /// Send app notification to connected device (Android only)
  Future<bool> sendAppNotification(AppNotificationData data) async {
    if (!isAndroid) return false;
    
    try {
      final json = jsonEncode(data.toJson());
      return await _methodChannel.invokeMethod<bool>('sendAppNotification', {'data': json}) ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send app notification: ${e.message}');
      return false;
    }
  }

  /// Send bulk data
  Future<bool> sendBulkData(List<int> data) async {
    try {
      return await _methodChannel.invokeMethod<bool>('sendBulkData', {
        'data': Uint8List.fromList(data),
      }) ?? false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send bulk data: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Shutdown BLE and cleanup resources
  Future<void> shutdown() async {
    try {
      await _methodChannel.invokeMethod('shutdown');
    } on PlatformException catch (e) {
      _errorController.add('Failed to shutdown BLE: ${e.message}');
    }
  }

  /// Dispose of resources
  void dispose() {
    _connectionStateController.close();
    _commandController.close();
    _errorController.close();
    _discoveredDevicesController.close();
    _smsAlertController.close();
    _callAlertController.close();
    _appNotificationController.close();
  }
}
