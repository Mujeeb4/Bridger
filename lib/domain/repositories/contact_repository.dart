import '../entities/contact.dart';

/// Repository interface for contact operations
abstract class ContactRepository {
  /// Get all contacts sorted alphabetically
  Future<List<ContactEntity>> getAllContacts();

  /// Get favorite contacts
  Future<List<ContactEntity>> getFavoriteContacts();

  /// Get a contact by phone number
  Future<ContactEntity?> getContactByPhoneNumber(String phoneNumber);

  /// Search contacts by name or phone number
  Future<List<ContactEntity>> searchContacts(String query);

  /// Save a new contact
  Future<ContactEntity> saveContact(ContactEntity contact);

  /// Update an existing contact
  Future<void> updateContact(ContactEntity contact);

  /// Delete a contact
  Future<void> deleteContact(int id);

  /// Toggle favorite status
  Future<void> toggleFavorite(int id);

  /// Update last contacted time
  Future<void> updateLastContacted(int id, DateTime timestamp);

  /// Import contacts from device
  Future<int> importFromDevice();
}
