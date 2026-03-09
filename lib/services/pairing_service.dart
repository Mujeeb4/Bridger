import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../data/models/ble_models.dart';
import '../data/models/pairing_models.dart';
import '../domain/repositories/pairing_repository.dart';
import '../domain/repositories/settings_repository.dart';
import 'ble_service.dart';
import 'communication_service.dart';
import 'command_dispatcher_service.dart';
import 'sms_service.dart';
import 'call_service.dart';
import 'notification_service.dart';
import 'encryption_service.dart';

/// High-level service for device pairing orchestration
class PairingService {
  final PairingRepository _pairingRepository;
  final SettingsRepository _settingsRepository;
  final BleService _bleService;
  final EncryptionService _encryptionService;
  final CommunicationService _communicationService;

  // Current pairing state
  PairingState _state = PairingState.idle;
  PairingState get state => _state;

  // Stream for state changes
  final _stateController = StreamController<PairingState>.broadcast();
  Stream<PairingState> get stateStream => _stateController.stream;

  // Current pairing data (Android only)
  PairingCode? _currentCode;
  PairingQRData? _currentQRData;

  PairingCode? get currentCode => _currentCode;
  PairingQRData? get currentQRData => _currentQRData;

  // Subscription for incoming commands (Android)
  StreamSubscription? _commandSubscription;

  PairingService({
    required PairingRepository pairingRepository,
    required SettingsRepository settingsRepository,
    required BleService bleService,
    required EncryptionService encryptionService,
    required CommunicationService communicationService,
  })  : _pairingRepository = pairingRepository,
        _settingsRepository = settingsRepository,
        _bleService = bleService,
        _encryptionService = encryptionService,
        _communicationService = communicationService {
    // Android: listen for incoming pairing requests from iOS
    if (Platform.isAndroid) {
      _listenForPairingRequests();
    }
  }

  // ============================================================================
  // Status Queries
  // ============================================================================

  /// Check if currently paired
  Future<bool> isPaired() => _pairingRepository.isPaired();

  /// Get paired device info
  Future<PairedDevice?> getPairedDevice() =>
      _pairingRepository.getPairedDevice();

  // ============================================================================
  // Android: Listen for incoming pairing requests
  // ============================================================================

  void _listenForPairingRequests() {
    _commandSubscription = _bleService.commandStream.listen((command) async {
      // The command JSON has { "cmd": "PAIRING_REQUEST", "payload": {...}, "requestId": "..." }
      final cmdType = command.command;

      if (cmdType == 'PAIRING_REQUEST') {
        final request = PairingRequest.fromJson(command.payload);
        final response = await handlePairingRequest(request);

        // Send the response back to iOS via BLE
        await _bleService.sendPairingResponse(response.toJson());
      }
    });
  }

  // ============================================================================
  // Android: Pairing Code Generation
  // ============================================================================

  /// Generate a new pairing code and QR data (Android only)
  Future<PairingQRData?> generatePairingCode() async {
    if (!Platform.isAndroid) return null;

    _updateState(PairingState.generatingCode);

    try {
      // Generate pairing code
      _currentCode = PairingCode.generate();
      await _pairingRepository.savePairingCode(_currentCode!);

      // Get device info
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final deviceName = androidInfo.model;
      final deviceId = await _getDeviceId();

      // Generate a temporary public key for this pairing session
      final publicKey = _generateSessionKey();

      // Create QR data with BLE service info so iOS can discover us
      _currentQRData = PairingQRData(
        deviceId: deviceId,
        deviceName: deviceName,
        pairingCode: _currentCode!.code,
        publicKey: publicKey,
        timestamp: DateTime.now(),
        bleServiceUuid: '4836180A-5e34-45c5-9252-710471c676af',
        wsPort: 8765,
      );

      _updateState(PairingState.waitingForScan);

      // Ensure BLE is initialized (may have failed at startup if Bluetooth was off)
      final bleInit = await _bleService.initialize();
      debugPrint('[PairingService] BLE initialized for advertising: $bleInit');

      // Start advertising so iOS can discover and connect
      await _bleService.startAdvertising();
      debugPrint(
          '[PairingService] Advertising started, code=${_currentCode!.code}');

      return _currentQRData;
    } catch (e) {
      _updateState(PairingState.failed);
      return null;
    }
  }

  /// Get the current pairing code string
  String? getPairingCodeString() => _currentCode?.code;

