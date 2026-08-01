import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/devices/data/device_preferences_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('provider route uses stable device-scoped keys', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = DevicePreferencesRepositoryImpl(preferences);

    await repository.setLastProvider('device-1', 'provider-new');
    await repository.setLastModel('device-1', 'model-new');

    expect(repository.getLastProvider('device-1'), 'provider-new');
    expect(repository.getLastModel('device-1'), 'model-new');
    expect(
      preferences.getString('agent_route_device-1_provider'),
      'provider-new',
    );
    expect(
      preferences.getString('agent_route_device-1_model'),
      'model-new',
    );
  });

  test('unrelated preference keys are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'unrelated_device-1_provider': 'provider-stale',
      'unrelated_device-1_model': 'model-stale',
    });
    final repository = DevicePreferencesRepositoryImpl(
      await SharedPreferences.getInstance(),
    );

    expect(repository.getLastProvider('device-1'), isNull);
    expect(repository.getLastModel('device-1'), isNull);
  });
}
