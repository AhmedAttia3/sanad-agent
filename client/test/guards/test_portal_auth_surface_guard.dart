// Plan 23 — Guard test enforcing the open-source auth surface contract.
//
// The Flutter client must not:
//   - call any backend auth path (/api/auth/...),
//   - construct device-code / session / mobile-* URLs,
//   - reference provider names (google, apple) or {provider} in auth code,
//   - use backendUrl inside login / refresh flows.
//
// If any of these leak back into the auth feature, this test fails so the
// behavior drift is caught at PR time.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final authFeatureDir = Directory('lib/features/auth');

  test('auth feature directory exists', () {
    expect(authFeatureDir.existsSync(), isTrue);
  });

  test('auth feature does not call backend auth /api/auth/* paths', () {
    final offenders = <String>[];
    final forbiddenPatterns = [
      RegExp(r'/api/auth/'),
      RegExp(r'auth/device/'),
      RegExp(r'auth/mobile/'),
      RegExp(r'auth/session/'),
      RegExp(r'/api/auth/device/start'),
      RegExp(r'/api/auth/device/status'),
      RegExp(r'/api/auth/mobile'),
      RegExp(r'/api/auth/session'),
    ];

    for (final entity in authFeatureDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final pattern in forbiddenPatterns) {
        if (pattern.hasMatch(source)) {
          offenders.add('${entity.path}: matches ${pattern.pattern}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Backend auth paths must not appear in the open-source client. '
          'Offenders:\n${offenders.join('\n')}',
    );
  });

  test('auth feature does not reference identity providers or {provider}', () {
    final offenders = <String>[];
    final forbiddenSubstrings = ['google', 'apple', '{provider}'];

    for (final entity in authFeatureDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final needle in forbiddenSubstrings) {
        if (source.contains(needle)) {
          offenders.add("${entity.path}: mentions '$needle'");
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Identity provider names or {provider} must not appear in the '
          'open-source client. Provider selection belongs to sanad-portal only.\n'
          'Offenders:\n${offenders.join('\n')}',
    );
  });

  test('login/refresh flows use portalUrl, not backendUrl', () {
    final offenders = <String>[];
    for (final entity in authFeatureDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      // Allow `backendUrl` only for non-auth purposes (profile / credits).
      // Detect login/refresh usage by proximity to auth-specific verbs.
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('backendUrl') &&
            (line.contains('/auth') ||
                line.contains('refresh') ||
                line.contains('login') ||
                line.contains('logout') ||
                line.contains('start') ||
                line.contains('status') ||
                line.contains('polling'))) {
          offenders.add('${entity.path}:${i + 1}: $line.trim()');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'backendUrl must not be used for authentication. Use portalUrl '
          'instead. Offenders:\n${offenders.join('\n')}',
    );
  });
}
