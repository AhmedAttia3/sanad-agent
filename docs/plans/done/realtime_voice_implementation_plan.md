---
title: "Dual-Scope Realtime Voice Streaming & LiveKit Purge Plan"
description: "This plan details the implementation strategy for integrating a pluggable, low-latency, and dual-scope voice system supporting both Realtime Duplex Streaming and Turn-Based TTS/STT fallback, while purging LiveKit client/server dependencies."
---

# Dual-Scope Realtime Voice Streaming & LiveKit Purge Plan

This plan details the implementation strategy for integrating a pluggable, low-latency, and dual-scope voice system supporting both **Realtime Duplex Streaming** (Gemini/OpenAI Multimodal Live APIs) and **Turn-Based TTS/STT** fallback across two connection scopes:
1.  **Local Connection Scope (`ConnectionScope.local`):** Directly via localhost WebSocket (`ws://localhost:4500`).
2.  **Cloud Connection Scope (`ConnectionScope.cloud`):** Relayed via the FastAPI Backend's Socket.IO connection.

Additionally, this plan outlines the progressive removal and stubbing of the legacy LiveKit client/server dependencies.

---

## User Review Required

> [!IMPORTANT]
> ### 1. Plug-and-Play Provider Abstraction
> To avoid coupling the system to a single provider (like Gemini), we introduce a pluggable provider abstraction in the Daemon (`sanadagent-local`). The core voice engine orchestrates sessions by routing packets through a generic `RealtimeVoiceProvider` interface. This allows seamless integration of OpenAI Realtime API or a local offline TTS/STT loop without changing the network transport code.

> [!IMPORTANT]
> ### 2. Audio Specifications & Playback Config (Robot Voice Bug Prevention)
> Based on the official Gemini Multimodal Live API protocol specifications:
> - **Input (Mic Recording):** **16,000 Hz** (16kHz), 16-bit Mono, Little-Endian PCM.
> - **Output (Speaker Playback):** **24,000 Hz** (24kHz), 16-bit Mono, Little-Endian PCM.
> - **Playback Engine Setup:** The Flutter client's audio player **MUST** be explicitly configured to consume the stream at **24,000 Hz**. Playing the 24kHz stream at 16kHz will cause the voice to sound slowed down and severely distorted.

> [!IMPORTANT]
> ### 3. Agent Tool Call Integration & Context Sync
> During voice interaction, the agent does **NOT** lose access to the desktop context:
> - **Function Calling:** Available tools (file tools, system tools, MCP tools) are registered during session setup. When the model requests a function call, the daemon interceptor runs the local tool, returns the result back to the SaaS WebSocket stream, and the model verbally reports the result.
> - **Thread Continuity:** The voice session is seeded with active text chat messages upon starting. Upon ending, the voice conversation transcripts are appended to the active database thread, ensuring a unified visual chat history.

---

## Provider Plugin Architecture Details

### A. The `RealtimeVoiceProvider` Interface
Every voice provider (Gemini, OpenAI, Local) must implement this interface in `sanadagent-local`:

```dart
abstract class RealtimeVoiceProvider {
  // Connection lifecycle
  Future<void> connect(Map<String, dynamic> sessionConfig);
  Future<void> close();

  // Audio and control inputs from client
  void handleInputAudio(List<int> pcmChunk16kHz);
  void handleControlEvent(String eventName, Map<String, dynamic> payload);

  // Stream of normalized events routed back to the client
  Stream<RealtimeVoiceEvent> get outputEvents;
}
```

### B. Standardized `RealtimeVoiceEvent` Classes
Providers map vendor-specific packets into these standardized events:
- `AudioOutputEvent(List<int> pcmChunk)`: Standardized binary PCM output (24kHz Mono 16-bit little-endian).
- `TextResponseEvent(String text)`: Streamed text transcript of the assistant's thought or spoken response.
- `UserTranscriptionEvent(String text)`: Streamed transcription of the user's voice inputs.
- `InterruptedEvent()`: Interruption trigger (VAD cut-off).

---

## Proposed Changes

### 1. Backend (`backend/`)

