import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter/services.dart';
import 'package:bridge_phone/services/contact_sync_service.dart';
import 'package:bridge_phone/domain/repositories/contact_repository.dart';
import 'package:bridge_phone/domain/repositories/settings_repository.dart';
import 'package:bridge_phone/domain/entities/contact.dart';

@GenerateMocks([ContactRepository, SettingsRepository])
import 'contact_sync_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContactSyncService contactSyncService;
  late MockContactRepository mockContactRepository;
  late MockSettingsRepository mockSettingsRepository;

  setUp(() {
    mockContactRepository = MockContactRepository();
    mockSettingsRepository = MockSettingsRepository();
    contactSyncService = ContactSyncService(
      mockContactRepository,
      mockSettingsRepository,
    );
  });

  group('ContactSyncService', () {
    group('getLastSyncTime', () {
      test('returns null when no sync has occurred', () async {
        when(mockSettingsRepository.getSetting('lastContactSync'))
            .thenAnswer((_) async => null);

        final result = await contactSyncService.getLastSyncTime();

        expect(result, isNull);
        verify(mockSettingsRepository.getSetting('lastContactSync')).called(1);
      });

      test('returns DateTime when sync has occurred', () async {
        final timestamp = DateTime.now().toIso8601String();
        when(mockSettingsRepository.getSetting('lastContactSync'))
            .thenAnswer((_) async => timestamp);

        final result = await contactSyncService.getLastSyncTime();

        expect(result, isNotNull);
        expect(result, isA<DateTime>());
      });

      test('returns null for invalid timestamp', () async {
        when(mockSettingsRepository.getSetting('lastContactSync'))
            .thenAnswer((_) async => 'invalid');

        final result = await contactSyncService.getLastSyncTime();

        expect(result, isNull);
      });
    });

    group('getContactDisplayName', () {
      setUp(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.bridge.phone/contacts'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getContactByPhoneNumber') {
              final args = methodCall.arguments as Map;
              if (args['phoneNumber'] == '+9999999999') {
                return null;
              }
              return {'name': 'Device Contact', 'phoneNumber': args['phoneNumber']};
            }
            return null;
          },
        );
      });

      test('returns contact name when found locally', () async {
        final testContact = ContactEntity(
          id: 1,
          name: 'John Doe',
          phoneNumber: '+1234567890',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        when(mockContactRepository.getContactByPhoneNumber('+1234567890'))
            .thenAnswer((_) async => testContact);

        final result = await contactSyncService.getContactDisplayName('+1234567890');

        expect(result, 'John Doe');
      });

      test('returns null when contact not found locally or on device', () async {
        when(mockContactRepository.getContactByPhoneNumber('+9999999999'))
            .thenAnswer((_) async => null);

        final result = await contactSyncService.getContactDisplayName('+9999999999');

        expect(result, isNull);
      });
    });
  });
}
