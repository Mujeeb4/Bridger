// App Constants
class AppConstants {
  // App Info
  static const String appName = 'Bridge Phone';
  static const String appVersion = '1.0.0';
  
  // BLE UUIDs
  static const String bleServiceControlUUID = '0000180A-0000-1000-8000-00805F9B34FB';
  static const String bleServiceNotificationUUID = '0000180B-0000-1000-8000-00805F9B34FB';
  static const String bleServiceDataUUID = '0000180C-0000-1000-8000-00805F9B34FB';
  
  // BLE Characteristics
  static const String bleCharCommandUUID = '00002A00-0000-1000-8000-00805F9B34FB';
  static const String bleCharStatusUUID = '00002A01-0000-1000-8000-00805F9B34FB';
  static const String bleCharSMSAlertUUID = '00002A10-0000-1000-8000-00805F9B34FB';
  static const String bleCharCallAlertUUID = '00002A11-0000-1000-8000-00805F9B34FB';
  static const String bleCharAppNotificationUUID = '00002A12-0000-1000-8000-00805F9B34FB';
  static const String bleCharBulkTransferUUID = '00002A20-0000-1000-8000-00805F9B34FB';
  
  // WebSocket
  static const int webSocketPort = 8765;
  static const String webSocketProtocol = 'wss';
  
  // Connection
  static const int connectionTimeout = 30; // seconds
  static const int reconnectDelay = 5; // seconds
  static const int maxReconnectAttempts = 5;
  
  // Hotspot
  static const String hotspotSSIDPrefix = 'Bridge_';
  static const String hotspotDefaultPassword = 'Bridge@2025';
  
  // Database
  static const String databaseName = 'bridge_phone.db';
  static const int databaseVersion = 1;
  
  // SharedPreferences Keys
  static const String keyDeviceId = 'device_id';
  static const String keyPairedDeviceId = 'paired_device_id';
  static const String keyEncryptionKey = 'encryption_key';
  static const String keyIsPaired = 'is_paired';
  static const String keyIsAndroid = 'is_android';
  static const String keyHotspotSSID = 'hotspot_ssid';
  static const String keyHotspotPassword = 'hotspot_password';
  static const String keyAutoConnectHotspot = 'auto_connect_hotspot';
  static const String keyBatteryOptimizationMode = 'battery_optimization_mode';
  
  // Notification Channels (Android)
  static const String notificationChannelId = 'bridge_phone_channel';
  static const String notificationChannelName = 'Bridge Phone';
  static const String notificationChannelDescription = 'Notifications from Bridge Phone';
  
  // Foreground Service
  static const int foregroundServiceNotificationId = 1001;
  static const String foregroundServiceTitle = 'Bridge Phone Active';
  static const String foregroundServiceMessage = 'Maintaining connection with paired device';
  
  // Timeouts
  static const int smsTimeout = 10; // seconds
  static const int callSetupTimeout = 15; // seconds
  static const int webrtcConnectionTimeout = 20; // seconds
}
