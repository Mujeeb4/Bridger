import 'package:equatable/equatable.dart';

/// Represents a contact entity in the domain layer
class ContactEntity extends Equatable {
  final int id;
  final String name;
  final String phoneNumber;
  final String? photoUrl;
  final bool isFavorite;
  final DateTime? lastContactedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContactEntity({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.photoUrl,
    this.isFavorite = false,
    this.lastContactedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get initials from contact name (for avatar display)
  String get initials {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    } else {
      return '${parts[0].substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
    }
  }

  ContactEntity copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    String? photoUrl,
    bool? isFavorite,
    DateTime? lastContactedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phoneNumber,
        photoUrl,
        isFavorite,
        lastContactedAt,
        createdAt,
        updatedAt,
      ];
}
