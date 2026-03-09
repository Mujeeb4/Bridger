import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Database
import '../../data/datasources/local/database.dart';

// Services
import '../../services/encryption_service.dart';
import '../../services/ble_service.dart';
import '../../services/pairing_service.dart';
import '../../services/hotspot_service.dart';
import '../../services/websocket_service.dart';
import '../../services/communication_service.dart';
import '../../services/sms_service.dart';
import '../../services/call_service.dart';
import '../../services/notification_service.dart';
import '../../services/audio_service.dart';
import '../../services/background_service.dart';
import '../../services/command_dispatcher_service.dart';

// Repositories - Interfaces
import '../../domain/repositories/sms_repository.dart';
import '../../domain/repositories/call_repository.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/pairing_repository.dart';

// Repositories - Implementations
import '../../data/repositories/sms_repository_impl.dart';
import '../../data/repositories/call_repository_impl.dart';
import '../../data/repositories/contact_repository_impl.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/pairing_repository_impl.dart';

final getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // ============================================================================
  // Core Storage
  // ============================================================================

  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);

  // ============================================================================
  // Database
  // ============================================================================

  final database = AppDatabase();
  getIt.registerSingleton<AppDatabase>(database);

  // ============================================================================
  // Services
  // ============================================================================

  final encryptionService = EncryptionService(secureStorage);
  await encryptionService.initialize();
  getIt.registerSingleton<EncryptionService>(encryptionService);

  // BLE Service - eagerly initialize so native layer is ready
  final bleService = BleService();
  await bleService.initialize();
  getIt.registerSingleton<BleService>(bleService);

  // Pairing Service
  getIt.registerLazySingleton<PairingRepository>(
    () => PairingRepositoryImpl(secureStorage),
  );

  getIt.registerLazySingleton<PairingService>(
    () => PairingService(
      pairingRepository: getIt<PairingRepository>(),
      settingsRepository: getIt<SettingsRepository>(),
      bleService: getIt<BleService>(),
      encryptionService: getIt<EncryptionService>(),
      communicationService: getIt<CommunicationService>(),
    ),
  );

  // Hotspot Service
  getIt.registerLazySingleton<HotspotService>(
    () => HotspotService(communicationService: getIt<CommunicationService>()),
  );

  // WebSocket Service
  getIt.registerLazySingleton<WebSocketService>(() => WebSocketService());

  // Communication Service (unified API)
  getIt.registerLazySingleton<CommunicationService>(
    () => CommunicationService(
      webSocketService: getIt<WebSocketService>(),
      bleService: getIt<BleService>(),
      encryptionService: getIt<EncryptionService>(),
    ),
  );

  // SMS Service
  getIt.registerLazySingleton<SMSService>(
    () => SMSService(communicationService: getIt<CommunicationService>()),
  );

  // Call Service
  getIt.registerLazySingleton<CallService>(
    () => CallService(
      communicationService: getIt<CommunicationService>(),
      audioService: getIt<AudioService>(),
    ),
  );

  // Notification Service
  getIt.registerLazySingleton<NotificationService>(
    () => NotificationService(
        communicationService: getIt<CommunicationService>()),
  );

  // Audio Streaming Service
  getIt.registerLazySingleton<AudioService>(
    () => AudioService(encryptionService: getIt<EncryptionService>()),
  );

  // Background Service
  getIt.registerLazySingleton<BackgroundService>(
    () => BackgroundService(),
  );

  // Command Dispatcher (Android only — routes iOS commands to native handlers)
  getIt.registerLazySingleton<CommandDispatcherService>(
    () => CommandDispatcherService(
      communicationService: getIt<CommunicationService>(),
      smsService: getIt<SMSService>(),
      callService: getIt<CallService>(),
      hotspotService: getIt<HotspotService>(),
      notificationService: getIt<NotificationService>(),
    ),
  );

  // ============================================================================
  // Repositories
  // ============================================================================

  getIt.registerLazySingleton<SMSRepository>(
    () => SMSRepositoryImpl(getIt<AppDatabase>(), getIt<EncryptionService>()),
  );

  getIt.registerLazySingleton<CallRepository>(
    () => CallRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<ContactRepository>(
    () => ContactRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(getIt<AppDatabase>()),
  );

  // ============================================================================
  // Use Cases (to be registered in later phases)
  // ============================================================================
}
