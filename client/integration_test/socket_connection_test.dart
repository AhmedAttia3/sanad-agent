import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

/// Standalone test to verify Socket.IO connection and message flow
/// Run with: dart test/socket_connection_test.dart
void main() async {
  print('🧪 Socket.IO Connection Test');
  print('=' * 50);

  // Configuration
  const serverUrl = 'http://localhost:8000';
  const userId = 1;
  const sessionId = 'session_1_default_device';
  const deviceId = 'default_device';

  print('📍 Connecting to: $serverUrl');
  print('🔑 User ID: $userId');
  print('🧵 Session ID: $sessionId');
  print('');

  // Create Socket.IO client
  final socket = socket_io.io(
    serverUrl,
    socket_io.OptionBuilder().setTransports(['websocket']).enableForceNew().disableAutoConnect().build(),
  );

  // Track connection status
  var isConnected = false;
  var isAuthenticated = false;
  final receivedEvents = <Map<String, dynamic>>[];

  // Setup event listeners
  socket.onConnect((_) {
    print('✅ Connected to server');
    isConnected = true;

    // Authenticate
    print('🔐 Authenticating...');
    socket.emit('app_authenticate', {'token': 'user:$userId'});
  });

  socket.onDisconnect((_) {
    print('❌ Disconnected from server');
    isConnected = false;
  });

  socket.on('auth_success', (data) {
    print('✅ Authentication successful: $data');
    isAuthenticated = true;

    // Join device room
    print('🚪 Joining device room: $deviceId');
    socket.emit('join_room', {'device_id': deviceId});
  });

  socket.on('auth_error', (data) {
    print('❌ Authentication failed: $data');
  });

  socket.on('device_event', (data) {
    print('📥 Received device_event: $data');
    if (data is Map<String, dynamic>) {
      receivedEvents.add(data);

      final event = data['event'];
      final payload = data['payload'];

      print('   Event: $event');
      print('   Payload: $payload');

      if (payload is Map<String, dynamic>) {
        final content = payload['content'];
        if (content != null) {
          print('   Content: $content');
        }
      }
    }
  });

  socket.on('error', (data) {
    print('❌ Socket error: $data');
  });

  // Connect
  socket.connect();

  // Wait for connection and authentication
  await Future.delayed(const Duration(seconds: 2));

  if (!isConnected) {
    print('❌ Failed to connect to server');
    socket.dispose();
    return;
  }

  if (!isAuthenticated) {
    print('❌ Failed to authenticate');
    socket.dispose();
    return;
  }

  // Send test message
  print('');
  print('📤 Sending test message...');
  socket.emit('device_command', {
    'device_id': deviceId,
    'command': 'think',
    'params': {
      'goal': 'Test message from Dart socket tester',
      'session_id': sessionId,
    },
  });

  print('✅ Message sent');
  print('⏳ Waiting for responses (15 seconds)...');
  print('');

  // Wait for responses
  await Future.delayed(const Duration(seconds: 15));

  // Summary
  print('');
  print('=' * 50);
  print('📊 Test Summary');
  print('=' * 50);
  print('Connection: ${isConnected ? "✅" : "❌"}');
  print('Authentication: ${isAuthenticated ? "✅" : "❌"}');
  print('Events Received: ${receivedEvents.length}');

  if (receivedEvents.isEmpty) {
    print('');
    print('❌ No events received!');
    print('');
    print('Troubleshooting:');
    print('1. Check if mock_brain.py is running');
    print('2. Check if Backend is receiving messages from Redis');
    print('3. Check Backend logs: docker compose logs backend');
    print('4. Check Redis MONITOR: docker compose exec redis redis-cli MONITOR');
  } else {
    print('');
    print('✅ Test PASSED!');
    print('');
    print('Received Events:');
    for (var i = 0; i < receivedEvents.length; i++) {
      final event = receivedEvents[i];
      print('  ${i + 1}. ${event['type']} - ${event['payload']}');
    }
  }

  print('');
  socket.dispose();
}
