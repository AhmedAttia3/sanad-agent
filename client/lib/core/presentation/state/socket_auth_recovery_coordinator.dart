import 'dart:async';

import 'package:sanad_client/features/auth/infrastructure/auth_service.dart';
import 'package:sanad_client/infrastructure/socket/sanad_socket_service.dart';

class SocketAuthRecoveryCoordinator {
  final AuthService authService;
  final SanadSocketService socketService;

  StreamSubscription<Map<String, dynamic>>? _authFailureSubscription;
  Future<void>? _recoveryFuture;

  SocketAuthRecoveryCoordinator({
    required this.authService,
    required this.socketService,
  });

  void start() {
    _authFailureSubscription ??= socketService.onAuthFailure.listen((_) {
      unawaited(recover().catchError((_) {}));
    });
  }

  Future<void> recover() async {
    if (_recoveryFuture != null) {
      return _recoveryFuture!;
    }

    _recoveryFuture = _recoverInternal();
    try {
      await _recoveryFuture!;
    } finally {
      _recoveryFuture = null;
    }
  }

  Future<void> _recoverInternal() async {
    final refreshedToken = await authService.refreshAccessToken();
    if (refreshedToken == null) {
      socketService.disconnect();
      socketService.setAccessToken(null);
      await authService.logout();
      return;
    }

    socketService.setAccessToken(refreshedToken);
    await socketService.connect();
  }

  void dispose() {
    unawaited(_authFailureSubscription?.cancel());
  }
}