We will introduce a low-latency binary PCM relay in the Socket.IO gateway manager.

#### [MODIFY] [manager.py](file:///backend/app/sanad_gateway/manager.py)
- Register listeners for binary streaming:
  - `@sio.event async def voice_audio_chunk(sid, data)`: Receives `{ agent_id, data: PCM_bytes }` from a client and forwards it to the target agent as `voice_audio_chunk_relay`.
  - `@sio.event async def agent_voice_audio_chunk(sid, data)`: Receives `{ agent_id, data: PCM_bytes }` from an agent worker and forwards it to the client room `user_app_{user_id}` as `voice_audio_chunk_relay`.
  - `@sio.event async def voice_control(sid, data)`: Relays control signals like `interrupt` or `stop_voice` to the remote agent as `voice_control_relay`.

---

### 2. Local Daemon (`sanadagent-local/`)

We will decouple the Gemini Live connection manager from the transport protocol by introducing an abstract transport channel.

#### [NEW] `voice_transport_channel.dart` (sanadagent-local/lib/infrastructure/voice/voice_transport_channel.dart)
- Define `VoiceTransportChannel` abstract class:
  - `Stream<List<int>> get inputAudioStream`
  - `Stream<String> get controlEvents`
  - `void sendOutputAudio(List<int> pcmChunk)`
  - `void sendControlEvent(String eventName, Map<String, dynamic> payload)`
- Implement two channel variants:
  1.  `LocalWebSocketTransportChannel` (handles local HTTP WebSocket server connections).
  2.  `CloudSocketIoTransportChannel` (handles backend Socket.IO events `voice_audio_chunk_relay` and `agent_voice_audio_chunk`).

#### [NEW] `realtime_voice_provider.dart` (sanadagent-local/lib/infrastructure/voice/realtime_voice_provider.dart)
- Implement the `RealtimeVoiceProvider` interface and standardized `RealtimeVoiceEvent` classes.

#### [NEW] `gemini_voice_provider.dart` (sanadagent-local/lib/infrastructure/voice/gemini_voice_provider.dart)
- Implement `GeminiRealtimeVoiceProvider` connecting to `wss://generativelanguage.googleapis.com/...`.
- Immediately send the JSON `setup` payload upon connection, registering available system, file, and MCP tools.
- Intercept incoming tool calls, invoke the local tool runner, and return results using `toolResponse` payloads.
- Stream input audio as base64 in `realtimeInput` messages and parse output audio from `serverContent` into `AudioOutputEvent`.

#### [MODIFY] `voice_engine.dart` (sanadagent-local/lib/infrastructure/voice/voice_engine.dart)
- Orchestrate the session by routing messages between the active `VoiceTransportChannel` and the selected `RealtimeVoiceProvider`.

---

### 3. Client UI (`sanad-client/`)

The client will capture PCM audio and route it dynamically based on the connection scope.

#### [MODIFY] [device_connection_coordinator.dart](file:///sanad-client/lib/features/devices/data/device_connection_coordinator.dart)
- Provide hooks to check connection scope and obtain the active socket service or local websocket endpoint.

#### [NEW] `voice_stream_service.dart` (sanad-client/lib/features/voice/domain/services/voice_stream_service.dart)
- Manage recording at **16,000 Hz** and playback at **24,000 Hz** (using a custom `StreamAudioSource` for PCM audio).
- Route recording stream to:
  - Local WebSocket when scope is `local`.
  - `SanadSocketService` (`voice_audio_chunk` event) when scope is `cloud`.

#### [MODIFY] [conversation_input_composer.dart](file:///sanad-client/lib/features/conversations/presentation/widgets/conversation_input/conversation_input_composer.dart)
- Place a Microphone Icon button in the text input composer row next to the Send button. Clicking this triggers voice mode.

#### [MODIFY] [pubspec.yaml](file:///sanad-client/pubspec.yaml)
- Remove `livekit_client` dependency and perform clean stubbing of `RoomService`, `CallCubit`, and related LiveKit elements to allow the client to build.

---

## Verification Plan

