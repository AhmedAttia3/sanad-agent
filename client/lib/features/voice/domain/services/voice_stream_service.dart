import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart' hide IosAudioCategory;
import 'package:audio_session/audio_session.dart';
import 'package:mp_audio_stream/mp_audio_stream.dart';
import 'package:logging/logging.dart';

class VoiceStreamService {
  final _logger = Logger('VoiceStreamService');
  final _recorder = AudioRecorder();
  final _audioStream = getAudioStream();
  StreamSubscription<List<int>>? _recorderSubscription;
  bool _isPlaying = false;
  bool _isAudioStreamInitialized = false;

  final List<List<int>> _playbackQueue = [];
  bool _isProcessingQueue = false;
  Timer? _playbackTimer;
  DateTime? _nextPlayTime;
  bool _isPreBuffering = true;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Starts recording microphone input at 16kHz Mono PCM 16-bit
  Future<Stream<List<int>>> startRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      throw Exception('Microphone recording permission denied');
    }

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    return stream;
  }

  /// Stops recording microphone input
  Future<void> stopRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _recorderSubscription?.cancel();
    _recorderSubscription = null;
  }

  /// Prepares the playback engine for 24kHz stream playback using mp_audio_stream
  Future<void> startPlayback() async {
    _logger.info('=== [VoiceStreamService] startPlayback called ===');
    await stopPlayback();

    // Configure global AudioSession for echo cancellation
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth | AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );
      await session.setActive(true);
      _logger.info('[VoiceStreamService] AudioSession configured and activated for Voice Chat (AEC enabled).');
    } catch (e) {
      _logger.severe('[VoiceStreamService] Failed to configure AudioSession: $e');
    }

    // Set up mp_audio_stream
    _audioStream.init(
      sampleRate: 24000,
      channels: 1,
      bufferMilliSec: 30000,
    );
    _isAudioStreamInitialized = true;
    _audioStream.resume();
    _isPlaying = true;
    _logger.info('[VoiceStreamService] mp_audio_stream initialized (ready to feed).');
  }

  /// Feeds incoming 24kHz PCM bytes directly into mp_audio_stream after converting to Float32List
  void playAudioChunk(List<int> pcmChunk) {
    if (pcmChunk.isEmpty) return;

    if (!_isPlaying) {
      _logger.warning('[VoiceStreamService] Warning: playAudioChunk called but _isPlaying is false. Ignoring.');
      return;
    }

    _playbackQueue.add(pcmChunk);
    if (!_isProcessingQueue) {
      _processPlaybackQueue();
    }
  }

  void _processPlaybackQueue() {
    if (_playbackQueue.isEmpty || !_isPlaying) {
      _isProcessingQueue = false;
      _nextPlayTime = null;
      return;
    }

    // Jitter buffer pre-buffering check
    if (_isPreBuffering) {
      final totalBytes = _playbackQueue.fold<int>(0, (sum, chunk) => sum + chunk.length);
      if (totalBytes < 5760) {
        // Less than 120ms of audio (120 * 48 bytes)
        _isProcessingQueue = false;
        return;
      }
      _isPreBuffering = false;
    }

    _isProcessingQueue = true;
    final chunk = _playbackQueue.removeAt(0);
    _playRawChunk(chunk);

    // Calculate exact chunk duration in microseconds to avoid accumulation of division errors:
    // samples = chunk.length / 2
    // durationUs = samples / 24000 * 1,000,000 = chunk.length * 1000000 / 48000
    final durationUs = (chunk.length * 1000000) ~/ 48000;

    final now = DateTime.now();
    if (_nextPlayTime == null) {
      _nextPlayTime = now.add(Duration(microseconds: durationUs));
    } else {
      _nextPlayTime = _nextPlayTime!.add(Duration(microseconds: durationUs));
    }

    // Determine delay for the next chunk
    int delayUs = _nextPlayTime!.difference(now).inMicroseconds;

    // If we are lagging behind by more than 100ms, reset the target time to prevent catch-up rush
    if (delayUs < -100000) {
      _nextPlayTime = now.add(Duration(microseconds: durationUs));
      delayUs = durationUs;
    } else if (delayUs < 0) {
      delayUs = 0; // Play immediately if slightly behind
    }

    _playbackTimer = Timer(Duration(microseconds: delayUs), () {
      _processPlaybackQueue();
    });
  }

  void _playRawChunk(List<int> pcmChunk) {
    // Convert 16-bit signed PCM to Float32List (-1.0 to 1.0)
    final buffer = pcmChunk is Uint8List ? pcmChunk : Uint8List.fromList(pcmChunk);
    final byteData = ByteData.sublistView(buffer);
    final count = pcmChunk.length ~/ 2;
    if (count == 0) return;

    final floatList = Float32List(count);
    for (int i = 0; i < count; i++) {
      final int16Sample = byteData.getInt16(i * 2, Endian.little);
      floatList[i] = int16Sample / 32768.0;
    }

    _audioStream.push(floatList);
  }

  /// Stops speaker playback
  Future<void> stopPlayback() async {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playbackQueue.clear();
    _isProcessingQueue = false;
    _nextPlayTime = null;
    _isPreBuffering = true;
    if (_isAudioStreamInitialized) {
      _audioStream.uninit();
      _isAudioStreamInitialized = false;
      _logger.info('[VoiceStreamService] mp_audio_stream uninitialized.');
    }
  }

  /// Fully disposes player and recorder resources
  Future<void> dispose() async {
    await stopRecording();
    await stopPlayback();
    await _recorder.dispose();
  }
}
