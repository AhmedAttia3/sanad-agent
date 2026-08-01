import 'dart:async';

/// Base class for all events emitted by a voice provider.
abstract class RealtimeVoiceEvent {}

/// Standardized binary PCM output (24kHz Mono 16-bit little-endian)
class AudioOutputEvent extends RealtimeVoiceEvent {
  final List<int> pcmChunk;
  AudioOutputEvent(this.pcmChunk);
}

/// Live text transcript of the assistant's response (thought/speak tokens)
class TextResponseEvent extends RealtimeVoiceEvent {
  final String text;
  TextResponseEvent(this.text);
}

/// Live text transcript of the user's voice (transcribed from input audio)
class UserTranscriptionEvent extends RealtimeVoiceEvent {
  final String text;
  UserTranscriptionEvent(this.text);
}

/// Interruption trigger (VAD cut-off / Barge-in)
class InterruptedEvent extends RealtimeVoiceEvent {}

/// Abstract interface for voice providers.
abstract class RealtimeVoiceProvider {
  /// Connection and handshake lifecycle.
  Future<void> connect(Map<String, dynamic> sessionConfig);

  /// Close connection and clean up resources.
  Future<void> close();

  /// Pass client microphone PCM audio chunks (16kHz, mono, 16-bit little-endian).
  void handleInputAudio(List<int> pcmChunk16kHz);

  /// Pass control signals (e.g., interrupt).
  void handleControlEvent(String eventName, Map<String, dynamic> payload);

  /// Stream of standardized output events from the provider.
  Stream<RealtimeVoiceEvent> get outputEvents;
}
