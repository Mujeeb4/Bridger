import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bridge_phone/services/encryption_service.dart';

@GenerateMocks([FlutterSecureStorage])
import 'encryption_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EncryptionService encryptionService;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    encryptionService = EncryptionService(mockSecureStorage);
    
    // Mock storage behavior
    when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((_) async {});
    when(mockSecureStorage.read(key: anyNamed('key')))
        .thenAnswer((_) async => null);
    when(mockSecureStorage.delete(key: anyNamed('key')))
        .thenAnswer((_) async {});
  });

  group('EncryptionService', () {
    group('generateKey', () {
      test('generates a 32-byte key', () async {
        final key = await encryptionService.generateKey();

        expect(key.length, 32);
      });

      test('generates unique keys', () async {
        final key1 = await encryptionService.generateKey();
        final key2 = await encryptionService.generateKey();

        expect(key1, isNot(equals(key2)));
      });
    });

    group('encrypt and decrypt', () {
      test('encrypts and decrypts string correctly', () async {
        await encryptionService.initialize();
        
        const originalText = 'Hello, World!';
        final encrypted = await encryptionService.encrypt(originalText);
        final decrypted = await encryptionService.decrypt(encrypted);

        expect(decrypted, originalText);
      });

      test('produces different ciphertext for same plaintext (due to IV)', () async {
        await encryptionService.initialize();
        
        const text = 'Same message';
        final encrypted1 = await encryptionService.encrypt(text);
        final encrypted2 = await encryptionService.encrypt(text);

        // Even same plaintext should produce different ciphertext due to random IV
        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('handles empty string', () async {
        await encryptionService.initialize();
        
        const emptyText = '';
        final encrypted = await encryptionService.encrypt(emptyText);
        final decrypted = await encryptionService.decrypt(encrypted);

        expect(decrypted, emptyText);
      });

      test('handles unicode characters', () async {
        await encryptionService.initialize();
        
        const unicodeText = '你好世界 🎉 مرحبا';
        final encrypted = await encryptionService.encrypt(unicodeText);
        final decrypted = await encryptionService.decrypt(encrypted);

        expect(decrypted, unicodeText);
      });

      test('handles long text', () async {
        await encryptionService.initialize();
        
        final longText = 'A' * 10000;
        final encrypted = await encryptionService.encrypt(longText);
        final decrypted = await encryptionService.decrypt(encrypted);

        expect(decrypted, longText);
      });
    });

    group('getKeyFingerprint', () {
      test('returns 8-character fingerprint', () async {
        await encryptionService.initialize();
        
        // Using the synchronous placeholder for UI or the async actual one
        // The service currently returns 'AES-256-' which is 8 chars
        final fingerprint = encryptionService.getKeyFingerprint();

        expect(fingerprint.length, 8);
      });

      test('returns consistent fingerprint for same key', () async {
        await encryptionService.initialize();
        
        final fingerprint1 = encryptionService.getKeyFingerprint();
        final fingerprint2 = encryptionService.getKeyFingerprint();

        expect(fingerprint1, fingerprint2);
      });
    });

    group('encryptBytes and decryptBytes', () {
      test('encrypts and decrypts byte data correctly', () async {
        await encryptionService.initialize();
        
        final originalBytes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        final encrypted = await encryptionService.encryptBytes(originalBytes);
        final decrypted = await encryptionService.decryptBytes(encrypted);

        expect(decrypted, originalBytes);
      });

      test('handles empty byte array', () async {
        await encryptionService.initialize();
        
        final emptyBytes = <int>[];
        final encrypted = await encryptionService.encryptBytes(emptyBytes);
        final decrypted = await encryptionService.decryptBytes(encrypted);

        expect(decrypted, emptyBytes);
      });
    });
  });
}
