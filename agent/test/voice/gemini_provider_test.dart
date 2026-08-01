import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:test/test.dart';
import 'package:sanad_agent/core/config.dart';
import 'package:sanad_agent/capabilities/registry/tools_registry.dart';
import 'package:sanad_agent/capabilities/tools/base_tool.dart';
import 'package:sanad_agent/capabilities/models/tool_schema.dart';
import 'package:sanad_agent/infrastructure/voice/realtime_voice_provider.dart';
import 'package:sanad_agent/infrastructure/voice/gemini_voice_provider.dart';

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
  int get readyState => WebSocket.open;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class FakeConfig implements Config {
  @override
  String get llmApiKey => 'fake-api-key-123';

  @override
  String getEnvVar(String key, {String defaultValue = ''}) => '';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class DummyTool extends BaseTool {
  final String toolName;
  final String responseString;
  Map<String, dynamic>? lastArgs;

  DummyTool(this.toolName, this.responseString);

  @override
  ToolSchema get schema => ToolSchema(
    name: toolName,
    description: 'A dummy testing tool',
    parameters: {
      'type': 'object',
      'properties': {
        'param1': {'type': 'string', 'description': 'Some string parameter'},
      },
      'required': ['param1'],
    },
  );

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    ToolContext? context,
  }) async {
    lastArgs = args;
    return responseString;
  }
}

void main() {
  final getIt = GetIt.instance;
  late FakeWebSocket ws;
  late GeminiRealtimeVoiceProvider provider;
  late ToolsRegistry toolsRegistry;

  setUp(() {
    getIt.registerSingleton<Config>(FakeConfig());
    toolsRegistry = ToolsRegistry();
    getIt.registerSingleton<ToolsRegistry>(toolsRegistry);

    ws = FakeWebSocket();
    provider = GeminiRealtimeVoiceProvider();
    provider.websocketConnector = (url) async => ws;
  });

  tearDown(() async {
    await provider.close();
    getIt.unregister<Config>();
    getIt.unregister<ToolsRegistry>();
  });

  test(
    'connect establishes WebSocket and sends setup configuration with tools',
    () async {
      final dummy = DummyTool('test_dummy', 'success-result');
      toolsRegistry.registerTool(dummy);

      await provider.connect({
        'session_id': 'test-session-123',
        'model': 'models/gemini-2.0-flash-exp',
        'voice_name': 'Kore',
      });

      expect(ws.sent.length, 1);
      final setupMsg = jsonDecode(ws.sent.first as String);
      expect(setupMsg.containsKey('setup'), true);
      final setup = setupMsg['setup'] as Map;
      expect(setup['model'], 'models/gemini-2.0-flash-exp');
      expect(
        setup['generationConfig']['speechConfig']['voiceConfig']['prebuiltVoiceConfig']['voiceName'],
        'Kore',
      );

      final toolsList = setup['tools'] as List;
      expect(toolsList.length, 1);
      final declList = toolsList.first['functionDeclarations'] as List;
      expect(declList.any((t) => t['name'] == 'test_dummy'), true);

      // Verify uppercase type conversion schema helper
      final dummyDecl =
          declList.firstWhere((t) => t['name'] == 'test_dummy') as Map;
      expect(dummyDecl['parameters']['type'], 'OBJECT');
    },
  );

  test(
    'handleInputAudio base64 encodes and sends realtimeInput mediaChunk',
    () async {
      await provider.connect({'session_id': 'session'});
      ws.sent.clear(); // Clear setup message

      final pcmChunk = [1, 2, 3, 4, 5];
      provider.handleInputAudio(pcmChunk);

      expect(ws.sent.length, 1);
      final inputMsg = jsonDecode(ws.sent.first as String);
      expect(inputMsg.containsKey('realtimeInput'), true);
      final mediaChunks = inputMsg['realtimeInput']['mediaChunks'] as List;
      expect(mediaChunks.first['mimeType'], 'audio/pcm;rate=16000');
      expect(mediaChunks.first['data'], base64Encode(pcmChunk));
    },
  );

  test(
    'parses incoming serverContent audio, text, and transcription events',
    () async {
      await provider.connect({'session_id': 'session'});

      // Test Audio Output Event
      final testAudio = [100, 101, 102];
      final audioBase64 = base64Encode(testAudio);

      final audioFuture = provider.outputEvents.firstWhere(
        (e) => e is AudioOutputEvent,
      );
      ws.controller.add(
        jsonEncode({
          'serverContent': {
            'modelTurn': {
              'parts': [
                {
                  'inlineData': {
                    'mimeType': 'audio/pcm;rate=24000',
                    'data': audioBase64,
                  },
                },
              ],
            },
          },
        }),
      );
      final audioEvent = await audioFuture as AudioOutputEvent;
      expect(audioEvent.pcmChunk, testAudio);

      // Test Text Response Event
      final textFuture = provider.outputEvents.firstWhere(
        (e) => e is TextResponseEvent,
      );
      ws.controller.add(
        jsonEncode({
          'serverContent': {
            'modelTurn': {
              'parts': [
                {'text': 'Hello world'},
              ],
            },
          },
        }),
      );
      final textEvent = await textFuture as TextResponseEvent;
      expect(textEvent.text, 'Hello world');

      // Test User Transcription Event
      final userTextFuture = provider.outputEvents.firstWhere(
        (e) => e is UserTranscriptionEvent,
      );
      ws.controller.add(
        jsonEncode({
          'serverContent': {
            'userTurn': {
              'parts': [
                {'text': 'User spoke something'},
              ],
            },
          },
        }),
      );
      final userTextEvent = await userTextFuture as UserTranscriptionEvent;
      expect(userTextEvent.text, 'User spoke something');

      // Test Interrupted Event
      final interruptedFuture = provider.outputEvents.firstWhere(
        (e) => e is InterruptedEvent,
      );
      ws.controller.add(
        jsonEncode({
          'serverContent': {'interrupted': true},
        }),
      );
      final interruptedEvent = await interruptedFuture as InterruptedEvent;
      expect(interruptedEvent, isA<InterruptedEvent>());
    },
  );

  test(
    'intercepts Gemini tool calls, executes local tool, and replies with toolResponse',
    () async {
      final dummy = DummyTool('search_local_docs', 'Dummy search output text');
      toolsRegistry.registerTool(dummy);

      await provider.connect({'session_id': 'session-456'});
      ws.sent.clear(); // Clear setup message

      // Simulate receiving a tool call from Gemini API
      ws.controller.add(
        jsonEncode({
          'toolCall': {
            'functionCalls': [
              {
                'id': 'call_xyz_123',
                'name': 'search_local_docs',
                'args': {'param1': 'secret code'},
              },
            ],
          },
        }),
      );

      // Wait a brief tick for async tool execution to complete and write to the socket
      await Future.delayed(const Duration(milliseconds: 50));

      expect(dummy.lastArgs != null, true);
      expect(dummy.lastArgs!['param1'], 'secret code');

      expect(ws.sent.length, 1);
      final responseMsg = jsonDecode(ws.sent.first as String);
      expect(responseMsg.containsKey('toolResponse'), true);
      final responses =
          responseMsg['toolResponse']['functionResponses'] as List;
      expect(responses.length, 1);
      expect(responses.first['id'], 'call_xyz_123');
      expect(responses.first['response']['output'], 'Dummy search output text');
    },
  );
}
