---
title: "Message Edit and Retry UX"
description: "Specification for inline edit and retry of the latest user messages in the timeline."
---

# Message Edit and Retry UX

## Scope

Sanad exposes Edit and Retry only for the latest durable user turn whose canonical event carries a raw `request_id`. Older turns remain read-only because replaying one would discard newer user-owned turns and requires a separate conversation-branching design.

## Inline edit

- Edit replaces the user message body with an inline multiline input in the same timeline position.
- `Send` and `Cancel` appear below the input, aligned to its leading edge.
- Desktop hardware Enter submits the edit and Shift+Enter inserts a line break. Android/iOS software-keyboard Enter inserts a line break; the visible Send button submits the edit.
- Cancel restores the original bubble without contacting the daemon.
- Navigating to another session, device, or New Conversation cancels the transient edit draft.
- The edit controls are disabled while replay confirmation or dispatch is pending.

## Retry

Retry reuses the latest user turn text. Edit Send uses the edited text. Both use the provider instance, model, and thinking selection currently displayed when the final replay request is submitted.

## Tool side-effect confirmation

The daemon classifies the target turn as `safe`, `unsafe`, or `unknown` from durable tool-call and replay-safety metadata.

- `safe` proceeds without an extra warning.
- `unsafe` warns that file or external-system changes may repeat.
- `unknown` warns that Sanad cannot verify replay safety.
- Canceling the warning performs no Stop and no history mutation.
- Continuing submits an explicit confirmation and then enters the authoritative idle boundary.

## User-visible failure behavior

Sanad keeps the original timeline unchanged when the turn boundary is missing, the target is no longer the latest user turn, confirmation is declined, or the daemon cannot reach idle. Legacy messages without durable request identity are not guessed or replayed.
