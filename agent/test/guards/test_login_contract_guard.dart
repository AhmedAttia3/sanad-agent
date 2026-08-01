// Plan 23 — Guard test enforcing the open-source CLI/daemon auth surface.
//
// `bin/login.dart` and `AuthManager` must not:
//   - mention any backend auth path (/api/auth/*),
//   - construct device-code / session / mobile-* URLs,
//   - reference provider names (google, apple) or {provider},
//   - call gatewayUrl for auth (refresh must go through portalUrl).

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final files = [
    File('bin/login.dart'),
    File('lib/core/auth/auth_manager.dart'),
  ];

  test('guard target files exist', () {
    for (final f in files) {
      expect(f.existsSync(), isTrue, reason: '${f.path} should exist');
    }
  });

  test('login.dart and AuthManager do not call backend auth paths', () {
    final offenders = <String>[];
    final forbiddenPatterns = [
      RegExp(r'/api/auth/'),
      RegExp(r'auth/device/'),
      RegExp(r'auth/mobile/'),
      RegExp(r'auth/session/'),
      RegExp(r'/api/auth/device'),
      RegExp(r'/api/auth/session'),
      RegExp(r'/api/auth/mobile'),
    ];
    for (final f in files) {
      final source = f.readAsStringSync();
      for (final p in forbiddenPatterns) {
        if (p.hasMatch(source)) {
          offenders.add('${f.path}: matches ${p.pattern}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Backend auth paths must not appear in CLI/daemon login/refresh. '
          'Offenders:\n${offenders.join('\n')}',
    );
  });

  test('login.dart and AuthManager do not reference identity providers', () {
    final offenders = <String>[];
    final forbidden = ['google', 'apple', '{provider}'];
    for (final f in files) {
      final source = f.readAsStringSync();
      for (final needle in forbidden) {
        if (source.contains(needle)) {
          offenders.add("${f.path}: mentions '$needle'");
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Provider names or {provider} must not appear in CLI login. '
          'Offenders:\n${offenders.join('\n')}',
    );
  });

  test(
    'login.dart and AuthManager use portalUrl, not gatewayUrl, for auth',
    () {
      final offenders = <String>[];
      for (final f in files) {
        final source = f.readAsStringSync();
        if (source.contains('gatewayUrl') &&
            source.toLowerCase().contains(
              RegExp(r'auth|login|refresh|token'),
            )) {
          offenders.add('${f.path}: uses gatewayUrl inside the auth path');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'gatewayUrl must not be used for authentication. Use portalUrl. '
            'Offenders:\n${offenders.join('\n')}',
      );
    },
  );
}
