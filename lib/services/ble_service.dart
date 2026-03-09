import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models/ble_models.dart';
import '../data/models/websocket_models.dart';

/// Service for managing BLE functionality
/// - Android: Acts as BLE Peripheral (GATT Server) - Advertises and accepts connections
/// - iOS: Acts as BLE Central - Scans for and connects to Android peripheral
class BleService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.bridge.phone/ble');
  static const EventChannel _eventChannel =
      EventChannel('com.bridge.phone/ble_events');

  /// Stream of BLE events from native layer
  Stream<BleEvent>? _eventStream;

  /// Current connection state
  BleConnectionState _connectionState = BleConnectionState.idle;
  BleConnectionState get connectionState => _connectionState;

  /// Connected devices (Android) or connected device ID (iOS)
  final List<BleDevice> _connectedDevices = [];
  List<BleDevice> get connectedDevices => List.unmodifiable(_connectedDevices);

  /// iOS: ID of the currently connected peripheral
  String? _connectedDeviceId;
  String? get connectedDeviceId => _connectedDeviceId;

  /// Discovered devices (iOS only)
  final List<ScannedDevice> _discoveredDevices = [];
  List<ScannedDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  /// Stream controllers
  final _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  final _commandController = StreamController<BleCommand>.broadcast();
  Stream<BleCommand> get commandStream => _commandController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  /// iOS-specific: Discovered devices stream
  final _discoveredDevicesController =
      StreamController<ScannedDevice>.broadcast();
  Stream<ScannedDevice> get discoveredDevicesStream =>
      _discoveredDevicesController.stream;

  /// iOS-specific: Received alerts streams
  final _smsAlertController = StreamController<String>.broadcast();
  Stream<String> get smsAlertStream => _smsAlertController.stream;

  final _callAlertController = StreamController<String>.broadcast();
  Stream<String> get callAlertStream => _callAlertController.stream;

  final _appNotificationController = StreamController<String>.broadcast();
  Stream<String> get appNotificationStream => _appNotificationController.stream;

  /// Pairing response stream (from Android via status/bulk notifications)
  final _pairingResponseController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get pairingResponseStream =>
      _pairingResponseController.stream;

  /// Parsed WebSocketMessage objects from BLE bulk data (e.g. SYNC_REQUEST response)
  final _bulkMessageController =
      StreamController<WebSocketMessage>.broadcast();
  Stream<WebSocketMessage> get bulkMessageStream =>
      _bulkMessageController.stream;

  /// Services Ready stream (iOS only)
  final _servicesReadyController = StreamController<void>.broadcast();
  Stream<void> get servicesReadyStream => _servicesReadyController.stream;

  /// Track if services are ready (iOS only)
  bool _areServicesReady = false;
  bool get areServicesReady => _areServicesReady;

  /// Current MTU size
  int _mtu = 23;
  int get mtu => _mtu;

  /// Prevent duplicate event subscriptions
  bool _eventsSubscribed = false;

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
      final success =
          await _methodChannel.invokeMethod<bool>('initialize') ?? false;

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
    if (_eventsSubscribed) return;
    _eventsSubscribed = true;

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
        final address = event.data['address'] as String? ?? '';
        final device = BleDevice(
          address: address,
          name: event.data['name'] as String? ?? 'Unknown',
          connectedAt: event.timestamp,
        );
        _connectedDevices.add(device);
        _connectedDeviceId = address;
        // Explicitly set state to connected when a device connects
        _connectionState = BleConnectionState.connected;
        _connectionStateController.add(_connectionState);
        break;

      case BleEventType.deviceDisconnected:
        final address = event.data['address'] as String? ?? '';
        _connectedDevices.removeWhere((d) => d.address == address);
        if (_connectedDeviceId == address) {
          _connectedDeviceId = null;
          _areServicesReady = false;
        }
        // Update connection state so CommunicationService and UI see the disconnect
        if (_connectedDevices.isEmpty) {
          _connectionState = BleConnectionState.disconnected;
          _connectionStateController.add(_connectionState);
        }
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

      case BleEventType.servicesReady:
        // iOS: All BLE services discovered and ready for communication
        _connectionState = BleConnectionState.connected;
        _connectionStateController.add(_connectionState);
        _areServicesReady = true;
        _servicesReadyController.add(null);
        debugPrint(
            '[BleService] Services ready — connection state set to CONNECTED');
        break;

      case BleEventType.statusUpdate:
        // Status updates may contain PAIRING_RESPONSE JSON or NATIVE_PAIRING_SUCCESS
        final statusData = event.data['data'] as String? ?? '';
        try {
          final json = jsonDecode(statusData) as Map<String, dynamic>;
          final type = json['type'] as String? ?? '';
          final cmd = json['cmd'] as String? ?? '';
          if (type == 'PAIRING_RESPONSE') {
            _pairingResponseController
                .add(json['data'] as Map<String, dynamic>? ?? json);
          } else if (cmd == 'NATIVE_PAIRING_SUCCESS') {
            // Native layer intercepted pairing and sends success with shared key
            final payload = json['payload'] as Map<String, dynamic>? ?? {};
            _pairingResponseController.add({
              'success': true,
              ...payload,
            });
          }
        } catch (_) {
          // Not JSON or not a pairing response, ignore
        }
        break;

      case BleEventType.pairingResponse:
        final data = event.data['data'] as String? ?? '{}';
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          _pairingResponseController.add(json);
        } catch (e) {
          _errorController.add('Failed to parse pairing response: $e');
        }
        break;

      case BleEventType.bulkData:
        final data = event.data['data'] as String? ?? '';
        // iOS sends bulk data as base64-encoded bytes.
        // Try base64-decode → UTF-8 → JSON → WebSocketMessage first,
        // then fall back to direct JSON parse for pairing responses.
        try {
          final bytes = base64Decode(data);
          final jsonStr = utf8.decode(bytes);
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;

          // Check for pairing response
          final type = json['type'] as String? ?? '';
          if (type == 'PAIRING_RESPONSE') {
            _pairingResponseController
                .add(json['data'] as Map<String, dynamic>? ?? json);
          } else if (json.containsKey('id') && json.containsKey('payload')) {
            // This is a full WebSocketMessage (e.g. SYNC_REQUEST response)
            final wsMessage = WebSocketMessage.fromJson(json);
            _bulkMessageController.add(wsMessage);
          }
        } catch (_) {
          // Fall back: try direct JSON parse (non-base64 data)
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final type = json['type'] as String? ?? '';
            if (type == 'PAIRING_RESPONSE') {
              _pairingResponseController
                  .add(json['data'] as Map<String, dynamic>? ?? json);
            } else if (json.containsKey('id') && json.containsKey('payload')) {
              final wsMessage = WebSocketMessage.fromJson(json);
              _bulkMessageController.add(wsMessage);
            }
          } catch (_) {
            // Not parseable, ignore
          }
        }
        break;

      case BleEventType.log:
        final message = event.data['message'] as String? ?? '';
        debugPrint(message);
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
          }) ??
          false;
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
          }) ??
          false;
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
        final deviceId =
            await _methodChannel.invokeMethod<String>('getConnectedDeviceId');
        return deviceId != null ? [deviceId] : [];
      }
      final result = await _methodChannel
          .invokeMethod<List<dynamic>>('getConnectedDevices');
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
      return await _methodChannel
              .invokeMethod<bool>('sendSmsAlert', {'data': json}) ??
          false;
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
      return await _methodChannel
              .invokeMethod<bool>('sendCallAlert', {'data': json}) ??
          false;
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
      return await _methodChannel
              .invokeMethod<bool>('sendAppNotification', {'data': json}) ??
          false;
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
          }) ??
          false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send bulk data: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // iOS-only: Send Command to Android via CHAR_COMMAND
  // ============================================================================

  /// Send a JSON command to Android via the Command characteristic (iOS only)
  Future<bool> sendCommand(Map<String, dynamic> command) async {
    if (!isIOS) return false;

    try {
      final jsonStr = jsonEncode(command);
      return await _methodChannel.invokeMethod<bool>('sendCommand', {
            'command': jsonStr,
          }) ??
          false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send command: ${e.message}');
      return false;
    }
  }

  /// Trigger service discovery on connected peripheral (iOS only).
  /// Use when connected but services weren't discovered (e.g. Android
  /// registered services after the connection was established).
  Future<void> discoverServices() async {
    if (!isIOS) return;
    try {
      await _methodChannel.invokeMethod('discoverServices');
    } on PlatformException catch (e) {
      _errorController.add('Failed to discover services: ${e.message}');
    }
  }

  /// Check native services-ready state (iOS only).
  /// Useful to sync the cached flag if an event was missed.
  Future<bool> checkNativeServicesReady() async {
    if (!isIOS) return true;
    try {
      final ready =
          await _methodChannel.invokeMethod<bool>('getServicesReady') ?? false;
      if (ready) _areServicesReady = true;
      return ready;
    } on PlatformException {
      return false;
    }
  }

  /// Wait for services to be ready (iOS only).
  /// After connecting, `didConnect` already triggers service discovery.
  /// This method waits for that to complete, and only triggers a
  /// re-discovery if the initial one doesn't finish within a few seconds.
  Future<bool> waitForServicesReady(
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (!isIOS) return true;
    if (_areServicesReady) return true;

    // Check native state in case we missed the event
    final nativeReady = await checkNativeServicesReady();
    if (nativeReady) {
      debugPrint('[BleService] Services already ready (native check)');
      return true;
    }

    debugPrint('[BleService] Waiting for services to be ready...');
    final completer = Completer<bool>();

    final subscription = servicesReadyStream.listen((_) {
      if (!completer.isCompleted) completer.complete(true);
    });

    // Give the initial discovery (triggered by didConnect) a few seconds.
    // Only trigger re-discovery if it hasn't completed by then.
    Timer? rediscoverTimer;
    final connected = await isConnected();
    if (connected) {
      rediscoverTimer = Timer(const Duration(seconds: 4), () async {
        if (!completer.isCompleted) {
          debugPrint(
              '[BleService] Initial discovery incomplete — triggering re-discovery...');
          await discoverServices();
        }
      });
    }

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint('[BleService] waitForServicesReady timed out');
        completer.complete(false);
      }
    });

    final result = await completer.future;
    subscription.cancel();
    timer.cancel();
    rediscoverTimer?.cancel();
    return result;
  }

  // ============================================================================
  // iOS-only: Scan and Connect to Bridger device
  // ============================================================================

  /// Scan for Bridger devices and connect to the first matching one.
  /// Optionally match by device name. Returns the connected device ID or null.
  Future<String?> scanAndConnect(
      {String? targetDeviceName,
      Duration timeout = const Duration(seconds: 30)}) async {
    if (!isIOS) return null;

    debugPrint(
        '[BleService] scanAndConnect: target="$targetDeviceName", timeout=${timeout.inSeconds}s');
    _discoveredDevices.clear();
    _areServicesReady = false;
    await startScanning();

    final completer = Completer<String?>();
    StreamSubscription? scanSub;
    StreamSubscription? connectSub;
    Timer? timeoutTimer;

    scanSub = discoveredDevicesStream.listen((device) {
      debugPrint(
          '[BleService] Discovered device: "${device.name}" (${device.id}) rssi=${device.rssi}');
      // Match by name containing "Bridge" or matching target name
      final name = device.name.toLowerCase();
      final target = (targetDeviceName ?? 'bridger').toLowerCase();

      if (name.contains('bridge') || name.contains(target)) {
        debugPrint('[BleService] MATCH found! Connecting to ${device.id}...');
        timeoutTimer?.cancel();
        scanSub?.cancel();
        stopScanning();

        // Connect to this device
        connect(device.id);

        // Wait for actual connection event instead of arbitrary delay
        Timer? connectTimer;
        connectSub = connectionStateStream.listen((state) {
          if (state == BleConnectionState.connected &&
              !completer.isCompleted) {
            connectTimer?.cancel();
            connectSub?.cancel();
            debugPrint(
                '[BleService] Connection established to ${device.id}');
            completer.complete(device.id);
          } else if ((state == BleConnectionState.error ||
                  state == BleConnectionState.disconnected) &&
              !completer.isCompleted) {
            connectTimer?.cancel();
            connectSub?.cancel();
            debugPrint('[BleService] Connection failed to ${device.id}');
            completer.complete(null);
          }
        });

        // Cancellable safety timeout for connection attempt
        connectTimer = Timer(const Duration(seconds: 10), () {
          connectSub?.cancel();
          if (!completer.isCompleted) {
            debugPrint(
                '[BleService] Connection attempt timed out for ${device.id}');
            completer.complete(null);
          }
        });
      }
    });

    timeoutTimer = Timer(timeout, () {
      debugPrint(
          '[BleService] Scan timed out after ${timeout.inSeconds}s — no matching device found');
      scanSub?.cancel();
      connectSub?.cancel();
      stopScanning();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  // ============================================================================
  // Android-only: Send pairing response back to iOS
  // ============================================================================

  /// Send a pairing response notification to connected iOS device (Android only)
  Future<bool> sendPairingResponse(Map<String, dynamic> response) async {
    if (!isAndroid) return false;

    try {
      final json = jsonEncode({
        'type': 'PAIRING_RESPONSE',
        'data': response,
      });
      // Send via status update characteristic (which iOS subscribes to)
      return await _methodChannel.invokeMethod<bool>('sendStatusUpdate', {
            'data': json,
          }) ??
          false;
    } on PlatformException catch (e) {
      _errorController.add('Failed to send pairing response: ${e.message}');
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
    _pairingResponseController.close();
    _bulkMessageController.close();
    _servicesReadyController.close();
  }
}
