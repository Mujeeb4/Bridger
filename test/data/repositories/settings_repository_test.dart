import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:bridge_phone/data/repositories/settings_repository_impl.dart';
import 'package:bridge_phone/data/datasources/local/database.dart';

@GenerateMocks([AppDatabase])
import 'settings_repository_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepositoryImpl settingsRepository;
  late MockAppDatabase mockDatabase;

  setUp(() {
    mockDatabase = MockAppDatabase();
    settingsRepository = SettingsRepositoryImpl(mockDatabase);
  });

  group('SettingsRepositoryImpl', () {
    group('getSetting', () {
      test('returns value when setting exists', () async {
        when(mockDatabase.getSetting('test_key'))
            .thenAnswer((_) async => 'test_value');

        final result = await settingsRepository.getSetting('test_key');

        expect(result, 'test_value');
        verify(mockDatabase.getSetting('test_key')).called(1);
      });

      test('returns null when setting does not exist', () async {
        when(mockDatabase.getSetting('missing_key'))
            .thenAnswer((_) async => null);

        final result = await settingsRepository.getSetting('missing_key');

        expect(result, isNull);
      });
    });

    group('getBoolSetting', () {
      test('returns true when value is "true"', () async {
        when(mockDatabase.getSetting('bool_key'))
            .thenAnswer((_) async => 'true');

        final result = await settingsRepository.getBoolSetting('bool_key');

        expect(result, true);
      });

      test('returns true when value is "TRUE" (case insensitive)', () async {
        when(mockDatabase.getSetting('bool_key'))
            .thenAnswer((_) async => 'TRUE');

        final result = await settingsRepository.getBoolSetting('bool_key');

        expect(result, true);
      });

      test('returns false when value is "false"', () async {
        when(mockDatabase.getSetting('bool_key'))
            .thenAnswer((_) async => 'false');

        final result = await settingsRepository.getBoolSetting('bool_key');

        expect(result, false);
      });

      test('returns false when value is null', () async {
        when(mockDatabase.getSetting('bool_key'))
            .thenAnswer((_) async => null);

        final result = await settingsRepository.getBoolSetting('bool_key');

        expect(result, false);
      });
    });

    group('getIntSetting', () {
      test('returns parsed integer when value exists', () async {
        when(mockDatabase.getSetting('int_key'))
            .thenAnswer((_) async => '42');

        final result = await settingsRepository.getIntSetting('int_key');

        expect(result, 42);
      });

      test('returns default value when setting is null', () async {
        when(mockDatabase.getSetting('int_key'))
            .thenAnswer((_) async => null);

        final result = await settingsRepository.getIntSetting('int_key', defaultValue: 10);

        expect(result, 10);
      });

      test('returns default value when value is not a number', () async {
        when(mockDatabase.getSetting('int_key'))
            .thenAnswer((_) async => 'not_a_number');

        final result = await settingsRepository.getIntSetting('int_key', defaultValue: 5);

        expect(result, 5);
      });
    });

    group('Connection Settings', () {
      test('getConnectionTimeout returns default when not set', () async {
        when(mockDatabase.getSetting('connection_timeout'))
            .thenAnswer((_) async => null);

        final result = await settingsRepository.getConnectionTimeout();

        expect(result, 30); // Default value
      });

      test('setConnectionTimeout saves value', () async {
        when(mockDatabase.setSetting('connection_timeout', '60'))
            .thenAnswer((_) async {});

        await settingsRepository.setConnectionTimeout(60);

        verify(mockDatabase.setSetting('connection_timeout', '60')).called(1);
      });

      test('getReconnectAttempts returns default when not set', () async {
        when(mockDatabase.getSetting('reconnect_attempts'))
            .thenAnswer((_) async => null);

        final result = await settingsRepository.getReconnectAttempts();

        expect(result, 5); // Default value
      });

      test('getBatteryMode returns default when not set', () async {
        when(mockDatabase.getSetting('battery_mode'))
            .thenAnswer((_) async => null);

        final result = await settingsRepository.getBatteryMode();

        expect(result, 'performance'); // Default value
      });
    });

    group('Security Settings', () {
      test('isEncryptionEnabled returns true by default', () async {
        when(mockDatabase.getSetting('encryption_enabled'))
            .thenAnswer((_) async => null);

        final result = await settingsRepository.isEncryptionEnabled();

        expect(result, true);
      });

      test('isEncryptionEnabled returns false when explicitly disabled', () async {
        when(mockDatabase.getSetting('encryption_enabled'))
            .thenAnswer((_) async => 'false');

        final result = await settingsRepository.isEncryptionEnabled();

        expect(result, false);
      });
    });
  });
}
