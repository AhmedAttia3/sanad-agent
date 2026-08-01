---
title: "Message Turn Replay Protocol"
description: "Technical specification and protocols governing historical message turn replay and recovery."
---

# Message Turn Replay Protocol

## Ownership

Historical edit/retry is a daemon-authoritative latest-turn replay operation. It is distinct from `session.runtime_retry`, which resumes a suspended provider request.

The durable raw `request_id` on the user `Message` identifies the turn boundary. A target is valid only when it resolves to the latest persisted user message in the session.

## Command

`session.turn_replay` carries:

- `session_id`
- `request_id`: identity of the replacement user turn and command correlation
- `target_request_id`: raw identity of the user turn being replaced
- `action`: `edit` or `retry`
- `message`: required non-empty replacement text for `edit`
- `confirmed_replay_unsafe`: explicit user confirmation, default false
- optional current `provider_instance_id`, `model_id`, and `thinking_mode`

## Result

`session.turn_replay_result` carries the same session, command, and target identities plus:

- `outcome`
- `replay_safety`: `safe`, `unsafe`, or `unknown`
- `requires_confirmation`

Important outcomes include `accepted`, `confirmation_required`, `turn_boundary_not_found`, `not_latest_turn`, `session_not_idle`, `stale_turn_boundary`, and `already_in_progress`.

## Replay safety

The target turn is `safe` when it has no tool calls or every tool call has durable replay-safety value true. Any explicit false is `unsafe`. Missing work-item or per-tool metadata is `unknown` and fails closed to confirmation.

Classification occurs before cancellation. An unconfirmed `unsafe|unknown` request returns `confirmation_required` without changing execution or history.

## Idle boundary and history mutation

After safety acceptance, the daemon serializes replay for the session and applies this order:

1. Stop/cancel active, queued, waiting, blocked, or resuming work scoped to the target session.
2. Read the authoritative execution snapshot and require `idle`.
3. Revalidate that the persisted target is still the latest user turn.
4. Remove the target user message and assistant/tool artifacts after it.
5. Emit `accepted` and dispatch one replacement turn using the route fields supplied by the final command.

The accepted result lets clients truncate the same timeline segment before the replacement user echo arrives. Normal canonical user/tool/final events then rebuild the replacement turn. Other sessions are untouched.

## Compatibility

Messages created before durable user `request_id` persistence are non-replayable. The daemon returns a boundary failure instead of matching by text or timestamp.
