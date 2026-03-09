import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Centralized service for requesting and checking all runtime permissions.
/// Must be called early in app lifecycle (before BLE, SMS, Call, etc.).
class PermissionService {
  /// Request all required permissions for the current platform.
  /// Returns a map of permission → granted status.
  static Future<Map<Permission, bool>> requestAll() async {
    if (Platform.isAndroid) {
      return _requestAndroidPermissions();
    } else if (Platform.isIOS) {
      return _requestIOSPermissions();
    }
    return {};
  }

  /// Check if all critical permissions are granted.
  static Future<bool> hasAllCriticalPermissions() async {
    if (Platform.isAndroid) {
      return await _checkAndroidCritical();
    } else if (Platform.isIOS) {
      return await _checkIOSCritical();
    }
    return false;
  }

  // ============================================================================
  // Android Permissions
  // ============================================================================

  static Future<Map<Permission, bool>> _requestAndroidPermissions() async {
    final permissions = <Permission>[
      // Bluetooth (API 31+)
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.bluetoothScan,

      // Location (required for BLE on older Android)
      Permission.locationWhenInUse,

      // SMS
      Permission.sms,

      // Phone & Call
      Permission.phone,

      // Contacts
      Permission.contacts,

      // Microphone (for call audio)
      Permission.microphone,

      // Notifications (API 33+)
      Permission.notification,

      // Camera (QR code scanning)
      Permission.camera,
    ];

    final statuses = await permissions.request();

    final results = <Permission, bool>{};
    for (final entry in statuses.entries) {
      results[entry.key] = entry.value.isGranted;
    }

    return results;
  }

  static Future<bool> _checkAndroidCritical() async {
    final critical = [
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.bluetoothScan,
      Permission.sms,
      Permission.phone,
      Permission.microphone,
      Permission.notification,
    ];

    for (final p in critical) {
      if (!await p.isGranted) return false;
    }
    return true;
  }

  // ============================================================================
  // iOS Permissions
  // ============================================================================

  static Future<Map<Permission, bool>> _requestIOSPermissions() async {
    final permissions = <Permission>[
      // Bluetooth
      Permission.bluetooth,

      // Microphone (for call audio)
      Permission.microphone,

      // Notifications (local notifications for mirroring)
      Permission.notification,

      // Camera (QR code scanning)
      Permission.camera,

      // Contacts (caller info display)
      Permission.contacts,
    ];

    final statuses = await permissions.request();

    final results = <Permission, bool>{};
    for (final entry in statuses.entries) {
      results[entry.key] = entry.value.isGranted;
    }

    return results;
  }

  static Future<bool> _checkIOSCritical() async {
    final critical = [
      Permission.bluetooth,
      Permission.microphone,
      Permission.notification,
    ];

    for (final p in critical) {
      if (!await p.isGranted) return false;
    }
    return true;
  }

  // ============================================================================
  // Individual Permission Checks
  // ============================================================================

  static Future<bool> hasBluetooth() async {
    if (Platform.isAndroid) {
      return await Permission.bluetoothConnect.isGranted &&
          await Permission.bluetoothAdvertise.isGranted &&
          await Permission.bluetoothScan.isGranted;
    }
    return await Permission.bluetooth.isGranted;
  }

  static Future<bool> hasMicrophone() async {
    return await Permission.microphone.isGranted;
  }

  static Future<bool> hasSMS() async {
    if (!Platform.isAndroid) return true; // iOS doesn't have SMS permission
    return await Permission.sms.isGranted;
  }

  static Future<bool> hasPhone() async {
    if (!Platform.isAndroid) return true;
    return await Permission.phone.isGranted;
  }

  static Future<bool> hasContacts() async {
    return await Permission.contacts.isGranted;
  }

  static Future<bool> hasCamera() async {
    return await Permission.camera.isGranted;
  }

  static Future<bool> hasNotification() async {
    return await Permission.notification.isGranted;
  }

  /// Open app settings so user can manually grant denied permissions.
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
