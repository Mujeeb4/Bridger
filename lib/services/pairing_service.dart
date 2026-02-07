import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';

import '../data/models/pairing_models.dart';
import '../domain/repositories/pairing_repository.dart';
import 'ble_service.dart';
import 'encryption_service.dart';

/// High-level service for device pairing orchestration
class PairingService {
  final PairingRepository _pairingRepository;
  final BleService _bleService;
  final EncryptionService _encryptionService;

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

  PairingService({
    required PairingRepository pairingRepository,
    required BleService bleService,
    required EncryptionService encryptionService,
  })  : _pairingRepository = pairingRepository,
        _bleService = bleService,
        _encryptionService = encryptionService;

  // ============================================================================
  // Status Queries
  // ============================================================================

  /// Check if currently paired
  Future<bool> isPaired() => _pairingRepository.isPaired();

  /// Get paired device info
  Future<PairedDevice?> getPairedDevice() => _pairingRepository.getPairedDevice();

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

      // Create QR data
      _currentQRData = PairingQRData(
        deviceId: deviceId,
        deviceName: deviceName,
        pairingCode: _currentCode!.code,
        publicKey: publicKey,
        timestamp: DateTime.now(),
      );

      _updateState(PairingState.waitingForScan);
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
  // iOS: Pairing Request
  // ============================================================================

  /// Process scanned QR data and initiate pairing (iOS only)
  Future<bool> processPairingQR(String qrData) async {
    if (!Platform.isIOS) return false;

    final pairingData = PairingQRData.decode(qrData);
    if (pairingData == null) {
      _updateState(PairingState.failed);
      return false;
    }

    return await _initiatePairing(pairingData);
  }

  /// Manually enter pairing code (iOS only)
  Future<bool> enterPairingCode(String code, String deviceId) async {
    if (!Platform.isIOS) return false;

    // Create minimal pairing data for manual entry
    final pairingData = PairingQRData(
      deviceId: deviceId,
      deviceName: 'Android Device',
      pairingCode: code,
      publicKey: '',
      timestamp: DateTime.now(),
    );

    return await _initiatePairing(pairingData);
  }

  /// Initiate pairing with scanned/entered data
  Future<bool> _initiatePairing(PairingQRData pairingData) async {
    _updateState(PairingState.connecting);

    try {
      // Connect to the Android device via BLE
      await _bleService.connect(pairingData.deviceId);

      // Wait for connection
      await Future.delayed(const Duration(seconds: 2));

      if (!await _bleService.isConnected()) {
        _updateState(PairingState.failed);
        return false;
      }

      _updateState(PairingState.exchangingKeys);

      // Get iOS device info
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      final deviceName = iosInfo.name;
      final deviceId = await _getDeviceId();

      // Generate our public key
      final publicKey = _generateSessionKey();

      // Send pairing request via BLE command
      final request = PairingRequest(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: 'ios',
        pairingCode: pairingData.pairingCode,
        publicKey: publicKey,
      );

      final success = await _bleService.sendBulkData(
        utf8.encode(jsonEncode({
          'type': 'PAIRING_REQUEST',
          'data': request.toJson(),
        })),
      );

      if (!success) {
        _updateState(PairingState.failed);
        return false;
      }

      // Wait for response (in real implementation, listen to BLE stream)
      // For now, simulate success
      await Future.delayed(const Duration(seconds: 1));

      // Store paired device
      final pairedDevice = PairedDevice(
        deviceId: pairingData.deviceId,
        deviceName: pairingData.deviceName,
        platform: 'android',
        sharedKey: pairingData.publicKey, // In real impl, derive shared key
        pairedAt: DateTime.now(),
      );

      await _pairingRepository.savePairedDevice(pairedDevice);
      _updateState(PairingState.paired);
      return true;
    } catch (e) {
      _updateState(PairingState.failed);
      return false;
    }
  }

  // ============================================================================
  // Android: Handle Incoming Pairing Request
  // ============================================================================

  /// Process incoming pairing request from iOS (Android only)
  Future<PairingResponse> handlePairingRequest(PairingRequest request) async {
    if (!Platform.isAndroid) {
      return PairingResponse(success: false, errorMessage: 'Not Android device');
    }

    // Validate pairing code
    final isValid = await _pairingRepository.validatePairingCode(request.pairingCode);
    if (!isValid) {
      return PairingResponse(success: false, errorMessage: 'Invalid or expired pairing code');
    }

    try {
      // Generate shared key
      final sharedKey = await _encryptionService.generateSecureKey();
      final sharedKeyBase64 = base64Encode(sharedKey);

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

      _updateState(PairingState.paired);

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

  void dispose() {
    _stateController.close();
  }
}
