import 'dart:convert';
import 'dart:math';

/// Represents a paired device stored securely
class PairedDevice {
  final String deviceId;
  final String deviceName;
  final String platform; // 'android' or 'ios'
  final String sharedKey; // Base64 encoded encryption key
  final DateTime pairedAt;
  final DateTime? lastSeen;

  PairedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.sharedKey,
    required this.pairedAt,
    this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    'sharedKey': sharedKey,
    'pairedAt': pairedAt.toIso8601String(),
    'lastSeen': lastSeen?.toIso8601String(),
  };

  factory PairedDevice.fromJson(Map<String, dynamic> json) {
    return PairedDevice(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      platform: json['platform'] as String,
      sharedKey: json['sharedKey'] as String,
      pairedAt: DateTime.parse(json['pairedAt'] as String),
      lastSeen: json['lastSeen'] != null 
          ? DateTime.parse(json['lastSeen'] as String) 
          : null,
    );
  }

  PairedDevice copyWith({
    String? deviceId,
    String? deviceName,
    String? platform,
    String? sharedKey,
    DateTime? pairedAt,
    DateTime? lastSeen,
  }) {
    return PairedDevice(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      sharedKey: sharedKey ?? this.sharedKey,
      pairedAt: pairedAt ?? this.pairedAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

/// 6-digit pairing code with expiry
class PairingCode {
  final String code;
  final DateTime createdAt;
  final Duration validity;

  PairingCode({
    required this.code,
    required this.createdAt,
    this.validity = const Duration(minutes: 5),
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  DateTime get expiresAt => createdAt.add(validity);
  
  Duration get remainingTime {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Generate a random 6-digit pairing code
  static PairingCode generate() {
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    return PairingCode(
      code: code,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'createdAt': createdAt.toIso8601String(),
    'validity': validity.inSeconds,
  };

  factory PairingCode.fromJson(Map<String, dynamic> json) {
    return PairingCode(
      code: json['code'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      validity: Duration(seconds: json['validity'] as int),
    );
  }
}

/// Data contained in pairing QR code
class PairingQRData {
  final String deviceId;
  final String deviceName;
  final String pairingCode;
  final String publicKey; // For key exchange
  final DateTime timestamp;

  PairingQRData({
    required this.deviceId,
    required this.deviceName,
    required this.pairingCode,
    required this.publicKey,
    required this.timestamp,
  });

  /// Encode to JSON string for QR code
  String encode() => jsonEncode(toJson());

  /// Decode from QR code data
  static PairingQRData? decode(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return PairingQRData.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'v': 1, // Version for future compatibility
    'id': deviceId,
    'name': deviceName,
    'code': pairingCode,
    'key': publicKey,
    'ts': timestamp.millisecondsSinceEpoch,
  };

  factory PairingQRData.fromJson(Map<String, dynamic> json) {
    return PairingQRData(
      deviceId: json['id'] as String,
      deviceName: json['name'] as String,
      pairingCode: json['code'] as String,
      publicKey: json['key'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int),
    );
  }
}

/// Pairing request sent via BLE
class PairingRequest {
  final String deviceId;
  final String deviceName;
  final String platform;
  final String pairingCode;
  final String publicKey;

  PairingRequest({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.pairingCode,
    required this.publicKey,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    'pairingCode': pairingCode,
    'publicKey': publicKey,
  };

  factory PairingRequest.fromJson(Map<String, dynamic> json) {
    return PairingRequest(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      platform: json['platform'] as String,
      pairingCode: json['pairingCode'] as String,
      publicKey: json['publicKey'] as String,
    );
  }
}

/// Pairing response from Android to iOS
class PairingResponse {
  final bool success;
  final String? errorMessage;
  final String? sharedKey; // Encrypted with iOS public key

  PairingResponse({
    required this.success,
    this.errorMessage,
    this.sharedKey,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'errorMessage': errorMessage,
    'sharedKey': sharedKey,
  };

  factory PairingResponse.fromJson(Map<String, dynamic> json) {
    return PairingResponse(
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
      sharedKey: json['sharedKey'] as String?,
    );
  }
}

/// Pairing state for UI
enum PairingState {
  idle,
  generatingCode,
  waitingForScan,
  scanning,
  connecting,
  exchangingKeys,
  paired,
  failed,
}
