import '../models/pairing_models.dart';

/// Repository interface for managing paired devices
abstract class PairingRepository {
  /// Get the currently paired device (if any)
  Future<PairedDevice?> getPairedDevice();

  /// Save a paired device
  Future<void> savePairedDevice(PairedDevice device);

  /// Remove the paired device
  Future<void> removePairedDevice();

  /// Check if a device is paired
  Future<bool> isPaired();

  /// Update last seen timestamp
  Future<void> updateLastSeen(DateTime lastSeen);

  /// Get the current pairing code (Android only)
  Future<PairingCode?> getCurrentPairingCode();

  /// Save a new pairing code (Android only)
  Future<void> savePairingCode(PairingCode code);

  /// Clear the current pairing code
  Future<void> clearPairingCode();

  /// Validate a pairing code
  Future<bool> validatePairingCode(String code);
}
