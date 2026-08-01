---
title: "Task 62 — Session Title Generation Resilience"
status: "completed"
owner: "agent/evolution + interfaces/runtime + engine/adapters"
---

# Task 62 — Session Title Generation Resilience

## Problem

Conversation title generation is a background request that can be skipped after runtime resume, lost across daemon restart, left hanging by adapters that do not apply the requested timeout, or rejected by provider-compatible endpoints that do not support the configured output-token field. The current eligibility check infers title state from new-session/message state, and the title write cannot distinguish an automatic placeholder from a user-owned title.

## Design

1. Persist explicit title lifecycle state on each session:
   - `pending` for an automatic first-message placeholder awaiting intelligent generation.
   - `final` for generated, fallback, migrated, or manually renamed titles.
2. Mark only daemon-created automatic placeholders as `pending`; explicit client titles and migrated sessions remain `final`.
3. Trigger title work after every successful terminal completion when the authoritative session title state is `pending`, including resumed/recovered first turns. Compare-and-set must require both the captured title and `pending` state so manual rename/delete/newer completion still wins.
4. On daemon startup, scan pending sessions that already contain a user/assistant exchange and regenerate their titles from persisted history. Startup recovery updates durable state without requiring a stale transport connection; clients receive the title through normal hydration.
5. Keep the provider/model snapshot for live jobs. Apply the 30-second timeout at `TitleService` so every adapter is bounded.
6. Preserve the 500-token bound when supported. If a structured HTTP 400 response explicitly reports the provider output-token parameter as unsupported, retry once without the bound rather than falling back immediately.
7. Accept any non-empty cleaned title, including valid one- or two-character titles. Empty, malformed, network, authentication, quota, timeout, and other provider failures retain the bounded user-message fallback.
8. Keep final-answer delivery non-blocking and title jobs single-writer through durable compare-and-set state.

## Verification / Definition of Done

- Codex-style `Unsupported parameter: max_output_tokens` retries once without a token bound and persists the intelligent title.
- Unrelated HTTP 400 responses do not retry.
- The service-level timeout applies even when the adapter ignores request options.
- One- and two-character titles are accepted; empty/cleaned-empty output falls back.
- A resumed first turn with a pending placeholder schedules title generation.
- Existing sessions with final/manual titles do not schedule generation.
- Explicit initial titles are final; automatic first-message snippets are pending.
- Manual rename and deletion still defeat delayed background writes.
- Startup recovery upgrades pending sessions with a persisted first exchange.
- Migration preserves existing titles as final.
- Focused evolution/interface/adapter tests and `fvm dart analyze` pass.
- `docs/technical/agent_runtime.md`, `docs/technical/agent_database_schema.md`, and `docs/qa_maintenance/session_title_generation_qa.md` describe the final behavior.
