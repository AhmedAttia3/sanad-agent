import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:sanad_agent/core/di.dart';
import 'package:sanad_agent/interfaces/platforms/sanad_gateway/server_sanad_gateway_platform.dart';

/// Abstract class representing a generic transport channel for voice audio and control signals.
abstract class VoiceTransportChannel {
  /// Stream of incoming audio chunks (microphone PCM 16kHz).
  Stream<List<int>> get inputAudioStream;

  /// Stream of control events (e.g. "interrupt", "stop_voice").
  Stream<String> get controlEvents;

  /// Send output audio back to the client (speaker PCM 24kHz).
  void sendOutputAudio(List<int> pcmChunk);

  /// Send control signals or transcription text back to the client.
  void sendControlEvent(String eventName, Map<String, dynamic> payload);

  /// Close the transport channel.
  Future<void> close();
}

/// Local WebSocket implementation of [VoiceTransportChannel].
class LocalWebSocketTransportChannel extends VoiceTransportChannel {
  final _logger = Logger('LocalWebSocketTransportChannel');
  final WebSocket _webSocket;
  final _audioController = StreamController<List<int>>.broadcast();
  final _controlController = StreamController<String>.broadcast();
  late final StreamSubscription _subscription;
  int _audioChunkCount = 0;

  LocalWebSocketTransportChannel(this._webSocket) {
    _subscription = _webSocket.listen(
      (message) {
        if (message is List<int>) {
          _audioChunkCount++;
          if (_audioChunkCount == 1 || _audioChunkCount % 50 == 0) {
            _logger.info(
              '🎙️ Audio chunk #$_audioChunkCount from Flutter: ${message.length} bytes → Gemini',
            );
          }
          _audioController.add(message);
        } else if (message is String) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(message);
            final eventName = decoded['event'] as String?;
            if (eventName != null) {
              _logger.info('🎮 Control event from Flutter: $eventName');
              _controlController.add(eventName);
            }
          } catch (e) {
            _logger.warning(
              'Failed to decode websocket text message: $message, error: $e',
            );
          }
        } else {
          _logger.warning('Unexpected message type: ${message.runtimeType}');
        }
      },
      onDone: () {
        _logger.info('Local WebSocket channel done.');
        close();
      },
      onError: (err) {
        _logger.severe('Local WebSocket channel error: $err');
        close();
      },
    );
  }

  @override
  Stream<List<int>> get inputAudioStream => _audioController.stream;

  @override
  Stream<String> get controlEvents => _controlController.stream;

  int _outputChunkCount = 0;

  @override
  void sendOutputAudio(List<int> pcmChunk) {
    try {
      _outputChunkCount++;
      if (_outputChunkCount == 1 || _outputChunkCount % 50 == 0) {
        _logger.info(
          '🔊 Audio chunk #$_outputChunkCount from Gemini → Flutter: ${pcmChunk.length} bytes',
        );
      }
      _webSocket.add(pcmChunk);
    } catch (e) {
      _logger.warning('Failed to send output audio: $e');
    }
  }

  @override
  void sendControlEvent(String eventName, Map<String, dynamic> payload) {
    try {
      final message = jsonEncode({
        'type': 'device_event',
        'event': eventName,
        'payload': payload,
      });
      _webSocket.add(message);
    } catch (e) {
      _logger.warning('Failed to send control event: $e');
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _audioController.close();
    await _controlController.close();
    await _webSocket.close();
  }
}

/// Cloud Socket.IO implementation of [VoiceTransportChannel].
class CloudSocketIoTransportChannel extends VoiceTransportChannel {
  final _logger = Logger('CloudSocketIoTransportChannel');
  final String deviceId;
  late final io.Socket _socket;
  final _audioController = StreamController<List<int>>.broadcast();
  final _controlController = StreamController<String>.broadcast();

  CloudSocketIoTransportChannel(this.deviceId) {
    final gatewayPlatform = getIt<ServerSanadGatewayPlatform>();
    final socket = gatewayPlatform.socket;
    if (socket == null) {
      throw StateError(
        'Socket.IO is not initialized on ServerSanadGatewayPlatform',
      );
    }
    _socket = socket;

    _socket.on('voice_audio_chunk_relay', _onAudioChunk);
    _socket.on('voice_control_relay', _onControlEvent);
  }

  void _onAudioChunk(dynamic data) {
    if (data is Map) {
      final audioData = data['data'];
      if (audioData is List<int>) {
        _audioController.add(audioData);
      } else if (audioData is List) {
        _audioController.add(List<int>.from(audioData));
      } else if (audioData is String) {
        // Base64 fallback if needed
        _audioController.add(base64Decode(audioData));
      }
    } else if (data is List<int>) {
      _audioController.add(data);
    } else if (data is List) {
      _audioController.add(List<int>.from(data));
    }
  }

  void _onControlEvent(dynamic data) {
    if (data is Map) {
      final eventName = data['event'] as String?;
      if (eventName != null) {
        _controlController.add(eventName);
      }
    } else if (data is String) {
      _controlController.add(data);
    }
  }

  @override
  Stream<List<int>> get inputAudioStream => _audioController.stream;

  @override
  Stream<String> get controlEvents => _controlController.stream;

  @override
  void sendOutputAudio(List<int> pcmChunk) {
    if (!_socket.connected) {
      _logger.warning('Cannot send output audio: Socket.IO is disconnected');
      return;
    }
    _socket.emit('device_voice_audio_chunk', {
      'device_id': deviceId,
      'data': pcmChunk,
    });
  }

  @override
  void sendControlEvent(String eventName, Map<String, dynamic> payload) {
    if (!_socket.connected) {
      _logger.warning('Cannot send control event: Socket.IO is disconnected');
      return;
    }
    _socket.emit('device_event', {
      'device_id': deviceId,
      'type': 'event',
      'event': eventName,
      'payload': payload,
    });
  }

  @override
  Future<void> close() async {
    _socket.off('voice_audio_chunk_relay', _onAudioChunk);
    _socket.off('voice_control_relay', _onControlEvent);
    await _audioController.close();
    await _controlController.close();
  }
}