### Automated Tests
- **Backend Relay Tests:** `backend/tests/integration/test_voice_relay.py` to assert correct Socket.IO event relay and authentication boundary checks.
- **Provider & Transport Channel Tests:** Unit tests in `sanadagent-local/test/voice_channels_test.dart` and `test/gemini_provider_test.dart` to verify packet throughput, events mapping, and error handling.

### Manual Verification
1.  **Local Scope Check:** Connect client and daemon on the same machine. Start voice conversation and verify local audio playback at 24kHz and local interruption response.
2.  **Cloud Scope Check:** Run daemon on desktop and client on a mobile simulator. Verify that voice audio chunks are relayed successfully through the backend over Socket.IO and voice conversation functions seamlessly.

---

## Tasks Checklist

### Phase 1: Stubbing & Dependency Removal (Completed)
- [x] Remove `livekit_client` and `livekit_components` from `sanad-client/pubspec.yaml`
- [x] Run `fvm flutter pub get` successfully
- [x] Create `livekit_stubs.dart` to mock all required LiveKit components and avoid build/load errors
- [x] Redirect all imports of `livekit_client` and `livekit_components` to the stub file
- [x] Remove LiveKit server settings from `backend/app/core/config.py`
- [x] Run static analysis (`fvm flutter analyze`) and verify it compiles with zero errors
- [x] Run backend pytest suite and verify all 130 tests pass

### Phase 2: WebSocket Voice Integration (In Progress)
- [x] **Backend (`backend/`)**
  - [x] Implement binary PCM streaming relay in Socket.IO manager (`manager.py`)
  - [x] Register events: `voice_audio_chunk`, `agent_voice_audio_chunk`, and `voice_control`
  - [x] Write backend integration tests for socket relay
- [x] **Local Daemon (`sanadagent-local/`)**
  - [x] Create `VoiceTransportChannel` abstract class and its implementations (`LocalWebSocketTransportChannel` and `CloudSocketIoTransportChannel`)
  - [x] Define `RealtimeVoiceProvider` interface and standard events (`AudioOutputEvent`, `TextResponseEvent`, etc.)
  - [x] Implement `GeminiRealtimeVoiceProvider` to connect directly to Gemini Live API
  - [x] Integrate local tool calling inside `GeminiRealtimeVoiceProvider`
  - [x] Update `VoiceEngine` to route packets between transport channel and provider
  - [x] Persist transcribed user inputs and agent responses in the session database history
  - [x] Add unit tests for channels and Gemini provider
- [x] **Client UI (`sanad-client/`)**
  - [x] Add connection scope checking to `AgentConnectionCoordinator`
  - [x] Create `VoiceStreamService` to record mic at 16kHz and play stream at 24kHz
  - [x] Route audio chunks to local WebSocket (local scope) or socket service (cloud scope)
  - [x] Add Microphone Icon button next to text input composer to trigger voice mode
  - [x] Implement `VoiceStreamCubit` and `VoiceStreamView` (integrated via `VoiceStreamPanel` in composer)

### Phase 3: Deep Clean & File Deletion (Future)
- [ ] Delete `sanad-client/lib/infrastructure/livekit/` directory completely
- [ ] Delete legacy LiveKit UI components and screens under `features/voice/`
- [ ] Remove LiveKit token generation endpoints and services from FastAPI backend
- [ ] Delete Python Agent LiveKit worker scripts (`run_eaststar_ai.py` and `eaststar_ai_agent.py`)
- [ ] Delete legacy LiveKit integration test files under `agent/tests/`

### Phase 4: Future Dictation & Multi-Provider Support (Future)
- [ ] Implement local Dictation Mode (STT Dictation Button in composer row) to pipe mic audio to daemon and stream transcripts directly into composer `TextField`
- [ ] Stream user and agent live text transcripts into the active chat message list during voice session (Live Text Streaming)
- [ ] Implement `OpenAiRealtimeVoiceProvider` to support OpenAI's Realtime API
- [ ] Implement local offline voice provider fallback (`LocalRealtimeVoiceProvider` using sherpa-onnx/Piper)


