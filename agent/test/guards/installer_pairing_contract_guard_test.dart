import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'installers accept only the initial pairing token and start the service',
    () {
      final posix = File('../scripts/install.sh').readAsStringSync();
      final windows = File('../scripts/install.ps1').readAsStringSync();

      expect(posix, contains('--pairing-token'));
      expect(posix, contains('login --token "\$PAIRING_TOKEN"'));
      expect(posix, contains('service install'));
      expect(windows, contains('[string]\$PairingToken'));
      expect(windows, contains('login --token \$PairingToken'));
      expect(windows, contains('service install'));
      expect(
        posix.indexOf('login --token "\$PAIRING_TOKEN"'),
        lessThan(posix.indexOf('service install')),
      );
      expect(
        windows.indexOf('login --token \$PairingToken'),
        lessThan(windows.indexOf('service install')),
      );

      expect(posix, isNot(contains('device_token')));
      expect(windows, isNot(contains('device_token')));
    },
  );
}
