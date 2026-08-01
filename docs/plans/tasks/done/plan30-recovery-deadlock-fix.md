# Plan 30 — Resumed Rate-Limit Recovery Handoff

## Problem

A session can remain trapped after this sequence:

1. A failed turn is suspended.
2. `session.runtime_retry` claims the suspended work and keeps `resumeSuspended` in flight.
3. The resumed runner encounters a retryable rate limit and enters a `waiting` notice.
4. `session.runtime_continue_with_provider` returns `alreadyResuming` because the first recovery command still owns `_resumingSessions`.

The recovery handler previously treated `alreadyResuming` as an unconditional no-op. The selected provider was therefore not applied and the active retry timer was not interrupted.

## Ownership Constraint

The in-flight resumed runner remains the valid owner of the work item. The fix must not cancel it and race a second `resumeSuspended` claim. `AgentRunner` already supports an interrupted retry handoff: after `RuntimeRecoveryService.abort` wakes `waitForRetry`, it reclaims its durable waiting state, refreshes the session route, and performs the next request.

## Implementation

`SessionRecoveryCommandHandler` now distinguishes two `alreadyResuming` states:

- `notice.status == waiting`: update the active runner and queued route, confirm the session route, abort the old retry timer, and emit `resuming`. The existing runner then reloads the confirmed route and continues.
- Any other notice: preserve the existing idempotent no-op behavior because a recovery command is genuinely progressing.

The same active-wait handoff is shared by Retry and Continue with Provider. Missing suspended work retains the existing controllable blocked fallback.

## Verification

`agent/test/interfaces/sanad_bridge_provider_test.dart` reproduces the complete sequence: initial blocked failure, manual resume, resumed rate-limit wait, provider change, and successful completion on the selected route. The assertions verify one continued run, ordered provider routes, persisted session route, and cleared recovery notice.
