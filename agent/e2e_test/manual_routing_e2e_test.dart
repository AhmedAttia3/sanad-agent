import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:test/test.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

void main() {
  test(
    'manual routing and run_id verification E2E test',
    () async {
      print('🚀 Starting SanadAgent E2E Routing Test...');

      // 1. Read auth.json
      final homeDir =
          Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (homeDir == null) {
        print('❌ Error: Could not determine home directory.');
        exit(1);
      }

      final authFile = File('$homeDir/.sanad/auth.json');
      if (!authFile.existsSync()) {
        print('❌ Error: auth.json not found at ${authFile.path}');
        exit(1);
      }

      final authData =
          jsonDecode(authFile.readAsStringSync()) as Map<String, dynamic>;
      final token = authData['access_token'] as String;
      final deviceId = authData['device_id'] as String;

      print('🔑 Loaded credentials:');
      print(' - Device ID: $deviceId');
      print(' - Token Preview: ${token.substring(0, 15)}...');

      // 2. Connect to the Gateway
      final gatewayUrl = 'http://localhost:8001';

      // 2.5 Proactively refresh access token
      String activeToken = token;
      final refreshToken = authData['refresh_token'] as String?;
      if (refreshToken != null) {
        print('🔄 Proactively refreshing access token...');
        final httpClient = HttpClient();
        try {
          final uri = Uri.parse('$gatewayUrl/api/auth/refresh');
          final request = await httpClient.postUrl(uri);
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode({'refresh_token': refreshToken}));
          final response = await request.close();
          if (response.statusCode == 200) {
            final bodyStr = await response.transform(utf8.decoder).join();
            final body = jsonDecode(bodyStr) as Map<String, dynamic>;
            activeToken = body['access_token'] as String;
            print('✅ Access token refreshed successfully!');

            // Update auth.json
            authData['access_token'] = activeToken;
            if (body.containsKey('refresh_token')) {
              authData['refresh_token'] = body['refresh_token'] as String;
            }
            authFile.writeAsStringSync(jsonEncode(authData));
          } else {
            print('⚠️ Failed to refresh token: status ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ Error refreshing token: $e');
        } finally {
          httpClient.close();
        }
      }

      print('🌐 Connecting to Sanad Gateway at $gatewayUrl...');

      final socket = io.io(
        gatewayUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      final completer = Completer<void>();
      Timer? timeoutTimer;

      socket.onConnect((_) {
        print('✅ Connected! Authenticating...');
        socket.emit('app_authenticate', {
          'token': activeToken,
          'device_id': deviceId,
          'platform': 'windows',
        });
      });

      socket.onDisconnect((_) {
        print('🔌 Socket disconnected.');
      });

      socket.on('auth_error', (data) {
        print('❌ Authentication failed: $data');
        completer.completeError('Auth failed');
      });

      socket.on('auth_success', (data) {
        print('✅ Authenticated successfully!');

        // We are now online. Wait 1 second and then request get_capabilities
        Timer(Duration(seconds: 1), () {
          print('⬆️ Sending get_capabilities request...');
          socket.emit('get_capabilities', {});
        });
      });

      socket.on('capabilities', (data) {
        print('📥 Received capabilities event from server: $data');
        final caps = data['capabilities'];
        if (caps != null) {
          print('✅ Capabilities successfully retrieved from backend!');
          print(' - Display Name: ${caps['display_name']}');
          print(' - Models count: ${caps['capabilities']?['models']?.length}');
        } else {
          print('❌ Error: Capabilities returned null!');
        }
        final targetRunId =
            'e2e_think_${DateTime.now().millisecondsSinceEpoch}';
        print(
          '⬆️ Sending think command (user chat message) with run_id: $targetRunId...',
        );
        socket.emit('device_command', {
          'device_id': deviceId,
          'command': 'think',
          'model': 'openai/deepseek/deepseek-chat',
          'payload': {
            'request_id': targetRunId,
            'session_id': 'default',
            'message': 'Hello, write a single short word.',
            'model': 'openai/deepseek/deepseek-chat',
          },
        });
      });

      socket.on('device_event', (data) {
        final event = data['event'] as String?;
        final runId =
            data['run_id'] as String? ?? data['payload']?['run_id'] as String?;

        print('📥 Received device_event: event=$event | run_id=$runId');

        if (event == 'thought_stream') {
          final payload = data['payload'] as Map<String, dynamic>? ?? {};
          final content = payload['content'] ?? '';
          final status = payload['status'] as String?;

          print(
            '💭 [thought_stream] status: $status | content chunk: "$content"',
          );

          if (runId != null && runId.startsWith('e2e_think_')) {
            print('✅ [Verified] Chunk contains correct run_id: $runId');
          } else {
            print('❌ [FAILED] Chunk is missing correct run_id!');
            completer.completeError('thought_stream missing run_id');
            return;
          }
        }

        if (event == 'final_answer') {
          final payload = data['payload'] as Map<String, dynamic>? ?? {};
          final content = payload['content'] ?? '';
          final status = payload['status'] as String?;

          print('🏁 [final_answer] status: $status | full content: "$content"');

          if (runId != null && runId.startsWith('e2e_think_')) {
            print('✅ [Verified] Final answer contains correct run_id: $runId');
          } else {
            print('❌ [FAILED] Final answer is missing correct run_id!');
            completer.completeError('final_answer missing run_id');
            return;
          }

          if (status == 'done') {
            print('📊 [Metrics Verified]:');
            print(' - Model: ${payload['model']}');
            print(' - Model Display: ${payload['model_display']}');
            print(' - Provider: ${payload['provider']}');
            print(' - Runtime Duration: ${payload['runtime_ms']} ms');
            print(' - Context Window: ${payload['context_tokens']} tokens');
            print(' - Token Usage: ${payload['usage']}');

            if (payload['usage'] != null) {
              print('✅ [SUCCESS] Token usage payload is present and verified!');
            } else {
              print(
                '⚠️ [WARNING] Token usage payload is null in this final_answer!',
              );
            }

            print(
              '🎉 [Verified] Complete final_answer stream finished successfully!',
            );
            completer.complete();
          }
        }
      });

      socket.connect();

      // Set timeout (LLM generation can take a few seconds)
      timeoutTimer = Timer(Duration(seconds: 25), () {
        if (!completer.isCompleted) {
          completer.completeError(
            'Timeout waiting for think stream responses.',
          );
        }
      });

      try {
        await completer.future;
        print(
          '✅ E2E Routing and run_id Verification Test Passed Successfully!',
        );
        socket.disconnect();
        timeoutTimer.cancel();
      } catch (e) {
        print('❌ E2E Routing and run_id Verification Test Failed: $e');
        socket.disconnect();
        timeoutTimer.cancel();
        fail(e.toString());
      }
    },
    skip:
        'Requires live Gateway running on port 8001 and local auth.json credentials. Run manually as needed.',
  );
}
