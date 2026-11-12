import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delitopia_v2/src/core/constants/app_constants.dart';
import 'package:delitopia_v2/src/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService token storage hardening', () {
    test('saveAuthToken stores exclusively in secure storage and removes prefs copy', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAuthToken: 'stale-plaintext-token',
      });
      FlutterSecureStorage.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      const secureStorage = FlutterSecureStorage();
      final service = StorageService(prefs, secureStorage);

      await service.saveAuthToken('jwt-secret-123');

      expect(service.getAuthToken(), equals('jwt-secret-123'));
      expect(
        await secureStorage.read(key: AppConstants.keyAuthToken),
        equals('jwt-secret-123'),
      );
      expect(prefs.getString(AppConstants.keyAuthToken), isNull);
    });

    test('initialize migrates legacy SharedPreferences token and deletes plaintext copy', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyAuthToken: 'legacy-token-456',
      });
      FlutterSecureStorage.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      const secureStorage = FlutterSecureStorage();
      final service = StorageService(prefs, secureStorage);

      await service.initialize();

      expect(service.getAuthToken(), equals('legacy-token-456'));
      expect(
        await secureStorage.read(key: AppConstants.keyAuthToken),
        equals('legacy-token-456'),
      );
      expect(prefs.getString(AppConstants.keyAuthToken), isNull);
    });
  });
}

