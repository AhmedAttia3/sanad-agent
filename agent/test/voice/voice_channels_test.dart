import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:test/test.dart';
import 'package:sanad_agent/interfaces/platforms/sanad_gateway/server_sanad_gateway_platform.dart';
import 'package:sanad_agent/infrastructure/voice/voice_transport_channel.dart';

class FakeWebSocket implements WebSocket {
  final controller = StreamController<dynamic>();
  final sent = <dynamic>[];

  @override
  StreamSubscription listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  void add(dynamic data) {
    sent.add(data);
  }

  @override
  Future close([int? code, String? reason]) async {
    await controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class FakeSocket implements io.Socket {
  final listeners = <String, List<Function>>{};
  final emitted = <String, dynamic>{};

  @override
  Function() on(String event, Function fn) {
    listeners.putIfAbsent(event, () => []).add(fn);
    return () {};
  }

  @override
  void off(String event, [Function? fn]) {
    listeners.remove(event);
  }

  @override
  void emit(String event, [dynamic data]) {
    emitted[event] = data;
  }

  @override
  bool get connected => true;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class FakeServerSanadGatewayPlatform implements ServerSanadGatewayPlatform {
  @override
  final io.Socket socket;
  FakeServerSanadGatewayPlatform(this.socket);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

void main() {
  group('LocalWebSocketTransportChannel Tests', () {
    late FakeWebSocket ws;
    late LocalWebSocketTransportChannel channel;

    setUp(() {
      ws = FakeWebSocket();
      channel = LocalWebSocketTransportChannel(ws);
    });

    test('receives binary PCM audio from WebSocket', () async {
      final pcmData = [0, 1, 2, 3];

      expect(channel.inputAudioStream, emits(pcmData));

      ws.controller.add(pcmData);
    });

    test('receives control event JSON from WebSocket', () async {
      final controlJson = '{"event": "interrupt"}';

      expect(channel.controlEvents, emits('interrupt'));

      ws.controller.add(controlJson);
    });

    test('sendOutputAudio adds binary data to WebSocket', () {
      final outputPcm = [4, 5, 6, 7];
      channel.sendOutputAudio(outputPcm);

      expect(ws.sent.length, 1);
      expect(ws.sent.first, outputPcm);
    });

    test('sendControlEvent adds JSON string to WebSocket', () {
      channel.sendControlEvent('voice_text_response', {'text': 'Hello'});

      expect(ws.sent.length, 1);
      final sentStr = ws.sent.first as String;
      final decoded = jsonDecode(sentStr);
      expect(decoded['type'], 'device_event');
      expect(decoded['event'], 'voice_text_response');
      expect(decoded['payload']['text'], 'Hello');
    });
  });

  group('CloudSocketIoTransportChannel Tests', () {
    late FakeSocket socket;
    late CloudSocketIoTransportChannel channel;
    final getIt = GetIt.instance;

    setUp(() {
      socket = FakeSocket();
      final gateway = FakeServerSanadGatewayPlatform(socket);
      getIt.registerSingleton<ServerSanadGatewayPlatform>(gateway);
      channel = CloudSocketIoTransportChannel('device-123');
    });

    tearDown(() {
      getIt.unregister<ServerSanadGatewayPlatform>();
    });

    test('receives binary PCM audio from voice_audio_chunk_relay', () async {
      final pcmData = [10, 11, 12, 13];

      expect(channel.inputAudioStream, emits(pcmData));

      final handler = socket.listeners['voice_audio_chunk_relay']!.first;
      handler({'data': pcmData});
    });

    test('receives control event from voice_control_relay', () async {
      expect(channel.controlEvents, emits('interrupt'));

      final handler = socket.listeners['voice_control_relay']!.first;
      handler({'event': 'interrupt'});
    });

    test('sendOutputAudio emits device_voice_audio_chunk to Socket.IO', () {
      final outputPcm = [14, 15, 16, 17];
      channel.sendOutputAudio(outputPcm);

      expect(socket.emitted.containsKey('device_voice_audio_chunk'), true);
      final payload = socket.emitted['device_voice_audio_chunk'] as Map;
      expect(payload['device_id'], 'device-123');
      expect(payload['data'], outputPcm);
    });

    test('sendControlEvent emits device_event to Socket.IO', () {
      channel.sendControlEvent('voice_interrupted', {});

      expect(socket.emitted.containsKey('device_event'), true);
      final payload = socket.emitted['device_event'] as Map;
      expect(payload['device_id'], 'device-123');
      expect(payload['type'], 'event');
      expect(payload['event'], 'voice_interrupted');
    });
  });
}
