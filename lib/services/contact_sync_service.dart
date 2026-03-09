import 'package:flutter/services.dart';

import '../domain/entities/contact.dart';
import '../domain/repositories/contact_repository.dart';
import '../domain/repositories/settings_repository.dart';

/// Service for syncing contacts from Android device to local database
class ContactSyncService {
  static const _channel = MethodChannel('com.bridge.phone/contacts');
  
  final ContactRepository _contactRepository;
  final SettingsRepository _settingsRepository;
  
  bool _isSyncing = false;
  
  ContactSyncService(this._contactRepository, this._settingsRepository);
  
  /// Check if sync is currently in progress
  bool get isSyncing => _isSyncing;
  
  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = await _settingsRepository.getSetting('lastContactSync');
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }
  
  /// Sync contacts from Android device
  /// Returns the number of contacts synced
  Future<int> syncContacts({
    void Function(int current, int total)? onProgress,
  }) async {
    if (_isSyncing) {
      throw StateError('Sync already in progress');
    }
    
    _isSyncing = true;
    
    try {
      // Get contacts from Android
      final List<dynamic> rawContacts = await _channel.invokeMethod('getContacts');
      
      final total = rawContacts.length;
      var synced = 0;
      
      for (final raw in rawContacts) {
        final map = Map<String, dynamic>.from(raw as Map);
        
        final phoneNumber = map['phoneNumber'] as String?;
        if (phoneNumber == null || phoneNumber.isEmpty) continue;
        
        // Check if contact already exists
        final existing = await _contactRepository.getContactByPhoneNumber(phoneNumber);
        
        final contact = ContactEntity(
          id: existing?.id ?? 0,
          name: map['name'] as String? ?? 'Unknown',
          phoneNumber: phoneNumber,
          photoUrl: map['photoUrl'] as String?,
          isFavorite: existing?.isFavorite ?? false,
          lastContactedAt: existing?.lastContactedAt,
          createdAt: existing?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        if (existing != null) {
          // Update existing contact
          await _contactRepository.updateContact(contact);
        } else {
          // Save new contact
          await _contactRepository.saveContact(contact);
        }
        
        synced++;
        onProgress?.call(synced, total);
      }
      
      // Save last sync time
      await _settingsRepository.setSetting(
        'lastContactSync',
        DateTime.now().toIso8601String(),
      );
      
      return synced;
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Get contact count on device (without full sync)
  Future<int> getDeviceContactCount() async {
    return await _channel.invokeMethod('getContactCount') ?? 0;
  }
  
  /// Get contact display name for caller ID
  Future<String?> getContactDisplayName(String phoneNumber) async {
    // First check local database
    final local = await _contactRepository.getContactByPhoneNumber(phoneNumber);
    if (local != null) {
      return local.name;
    }
    
    // Fall back to device contacts
    final result = await _channel.invokeMethod('getContactByPhoneNumber', {
      'phoneNumber': phoneNumber,
    });
    
    if (result != null) {
      final map = Map<String, dynamic>.from(result as Map);
      return map['name'] as String?;
    }
    
    return null;
  }
}
