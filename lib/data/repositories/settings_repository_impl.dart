import '../../datasources/local/database.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../../core/constants/app_constants.dart';

/// Implementation of SettingsRepository using Drift database
class SettingsRepositoryImpl implements SettingsRepository {
  final AppDatabase _database;

  SettingsRepositoryImpl(this._database);

  @override
  Future<String?> getSetting(String key) async {
    return await _database.getSetting(key);
  }

  @override
  Future<bool> getBoolSetting(String key) async {
    final value = await _database.getSetting(key);
    return value?.toLowerCase() == 'true';
  }

  @override
  Future<int> getIntSetting(String key, {int defaultValue = 0}) async {
    final value = await _database.getSetting(key);
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await _database.setSetting(key, value);
  }

  @override
  Future<void> setBoolSetting(String key, bool value) async {
    await _database.setSetting(key, value.toString());
  }

  @override
  Future<void> setIntSetting(String key, int value) async {
    await _database.setSetting(key, value.toString());
  }

  @override
  Future<void> deleteSetting(String key) async {
    await _database.deleteSetting(key);
  }

  @override
  Future<bool> hasSetting(String key) async {
    final value = await _database.getSetting(key);
    return value != null;
  }

  // ============================================================================
  // Convenience Methods for Common Settings
  // ============================================================================

  @override
  Future<bool> isDevicePaired() async {
    return await getBoolSetting(AppConstants.keyIsPaired);
  }

  @override
  Future<void> setDevicePaired(bool value) async {
    await setBoolSetting(AppConstants.keyIsPaired, value);
  }

  @override
  Future<String?> getPairedDeviceId() async {
    return await getSetting(AppConstants.keyPairedDeviceId);
  }

  @override
  Future<void> setPairedDeviceId(String? deviceId) async {
    if (deviceId == null) {
      await deleteSetting(AppConstants.keyPairedDeviceId);
    } else {
      await setSetting(AppConstants.keyPairedDeviceId, deviceId);
    }
  }

  @override
  Future<bool> isAutoConnectEnabled() async {
    // Default to true if not set
    final value = await getSetting(AppConstants.keyAutoConnectHotspot);
    return value?.toLowerCase() != 'false';
  }

  @override
  Future<void> setAutoConnectEnabled(bool value) async {
    await setBoolSetting(AppConstants.keyAutoConnectHotspot, value);
  }
}
