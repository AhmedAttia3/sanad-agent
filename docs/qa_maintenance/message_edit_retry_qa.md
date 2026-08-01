---
title: "Message Edit and Retry QA Matrix"
description: "Quality Assurance matrix and test cases for the message edit and retry flow."
---

# Message Edit and Retry QA Matrix

## Inline presentation

- The latest durable user bubble exposes Edit and Retry.
- Edit replaces that bubble with one multiline input in place.
- Send and Cancel render below the input at the leading edge.
- Desktop Enter submits, desktop Shift+Enter inserts a newline, and Android/iOS software-keyboard Enter inserts a newline without submitting.
- Cancel restores the original message without a protocol command.
- Session, device, and New Conversation navigation discard the inline draft.
- Pending confirmation/dispatch disables duplicate Edit, Retry, Send, and Cancel actions.

## Boundary validation

- A latest user turn with a raw request identity can be retried.
- A legacy user event without request identity has no replay controls.
- An older user turn is rejected and newer messages remain unchanged.
- A stale or missing target does not mutate history.
- Accepted replay removes only the latest target turn projection and its assistant/tool artifacts before the replacement echo.

## Authoritative idle transition

- Running, waiting, blocked, and resuming sessions stop before replacement dispatch.
- Stopping never admits the replacement turn until the daemon reports idle.
- Queued and pending work owned by the same session cannot mix with the replacement turn.
- Stopping session A does not alter execution or history in session B.
- Repeated replay commands produce at most one accepted replacement turn.

## Tool replay safety

- No-tool and fully replay-safe turns proceed without warning.
- Any explicitly unsafe tool produces the side-effect warning.
- Missing safety metadata produces the unknown-safety warning.
- Canceling the warning sends no confirmed replay, Stop, or history mutation.
- Continuing sends explicit confirmation and then crosses the idle boundary.

## Route selection

- Retry and Edit Send carry the provider instance, model, and thinking mode currently selected in the composer.
- A selection changed while the warning is open is read again for the confirmed request.
- The daemon does not restore the original turn route implicitly when current route fields are supplied.

## Recovery

- Transport timeout leaves the original timeline visible.
- Reopening the session after acceptance hydrates the truncated durable history plus the replacement turn.
- Reconnect cannot resurrect the superseded target turn from a stale live projection.
