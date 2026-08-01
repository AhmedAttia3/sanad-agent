import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/core/theme/app_color_scheme.dart';

void main() {
  test('light and dark themes use the application primary color', () {
    const applicationPrimary = Color(0xFF60A5FA);
    const onApplicationPrimary = Color(0xFF0A0A0A);

    expect(AppColorScheme.light.primary, applicationPrimary);
    expect(AppColorScheme.dark.primary, applicationPrimary);
    expect(AppColorScheme.light.onPrimary, onApplicationPrimary);
    expect(AppColorScheme.dark.onPrimary, onApplicationPrimary);
  });
}
