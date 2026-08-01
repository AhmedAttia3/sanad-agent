import 'package:shared_preferences/shared_preferences.dart';

class StorageModule {
  Future<SharedPreferences> prefs() {
    return SharedPreferences.getInstance();
  }
}
