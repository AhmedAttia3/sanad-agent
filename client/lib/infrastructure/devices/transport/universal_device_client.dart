import 'package:sanad_client/infrastructure/socket/sanad_socket_service.dart';
import 'package:sanad_client/infrastructure/devices/models/device_client.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:sanad_client/features/conversations/data/transport/conversation_command_gateway.dart';
import 'dart:async';

class UniversalDeviceClient extends DeviceClient {
  final DeviceConfig _config;
  late SanadSocketService _controller;
  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();
  ConversationCommandGateway? _gateway;
  StreamSubscription<Map<String, dynamic>>? _eventsSubscription;

  UniversalDeviceClient(this._config, this._controller) {
    _bindGateway(_controller);
  }

  @override
  DeviceConfig get config => _config;

  @override
  SanadSocketService get controller => _controller;

  @override
  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  @override
  bool get isConnected => _gateway!.isConnected;

  @override
  void sendCommand({
    required String command,
    Map<String, dynamic>? payload,
  }) {
    _gateway!.sendCommand(command: command, payload: payload);
  }

  @override
  Future<Map<String, dynamic>?> request({
    required String command,
    required Map<String, dynamic> payload,
    required String requestId,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _gateway!.request(
      command: command,
      payload: payload,
      requestId: requestId,
      timeout: timeout,
    );
  }

  void updateSocketService(SanadSocketService controller) {
    if (identical(_controller, controller)) {
      return;
    }
    _bindGateway(controller);
  }

  void _bindGateway(SanadSocketService controller) {
    _disposeGateway();
    _controller = controller;
    final gateway = SocketConversationCommandGateway(
      config: _config,
      controller: _controller,
    );
    _gateway = gateway;
    _eventsSubscription = gateway.events.listen((event) {
      if (!_eventsController.isClosed) {
        _eventsController.add(event);
      }
    });
  }

  void _disposeGateway() {
    final eventsSubscription = _eventsSubscription;
    if (eventsSubscription != null) {
      unawaited(eventsSubscription.cancel());
    }
    _eventsSubscription = null;
    final gateway = _gateway;
    if (gateway != null) {
      gateway.dispose();
    }
    _gateway = null;
  }

  @override
  void dispose() {
    _disposeGateway();
    unawaited(_eventsController.close());
  }

  static UniversalDeviceClient create({
    required DeviceConfig config,
    required SanadSocketService controller,
  }) {
    return UniversalDeviceClient(config, controller);
  }
}
