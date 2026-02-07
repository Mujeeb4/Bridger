/// Repository interface for app settings operations
abstract class SettingsRepository {
  /// Get a setting value by key
  Future<String?> getSetting(String key);

  /// Get a boolean setting (returns false if not found)
  Future<bool> getBoolSetting(String key);

  /// Get an integer setting (returns defaultValue if not found)
  Future<int> getIntSetting(String key, {int defaultValue = 0});

  /// Set a setting value
  Future<void> setSetting(String key, String value);

  /// Set a boolean setting
  Future<void> setBoolSetting(String key, bool value);

  /// Set an integer setting
  Future<void> setIntSetting(String key, int value);

  /// Delete a setting
  Future<void> deleteSetting(String key);

  /// Check if a setting exists
  Future<bool> hasSetting(String key);

  // Convenience methods for common settings
  Future<bool> isDevicePaired();
  Future<void> setDevicePaired(bool value);
  Future<String?> getPairedDeviceId();
  Future<void> setPairedDeviceId(String? deviceId);
  Future<bool> isAutoConnectEnabled();
  Future<void> setAutoConnectEnabled(bool value);
}
