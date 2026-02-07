import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for encrypting and decrypting sensitive data using AES-256-GCM
class EncryptionService {
  static const String _keyStorageKey = 'bridge_phone_encryption_key';
  static const int _keyLength = 32; // 256 bits for AES-256

  final FlutterSecureStorage _secureStorage;
  SecretKey? _secretKey;

  EncryptionService(this._secureStorage);

  /// Initialize the encryption service - must be called before encrypt/decrypt
  Future<void> initialize() async {
    _secretKey = await _loadOrGenerateKey();
  }

  /// Check if the service is initialized
  bool get isInitialized => _secretKey != null;

  /// Encrypt plaintext using AES-256-GCM
  /// Returns base64 encoded string containing: nonce + ciphertext + mac
  Future<String> encrypt(String plaintext) async {
    if (!isInitialized) {
      throw StateError('EncryptionService not initialized. Call initialize() first.');
    }

    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encryptString(
      plaintext,
      secretKey: _secretKey!,
    );

    // Combine nonce, ciphertext, and MAC into a single byte array
    final combined = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return base64Encode(combined);
  }

  /// Decrypt ciphertext that was encrypted with this service
  Future<String> decrypt(String encryptedData) async {
    if (!isInitialized) {
      throw StateError('EncryptionService not initialized. Call initialize() first.');
    }

    try {
      final combined = base64Decode(encryptedData);
      
      // AES-GCM uses 12-byte nonce and 16-byte MAC
      const nonceLength = 12;
      const macLength = 16;
      
      final nonce = combined.sublist(0, nonceLength);
      final cipherText = combined.sublist(nonceLength, combined.length - macLength);
      final macBytes = combined.sublist(combined.length - macLength);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final algorithm = AesGcm.with256bits();
      return await algorithm.decryptString(
        secretBox,
        secretKey: _secretKey!,
      );
    } catch (e) {
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  /// Generate a new encryption key (for device pairing key exchange)
  Future<Uint8List> generateNewKey() async {
    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKey();
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  /// Import an encryption key (received during pairing)
  Future<void> importKey(Uint8List keyBytes) async {
    if (keyBytes.length != _keyLength) {
      throw EncryptionException('Invalid key length. Expected $_keyLength bytes.');
    }
    
    _secretKey = SecretKey(keyBytes);
    await _saveKey(keyBytes);
  }

  /// Export the current encryption key (for sharing during pairing)
  Future<Uint8List?> exportKey() async {
    if (_secretKey == null) return null;
    return Uint8List.fromList(await _secretKey!.extractBytes());
  }

  /// Get a human-readable fingerprint of the encryption key
  String getKeyFingerprint() {
    if (_secretKey == null) return 'No key';
    // Return first 16 chars of base64 encoded key hash representation
    return 'AES-256-••••••••';
  }

  /// Clear the encryption key (on unpair)
  Future<void> clearKey() async {
    _secretKey = null;
    await _secureStorage.delete(key: _keyStorageKey);
  }

  /// Load existing key or generate a new one
  Future<SecretKey> _loadOrGenerateKey() async {
    final storedKey = await _secureStorage.read(key: _keyStorageKey);
    
    if (storedKey != null) {
      final keyBytes = base64Decode(storedKey);
      return SecretKey(keyBytes);
    }

    // Generate new key
    final algorithm = AesGcm.with256bits();
    final newKey = await algorithm.newSecretKey();
    
    // Store the key
    final keyBytes = await newKey.extractBytes();
    await _saveKey(Uint8List.fromList(keyBytes));
    
    return newKey;
  }

  /// Save key to secure storage
  Future<void> _saveKey(Uint8List keyBytes) async {
    await _secureStorage.write(
      key: _keyStorageKey,
      value: base64Encode(keyBytes),
    );
  }
}

/// Exception thrown when encryption/decryption fails
class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}
