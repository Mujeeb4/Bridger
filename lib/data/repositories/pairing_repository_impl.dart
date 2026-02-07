import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/pairing_repository.dart';
import '../models/pairing_models.dart';

/// Implementation of PairingRepository using secure storage
class PairingRepositoryImpl implements PairingRepository {
  final FlutterSecureStorage _secureStorage;

  static const String _pairedDeviceKey = 'paired_device';
  static const String _pairingCodeKey = 'pairing_code';

  PairingRepositoryImpl(this._secureStorage);

  @override
  Future<PairedDevice?> getPairedDevice() async {
    try {
      final json = await _secureStorage.read(key: _pairedDeviceKey);
      if (json == null) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      return PairedDevice.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> savePairedDevice(PairedDevice device) async {
    final json = jsonEncode(device.toJson());
    await _secureStorage.write(key: _pairedDeviceKey, value: json);
  }

  @override
  Future<void> removePairedDevice() async {
    await _secureStorage.delete(key: _pairedDeviceKey);
    await clearPairingCode();
  }

  @override
  Future<bool> isPaired() async {
    final device = await getPairedDevice();
    return device != null;
  }

  @override
  Future<void> updateLastSeen(DateTime lastSeen) async {
    final device = await getPairedDevice();
    if (device == null) return;

    final updated = device.copyWith(lastSeen: lastSeen);
    await savePairedDevice(updated);
  }

  @override
  Future<PairingCode?> getCurrentPairingCode() async {
    try {
      final json = await _secureStorage.read(key: _pairingCodeKey);
      if (json == null) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      final code = PairingCode.fromJson(data);
      
      // Return null if expired
      if (code.isExpired) {
        await clearPairingCode();
        return null;
      }
      
      return code;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> savePairingCode(PairingCode code) async {
    final json = jsonEncode(code.toJson());
    await _secureStorage.write(key: _pairingCodeKey, value: json);
  }

  @override
  Future<void> clearPairingCode() async {
    await _secureStorage.delete(key: _pairingCodeKey);
  }

  @override
  Future<bool> validatePairingCode(String code) async {
    final storedCode = await getCurrentPairingCode();
    if (storedCode == null) return false;
    if (storedCode.isExpired) return false;
    return storedCode.code == code;
  }
}