  /// Check if current code is still valid
  bool isCodeValid() => _currentCode != null && !_currentCode!.isExpired;

  /// Get remaining time for current code
  Duration? getCodeRemainingTime() => _currentCode?.remainingTime;

  // ============================================================================
  // iOS: Pairing Request via QR Scan
  // ============================================================================

  /// Process scanned QR data and initiate pairing (iOS only)
  Future<bool> processPairingQR(String qrData) async {
    if (!Platform.isIOS) return false;

    debugPrint(
        '[PairingService] QR scanned, raw data length: ${qrData.length}');

    final pairingData = PairingQRData.decode(qrData);
    if (pairingData == null) {
      debugPrint('[PairingService] Failed to decode QR data');
      _updateState(PairingState.failed);
      return false;
    }

    debugPrint(
        '[PairingService] QR decoded: device=${pairingData.deviceName}, code=${pairingData.pairingCode}');
    return await _initiatePairing(pairingData);
  }

  // ============================================================================
  // iOS: Manual Code Entry Pairing
  // ============================================================================

  /// Manually enter pairing code (iOS only)
  /// This will scan for a Bridger device, connect, and send the code
  Future<bool> enterPairingCode(String code) async {
    if (!Platform.isIOS) return false;

    debugPrint('[PairingService] enterPairingCode: $code');
    _updateState(PairingState.scanning);

    try {
      // Ensure BLE is initialized before scanning
      final bleReady = await _bleService.initialize();
      debugPrint('[PairingService] BLE initialized: $bleReady');

      // Scan for the Bridger Android device
      debugPrint('[PairingService] Starting BLE scan for "Bridger"...');
      final deviceId = await _bleService.scanAndConnect(
        targetDeviceName: 'Bridger',
        timeout: const Duration(seconds: 30),
      );

      debugPrint('[PairingService] Scan result: $deviceId');
      if (deviceId == null) {
        debugPrint('[PairingService] FAILED: No Bridger device found');
        _updateState(PairingState.failed);
        return false;
      }

      // Create pairing data with discovered device info
      final pairingData = PairingQRData(
        deviceId: deviceId,
        deviceName: 'Android Device',
        pairingCode: code,
        publicKey: '',
        timestamp: DateTime.now(),
      );

      return await _initiatePairing(pairingData);
    } catch (e) {
      _updateState(PairingState.failed);
      return false;
    }
  }

  // ============================================================================
  // iOS: Core Pairing Logic
  // ============================================================================

