import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../constants.dart';

class AuthManager {
  final _logger = Logger('AuthManager');
  String? _accessToken;
  String? _refreshToken;
  String? _hardwareId;
  String? _deviceToken;
  String? _pairingToken;
  String? _pendingDeviceToken;

  String? get accessToken => _accessToken;
  String? get hardwareId => _hardwareId;
  String? get refreshToken => _refreshToken;
  String? get deviceToken => _deviceToken;
  String? get pairingToken => _pairingToken;
  String? get pendingDeviceToken => _pendingDeviceToken;
  bool get hasPendingDevicePairing =>
      _pairingToken != null && _pendingDeviceToken != null;

  Future<void> initialize() async {
    final sanadHome = getSanadHome();
    final authFile = File(p.join(sanadHome, 'auth.json'));

    if (await authFile.exists()) {
      try {
        final content = await authFile.readAsString();
        if (content.trim().isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          _accessToken = data['access_token'];
          _refreshToken = data['refresh_token'];
          _hardwareId = data['hardware_id'];
          _deviceToken = data['device_token'];
          _pairingToken = data['pairing_token'];
          _pendingDeviceToken = data['pending_device_token'];
        }
      } catch (e) {
        // Silently fail if file is malformed
      }
    }

    if (_hardwareId == null || _hardwareId!.isEmpty) {
      _hardwareId = const Uuid().v4();
      await _saveAuth();
    }
  }

  bool get isAuthenticated =>
      _accessToken != null || _deviceToken != null || hasPendingDevicePairing;

  Future<void> saveDeviceToken(String token) async {
    _deviceToken = token;
    _pairingToken = null;
    _pendingDeviceToken = null;
    await _saveAuth();
  }

  Future<void> prepareDevicePairing(String pairingToken) async {
    if (pairingToken.isEmpty) {
      throw ArgumentError.value(
        pairingToken,
        'pairingToken',
        'must not be empty',
      );
    }
    _pairingToken = pairingToken;
    _pendingDeviceToken = _generateDeviceToken();
    _deviceToken = null;
    await _saveAuth();
  }

  Future<bool> completeDevicePairing() async {
    final pendingToken = _pendingDeviceToken;
    if (pendingToken == null || _pairingToken == null) return false;

    _deviceToken = pendingToken;
    _pairingToken = null;
    _pendingDeviceToken = null;
    await _saveAuth();
    return true;
  }

  Future<void> saveUserTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _saveAuth();
  }

  Future<bool> refreshAccessToken(String portalUrl) async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      _logger.warning('Refresh token is null or empty');
      return false;
    }

    try {
      // Plan 23: refresh goes through the portal only. The CLI/daemon must
      // never call backend auth endpoints directly.
      final url = Uri.parse('$portalUrl/auth/refresh');
      _logger.info('Calling portal refresh endpoint...');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'];
        if (data.containsKey('refresh_token')) {
          _refreshToken = data['refresh_token'];
        }

        await _saveAuth();
        _logger.info('Token refreshed and saved successfully.');
        return true;
      } else {
        _logger.warning(
          'Refresh failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      _logger.severe('Error during refresh: $e');
    }
    return false;
  }

  Future<void> _saveAuth() async {
    final sanadHome = getSanadHome();
    await Directory(sanadHome).create(recursive: true);
    final authFile = File(p.join(sanadHome, 'auth.json'));

    final data = <String, dynamic>{};
    if (await authFile.exists()) {
      try {
        final content = await authFile.readAsString();
        if (content.trim().isNotEmpty) {
          data.addAll(jsonDecode(content) as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    data.remove('access_token');
    data.remove('refresh_token');
    data.remove('hardware_id');
    data.remove('device_token');
    data.remove('pairing_token');
    data.remove('pending_device_token');

    if (_accessToken != null) data['access_token'] = _accessToken;
    if (_refreshToken != null) data['refresh_token'] = _refreshToken;
    if (_hardwareId != null) data['hardware_id'] = _hardwareId;
    if (_deviceToken != null) data['device_token'] = _deviceToken;
    if (_pairingToken != null) data['pairing_token'] = _pairingToken;
    if (_pendingDeviceToken != null) {
      data['pending_device_token'] = _pendingDeviceToken;
    }

    await authFile.writeAsString(jsonEncode(data));
    await _secureAuthFile(authFile);
  }

  Future<void> _secureAuthFile(File authFile) async {
    if (Platform.isWindows) return;
    try {
      await Process.run('chmod', ['600', authFile.path]);
    } catch (e) {
      _logger.warning('Failed to set auth.json permissions: $e');
    }
  }

  /// Clear session
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _deviceToken = null;
    _pairingToken = null;
    _pendingDeviceToken = null;
    final sanadHome = getSanadHome();
    final authFile = File(p.join(sanadHome, 'auth.json'));
    if (await authFile.exists()) {
      try {
        final content = await authFile.readAsString();
        if (content.trim().isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          data.remove('access_token');
          data.remove('refresh_token');
          data.remove('device_token');
          data.remove('pairing_token');
          data.remove('pending_device_token');
          await authFile.writeAsString(jsonEncode(data));
          await _secureAuthFile(authFile);
        } else {
          await authFile.delete();
        }
      } catch (_) {
        await authFile.delete();
      }
    }
  }

  String _generateDeviceToken() {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final value = List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return 'sanad_$value';
  }
}
