import 'dart:async';

import 'package:sanad_client/core/presentation/state/socket_auth_recovery_coordinator.dart';
import 'package:sanad_client/features/auth/infrastructure/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_socket_service.dart';

class FakeAuthService extends AuthService {
  final _tokenController = StreamController<String?>.broadcast();
  String? _token;
  int refreshCalls = 0;
  int logoutCalls = 0;
  String? refreshResult;

  FakeAuthService({this.refreshResult}) {
    _token = refreshResult;
  }

  @override
  Stream<String?> get accessTokenStream => _tokenController.stream;

  @override
  String? get accessToken => _token;

  @override
  Future<String?> refreshAccessToken() async {
    refreshCalls += 1;
    _token = refreshResult;
    _tokenController.add(_token);
    return refreshResult;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    _token = null;
    _tokenController.add(null);
  }

  @override
  Future<void> init({String? fallbackDeviceId}) async {}

  @override
  void dispose() {
    unawaited(_tokenController.close());
    super.dispose();
  }
}

class TrackingSocketService extends FakeSanadSocketService {
  int connectCalls = 0;
  final List<String?> seenTokens = [];

  TrackingSocketService() : super();

  @override
  void setAccessToken(String? token) {
    seenTokens.add(token);
    super.setAccessToken(token);
  }

  @override
  Future<void> connect() async {
    connectCalls += 1;
    setConnected(true);
  }
}

void main() {
  group('SocketAuthRecoveryCoordinator', () {
    late FakeAuthService authService;
    late TrackingSocketService socketService;
    late SocketAuthRecoveryCoordinator coordinator;

    setUp(() {
      authService = FakeAuthService(refreshResult: 'refreshed-access-token');
      socketService = TrackingSocketService();
      coordinator = SocketAuthRecoveryCoordinator(authService: authService, socketService: socketService)..start();
    });

    tearDown(() {
      coordinator.dispose();
      authService.dispose();
      socketService.dispose();
    });

    test('refreshes token and reconnects after socket auth failure', () async {
      socketService.debugEmitAuthFailure({'message': 'Invalid token'});

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(authService.refreshCalls, 1);
      expect(socketService.seenTokens, contains('refreshed-access-token'));
      expect(socketService.connectCalls, 1);
      expect(socketService.isConnected, isTrue);
    });

    test('logs out when refresh token recovery fails', () async {
      authService.refreshResult = null;

      socketService.debugEmitAuthFailure({'message': 'Invalid token'});

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(authService.refreshCalls, 1);
      expect(authService.logoutCalls, 1);
      expect(socketService.seenTokens, contains(null));
      expect(socketService.isConnected, isFalse);
    });

    test('coalesces concurrent auth failures into one refresh attempt', () async {
      socketService.debugEmitAuthFailure({'message': 'Invalid token'});
      socketService.debugEmitAuthFailure({'message': 'Invalid token'});

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(authService.refreshCalls, 1);
      expect(socketService.connectCalls, 1);
    });
  });
}