  /// Initiate pairing with scanned/entered data
  Future<bool> _initiatePairing(PairingQRData pairingData) async {
    debugPrint('[PairingService] _initiatePairing started');
    _updateState(PairingState.connecting);

    try {
      // Ensure BLE is initialized
      final bleReady = await _bleService.initialize();
      debugPrint('[PairingService] BLE initialized: $bleReady');

      // Step 1: Establish BLE connection to Android device
      final alreadyConnected = await _bleService.isConnected();
      debugPrint('[PairingService] Already connected: $alreadyConnected');

      if (!alreadyConnected) {
        _updateState(PairingState.scanning);

        // Scan for the Bridger device. The BLE advertised name is "Bridger",
        // not the Android model name, so also accept any device matching our
        // service UUID (the scan filter already limits to our UUID).
        final connectedId = await _bleService.scanAndConnect(
          targetDeviceName: pairingData.deviceName,
          timeout: const Duration(seconds: 30),
        );

        debugPrint('[PairingService] Scan result: $connectedId');
        if (connectedId == null) {
          debugPrint('[PairingService] FAILED: No device found during scan');
          _updateState(PairingState.failed);
          return false;
        }
      }

      // Step 2: Ensure BLE services are discovered.
      // This will re-trigger discovery if we connected before Android
      // finished registering its GATT services.
      debugPrint('[PairingService] Waiting for service discovery...');
      final servicesReady = await _bleService.waitForServicesReady(
        timeout: const Duration(seconds: 20),
      );

      if (!servicesReady) {
        debugPrint(
            '[PairingService] First attempt failed, retrying service discovery...');
        // One more attempt: disconnect and reconnect cleanly
        await _bleService.disconnect();
        await Future.delayed(const Duration(seconds: 1));

        _updateState(PairingState.scanning);
        final retryId = await _bleService.scanAndConnect(
          targetDeviceName: pairingData.deviceName,
          timeout: const Duration(seconds: 20),
        );
        if (retryId == null) {
          debugPrint('[PairingService] FAILED: Retry scan found no device');
          _updateState(PairingState.failed);
          return false;
        }

        final retryReady = await _bleService.waitForServicesReady(
          timeout: const Duration(seconds: 15),
        );
        if (!retryReady) {
          debugPrint(
              '[PairingService] FAILED: Services not ready after retry');
          _updateState(PairingState.failed);
          return false;
        }
      }
      debugPrint('[PairingService] Services ready!');

      // Step 3: Verify connection is still alive
      final isConnected = await _bleService.isConnected();
      debugPrint('[PairingService] Connected: $isConnected');
      if (!isConnected) {
        debugPrint(
            '[PairingService] FAILED: Lost connection after service discovery');
        _updateState(PairingState.failed);
        return false;
      }

      // Step 4: Exchange pairing keys
      _updateState(PairingState.exchangingKeys);

      // Get iOS device info
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      final deviceName = iosInfo.name;
      final deviceId = await _getDeviceId();

      // Generate our public key
      final publicKey = _generateSessionKey();

      // Build pairing request
      final request = PairingRequest(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: 'ios',
        pairingCode: pairingData.pairingCode,
        publicKey: publicKey,
      );

      // Send pairing request via CHAR_COMMAND (not bulk transfer!)
      debugPrint('[PairingService] Sending PAIRING_REQUEST command...');
      final success = await _bleService.sendCommand({
        'cmd': 'PAIRING_REQUEST',
        'payload': request.toJson(),
        'requestId': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      debugPrint('[PairingService] Command sent: $success');
      if (!success) {
        debugPrint('[PairingService] FAILED: Could not send pairing request');
        _updateState(PairingState.failed);
        return false;
      }

      // Wait for REAL response from Android (not fake delay)
      debugPrint('[PairingService] Waiting for pairing response...');
      final response = await _waitForPairingResponse(
        timeout: const Duration(seconds: 15),
      );

      debugPrint('[PairingService] Response: $response');
      if (response == null || response['success'] != true) {
        debugPrint(
            '[PairingService] FAILED: Invalid/null response from Android');
        _updateState(PairingState.failed);
        return false;
      }

      // Extract shared key from response
      final sharedKey =
          response['sharedKey'] as String? ?? pairingData.publicKey;

      // Store paired device
      final pairedDevice = PairedDevice(
        deviceId: pairingData.deviceId,
        deviceName: pairingData.deviceName,
        platform: 'android',
        sharedKey: sharedKey,
        pairedAt: DateTime.now(),
      );

      await _pairingRepository.savePairedDevice(pairedDevice);

      // Sync pairing state to SettingsRepository
      await _settingsRepository.setDevicePaired(true);
      await _settingsRepository.setPairedDeviceId(pairingData.deviceId);

      // Import the shared encryption key
      if (sharedKey.isNotEmpty) {
        try {
          final keyBytes = base64Decode(sharedKey);
          await _encryptionService.importKey(keyBytes);
        } catch (_) {
          // Key import failure is non-fatal for pairing
        }
      }

      _updateState(PairingState.paired);

      // Start communication services (WebSocket client connection on iOS)
      _activatePostPairingServices();

      return true;
    } catch (e) {
      debugPrint('[PairingService] _initiatePairing exception: $e');
      // Disconnect stale connection so next attempt starts fresh
      try {
        await _bleService.disconnect();
      } catch (_) {}
      _updateState(PairingState.failed);
      return false;
    }
  }

  /// Wait for a pairing response from Android via BLE notification
  Future<Map<String, dynamic>?> _waitForPairingResponse({
    required Duration timeout,
  }) async {
    final completer = Completer<Map<String, dynamic>?>();
    late final StreamSubscription sub;
    late final StreamSubscription statusSub;

    sub = _bleService.pairingResponseStream.listen((response) {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.complete(response);
      }
    });

    // Also handle disconnection during wait
    statusSub = _bleService.connectionStateStream.listen((state) {
      if (state == BleConnectionState.disconnected && !completer.isCompleted) {
        statusSub.cancel();
        sub.cancel();
        completer.complete(null);
      }
    });

    // Timeout
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        sub.cancel();
        statusSub.cancel();
        completer.complete(null);
      }
    });

    final result = await completer.future;
    timer.cancel();
    sub.cancel();
    statusSub.cancel();
    return result;
  }

  // ============================================================================
  // Android: Handle Incoming Pairing Request
  // ============================================================================

  /// Process incoming pairing request from iOS (Android only)
  Future<PairingResponse> handlePairingRequest(PairingRequest request) async {
    if (!Platform.isAndroid) {
      return PairingResponse(
          success: false, errorMessage: 'Not Android device');
    }

    // Validate pairing code
    final isValid =
        await _pairingRepository.validatePairingCode(request.pairingCode);
    if (!isValid) {
      return PairingResponse(
          success: false, errorMessage: 'Invalid or expired pairing code');
    }

    try {
      // Generate shared key
      final sharedKey = await _encryptionService.generateNewKey();
      final sharedKeyBase64 = base64Encode(sharedKey);

      // CRITICAL: Import the shared key into EncryptionService so both
      // sides use the same key for encryption/decryption
      await _encryptionService.importKey(sharedKey);

      // Store paired device
      final pairedDevice = PairedDevice(
        deviceId: request.deviceId,
        deviceName: request.deviceName,
        platform: request.platform,
        sharedKey: sharedKeyBase64,
        pairedAt: DateTime.now(),
      );

      await _pairingRepository.savePairedDevice(pairedDevice);
      await _pairingRepository.clearPairingCode();

      // Sync pairing state to SettingsRepository
      await _settingsRepository.setDevicePaired(true);
      await _settingsRepository.setPairedDeviceId(request.deviceId);

      _updateState(PairingState.paired);

      // Start communication services (WebSocket server + BLE advertising)
      _activatePostPairingServices();

      return PairingResponse(
        success: true,
        sharedKey: sharedKeyBase64,
      );
    } catch (e) {
      return PairingResponse(success: false, errorMessage: e.toString());
    }
  }

  // ============================================================================
  // Unpair
  // ============================================================================

  /// Remove paired device
  Future<void> unpair() async {
    await _pairingRepository.removePairedDevice();
    await _settingsRepository.setDevicePaired(false);
    await _settingsRepository.setPairedDeviceId(null);
    await _encryptionService.clearKey();
    _currentCode = null;
    _currentQRData = null;
    _updateState(PairingState.idle);
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  void _updateState(PairingState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return info.id;
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return info.identifierForVendor ?? 'unknown';
    }
    return 'unknown';
  }

  String _generateSessionKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Activate WebSocket and communication services after a successful pairing
  Future<void> _activatePostPairingServices() async {
    try {
      // Initialize CommunicationService (wires up event stream listeners)
      await _communicationService.initialize();

      // Initialize SMS, Call, and Notification services so they start
      // listening to messageStream (iOS) and native event channels (Android)
      try {
        final getIt = GetIt.instance;
        await getIt<SMSService>().initialize();
        await getIt<CallService>().initialize();
        await getIt<NotificationService>().initialize();
      } catch (_) {
        // May not be registered in tests
      }

      if (Platform.isAndroid) {
        // Android: Start WebSocket server + continue BLE advertising
        await _communicationService.startServices(wsPort: 8765);

        // Android: Start listening for commands from iOS
        try {
          final dispatcher = GetIt.instance<CommandDispatcherService>();
          dispatcher.initialize();
        } catch (_) {
          // CommandDispatcherService may not be registered in tests
        }
      } else if (Platform.isIOS) {
        // iOS: BLE is the active transport after pairing
        // Try to set BLE transport via CommunicationService.connect()
        final isConnected = await _bleService.isConnected();
        debugPrint('[PairingService] iOS transport set to BLE: $isConnected');
        if (isConnected) {
          // Get the connected device ID to set BLE as active transport
          final deviceId = _bleService.connectedDeviceId;
          if (deviceId != null) {
            await _communicationService.connect(bleDeviceId: deviceId);
          } else {
            // Fallback: get device ID from native layer
            final addresses = await _bleService.getConnectedDeviceAddresses();
            if (addresses.isNotEmpty) {
              await _communicationService.connect(bleDeviceId: addresses.first);
            }
          }
        }
        debugPrint(
            '[PairingService] Current transport: ${_communicationService.currentTransport}');
      }
    } catch (e) {
      debugPrint(
          '[PairingService] _activatePostPairingServices error: $e');
    }
  }

  void dispose() {
    _commandSubscription?.cancel();
    _stateController.close();
  }
}
