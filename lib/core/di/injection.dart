import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // Storage
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);
  
  // Services will be registered in later phases
  // getIt.registerLazySingleton<BLEService>(() => BLEService());
  // getIt.registerLazySingleton<WebSocketService>(() => WebSocketService());
  // getIt.registerLazySingleton<EncryptionService>(() => EncryptionService());
  
  // Repositories will be registered in later phases
  
  // Use cases will be registered in later phases
}
