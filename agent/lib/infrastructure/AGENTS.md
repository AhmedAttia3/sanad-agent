# Agent Infrastructure Contract

## Scope
This contract applies to `agent/lib/infrastructure/`.

## Ownership
- Implement OS/platform and voice infrastructure behind domain-owned interfaces.
- Keep platform detection, filesystem permissions, process integration, and vendor transport details out of engine and presentation-neutral runtime owners.
- Infrastructure implementations must not become sources of provider, session, capability, or protocol truth.

## Platform Safety
- Normalize host-specific path, shell, permission, and service behavior behind typed abstractions.
- Preserve owner-only secret/auth permissions where the platform supports them and use equivalent user-restricted ACLs on Windows.
- Keep local services bound to configured loopback endpoints and dynamic ports.
- Do not infer remote filesystem roots or shell semantics from the client platform.

## Voice Infrastructure
- Keep transport channels separate from realtime voice-provider implementations and from the voice engine.
- Local and cloud channels carry equivalent audio/control semantics without embedding conversation ownership.
- Preserve canonical run, model-step, tool-call, and event identities when voice activity produces conversation events.
- Voice transport failure must not terminate text interfaces or the daemon event loop.
- Detailed codec, sampling, and channel design belongs to `docs/technical/voice_streaming.md`.
