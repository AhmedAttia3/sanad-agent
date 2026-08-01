---
title: "Suspended Input Restart Recovery"
status: completed
scope: "Daemon startup recovery, persisted permission/ask-user checkpoints, history healing, and orphan runtime notices"
---

# Suspended Input Restart Recovery

## Problem

A daemon restart while `system_ask_user` or a permission prompt is waiting for
the user leaves two durable facts:

1. The active work item still records the tool call in
   `currently_executing_tools`.
2. `suspended_checkpoints` records that the same tool call is waiting for user
   input.

Startup currently considers only the first fact. Because interactive tools are
not restart-replay-safe, it incorrectly classifies the work item as an
ambiguous interrupted side effect, changes it to `blocked`, and emits
`Execution interrupted`. The pending checkpoint is still hydrated, so answering
the prompt resumes model execution while the authoritative execution snapshot
remains blocked.

Runner construction also heals the unanswered tool call with a synthetic
`Tool execution cancelled by user.` result even though the matching suspended
checkpoint proves that the call is still pending.

A separate fallback bug amplifies any startup restoration exception:
`markRestoreFailureAsBlocked()` emits a recovery-failure notice for every
session that has historical work items, including sessions whose work is
entirely `completed` or `cancelled`. Those orphan notices remain visible on old
conversations.

## Invariants

- A matching unresolved suspended checkpoint is a durable waiting state, not
  evidence of an interrupted side effect.
- Startup may classify a running tool batch as interactive waiting only when
  every unresolved executing tool call is covered by an unresolved checkpoint.
- History healing must not synthesize results for unresolved suspended tool
  calls.
- A restart-restored answer must claim the active work item before resuming,
  transition it to `resuming`, and durably commit `completed` before publishing
  the terminal response.
- A startup fallback notice may be attached only to an active non-terminal work
  item.
- A persisted runtime notice with no active recovery-owned work is orphan state
  and must be removed during startup reconciliation.
- Truly ambiguous non-idempotent tool execution remains fail-closed and
  `blocked`.

## Implementation

1. Load unresolved suspended checkpoints before classifying running work.
2. Reclassify a fully covered interactive tool wait as `waiting`, without
   creating a runtime failure notice.
3. Teach history healing to exclude unresolved suspended tool-call ids.
4. Make persisted permission/ask-user resume claim durable ownership, restore
   the runner's authoritative owner, clear stale false notices, and commit the
   terminal work item before final delivery.
5. Restrict restore-failure fallback to active work and reconcile orphan
   notices on startup.
6. Update the technical suspension/recovery contract and the restart QA matrix.

## Verification

- Focused history-healer test preserves a pending suspended tool call.
- SQLite-backed startup test restores `system_ask_user` as `waiting`, keeps its
  checkpoint, emits no blocked notice, and preserves true unsafe-tool blocking.
- Persisted resume test proves `waiting -> resuming -> completed`, terminal
  delivery after commit, and stale false-notice cleanup.
- Startup fallback test proves completed/cancelled historical sessions receive
  no recovery notice.
- Orphan-notice reconciliation test proves polluted historical notices are
  deleted while a notice backed by active recovery work is retained.
- `fvm dart analyze` and the focused test files pass with bounded output.
- `graphify update .` completes after source changes.

## Result

- Interactive checkpoints now restore as `waiting`, including repair of the
  false `blocked` state written by older daemon versions.
- Persisted answers claim and complete the original durable work owner before
  terminal delivery.
- Pending interactive tool calls are excluded from synthetic history healing.
- Orphan notices are reconciled on startup and restore-failure fallback is
  limited to active work.
- `fvm dart analyze` passed.
- The complete agent test suite passed: 903 tests, with 2 skipped.
- `graphify update .` completed after the final source changes.
