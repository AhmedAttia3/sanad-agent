import 'package:sanad_client/core/config/app_config.dart';
import 'package:sanad_client/core/di/injection.dart';
import 'package:sanad_client/core/presentation/bloc/theme/theme_cubit.dart';
import 'package:sanad_client/core/presentation/state/app_state.dart';
import 'package:sanad_client/features/conversations/data/persistence/conversation_cache_persistor.dart';
import 'package:sanad_client/core/utils/logger.dart';
import 'package:sanad_client/infrastructure/platform/window_manager_service.dart';
import 'package:sanad_client/utils/windows_scheme_registrar.dart';
import 'package:sanad_client/utils/inspector_helper.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppBootstrapResult {
  final ThemeMode initialTheme;

  const AppBootstrapResult({required this.initialTheme});
}

class AppBootstrap {
  static Future<AppBootstrapResult> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final preferencesPrefix = AppConfig.sharedPreferencesPrefix;
    if (preferencesPrefix.isNotEmpty) {
      SharedPreferences.setPrefix(preferencesPrefix);
    }
    initClientLogger();
    setupInspectorListener();

    final initialTheme = await ThemeCubit.getSavedTheme();
    await Future.wait([
      WindowManagerService.initialize(),
      registerWindowsScheme(),
    ]);

    await configureDependencies();
    await getIt<AppState>().ready;
    await getIt<ConversationCachePersistor>().hydrate();

    return AppBootstrapResult(initialTheme: initialTheme);
  }
}
