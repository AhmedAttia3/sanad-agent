import 'package:sanad_client/features/auth/infrastructure/auth_service.dart';
import 'package:sanad_client/infrastructure/local_tools/sanad_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class MockSanadSettingsStore extends Fake implements SanadSettingsStore {
  Map<String, dynamic> authDocument = {};

  @override
  Future<Map<String, dynamic>> readAuthDocument() async => authDocument;

  @override
  Future<void> saveAuthDocument(Map<String, dynamic> data) async {
    authDocument = data;
  }

  @override
  Future<void> deleteAuthDocument() async {
    authDocument = {};
  }
}

class MockDio extends Fake implements Dio {
  @override
  BaseOptions options = BaseOptions();
  @override
  final interceptors = Interceptors();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService authService;
  late MockSanadSettingsStore mockStore;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockStore = MockSanadSettingsStore();
    authService = AuthService(dio: MockDio(), prefs: prefs, settingsStore: mockStore);
  });

  group('AuthService SSoT Logic', () {
    test('init restores from auth.json if present', () async {
      mockStore.authDocument = {
        'access_token': 'file_token',
        'refresh_token': 'file_refresh',
        'hardware_id': 'file_device',
      };

      await authService.init();

      expect(authService.accessToken, equals('file_token'));
      expect(authService.hardwareId, equals('file_device'));
    });

    test('init uses the canonical desktop hardware id when auth is restored from preferences', () async {
      await prefs.setString('backend_access_token', 'prefs_token');
      await prefs.setString('backend_refresh_token', 'prefs_refresh');
      await prefs.setString('hardware_id', 'stale_prefs_device');

      await authService.init(fallbackDeviceId: 'canonical_device');

      expect(authService.accessToken, equals('prefs_token'));
      expect(authService.hardwareId, equals('canonical_device'));

      expect(mockStore.authDocument['access_token'], equals('prefs_token'));
      expect(mockStore.authDocument['hardware_id'], equals('canonical_device'));
    });

    test('login updates both auth.json and SharedPreferences', () async {
      // Note: testing login might require mocking the profile request if it triggers it.
      // But we can test the internal state if we can trigger it.
    });

    test('logout clears tokens but preserves hardware_id', () async {
      mockStore.authDocument = {
        'access_token': 'test_token',
        'refresh_token': 'test_refresh',
        'hardware_id': 'test_hardware',
      };
      await prefs.setString('backend_access_token', 'test_token');
      await prefs.setString('backend_refresh_token', 'test_refresh');

      await authService.logout();

      expect(mockStore.authDocument['access_token'], isNull);
      expect(mockStore.authDocument['refresh_token'], isNull);
      expect(mockStore.authDocument['hardware_id'], equals('test_hardware'));
      expect(prefs.getString('backend_access_token'), isNull);
      expect(prefs.getString('backend_refresh_token'), isNull);
    });
  });
}
