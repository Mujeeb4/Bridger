import 'package:drift/drift.dart';

import '../../datasources/local/database.dart';
import '../../../domain/entities/contact.dart';
import '../../../domain/repositories/contact_repository.dart';

/// Implementation of ContactRepository using Drift database
class ContactRepositoryImpl implements ContactRepository {
  final AppDatabase _database;

  ContactRepositoryImpl(this._database);

  @override
  Future<List<ContactEntity>> getAllContacts() async {
    final contacts = await _database.getAllContacts();
    return contacts.map(_mapToEntity).toList();
  }

  @override
  Future<List<ContactEntity>> getFavoriteContacts() async {
    final contacts = await _database.getFavoriteContacts();
    return contacts.map(_mapToEntity).toList();
  }

  @override
  Future<ContactEntity?> getContactByPhoneNumber(String phoneNumber) async {
    final contact = await _database.getContactByPhoneNumber(phoneNumber);
    return contact != null ? _mapToEntity(contact) : null;
  }

  @override
  Future<List<ContactEntity>> searchContacts(String query) async {
    final lowerQuery = query.toLowerCase();
    final contacts = await (_database.select(_database.contacts)
      ..where((c) => 
          c.name.lower().contains(lowerQuery) |
          c.phoneNumber.contains(query))
      ..orderBy([(c) => OrderingTerm.asc(c.name)])
    ).get();
    return contacts.map(_mapToEntity).toList();
  }

  @override
  Future<ContactEntity> saveContact(ContactEntity contact) async {
    final id = await _database.insertContact(
      ContactsCompanion.insert(
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        photoUrl: Value(contact.photoUrl),
        isFavorite: Value(contact.isFavorite),
        lastContactedAt: Value(contact.lastContactedAt),
      ),
    );
    return contact.copyWith(
      id: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateContact(ContactEntity contact) async {
    await _database.updateContact(Contact(
      id: contact.id,
      name: contact.name,
      phoneNumber: contact.phoneNumber,
      photoUrl: contact.photoUrl,
      isFavorite: contact.isFavorite,
      lastContactedAt: contact.lastContactedAt,
      createdAt: contact.createdAt,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<void> deleteContact(int id) async {
    await _database.deleteContact(id);
  }

  @override
  Future<void> toggleFavorite(int id) async {
    final contact = await (_database.select(_database.contacts)
      ..where((c) => c.id.equals(id))
    ).getSingleOrNull();
    
    if (contact != null) {
      await (_database.update(_database.contacts)
        ..where((c) => c.id.equals(id))
      ).write(ContactsCompanion(
        isFavorite: Value(!contact.isFavorite),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  @override
  Future<void> updateLastContacted(int id, DateTime timestamp) async {
    await (_database.update(_database.contacts)
      ..where((c) => c.id.equals(id))
    ).write(ContactsCompanion(
      lastContactedAt: Value(timestamp),
      updatedAt: Value(DateTime.now()),
    ));
  }

  @override
  Future<int> importFromDevice() async {
    // This will be implemented with platform channels in a later phase
    // when we integrate with the native contact providers
    throw UnimplementedError('Contact import will be implemented in Phase 16');
  }

  ContactEntity _mapToEntity(Contact contact) {
    return ContactEntity(
      id: contact.id,
      name: contact.name,
      phoneNumber: contact.phoneNumber,
      photoUrl: contact.photoUrl,
      isFavorite: contact.isFavorite,
      lastContactedAt: contact.lastContactedAt,
      createdAt: contact.createdAt,
      updatedAt: contact.updatedAt,
    );
  }
}
