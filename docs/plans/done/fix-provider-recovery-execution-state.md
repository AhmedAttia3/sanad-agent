---
title: "Provider recovery execution-state convergence"
status: "complete"
---

# Provider recovery execution-state convergence

## Problem

When a provider retry is waiting and a provider change aborts that wait, the
runner refreshes its route and continues without reclaiming the durable work
item from `waiting` to `resuming`. Model output can continue while the
authoritative execution snapshot remains `waiting`, leaving the client sidebar
on its clock indicator and causing the terminal commit to be rejected because
recovery still owns the work item.

## Ownership and design

- Keep the daemon execution snapshot authoritative; the client must not infer
  execution from `thought_stream` or runtime-notice clearance.
- Reuse the existing owner-checked retry claim after an interrupted wait.
- Treat Stop as cancellation, but require every non-Stop wakeup to reclaim the
  exact work item/run/generation before another provider attempt begins.
- Preserve route refresh after the successful claim so provider changes take
  effect on the next attempt.

## Verification

- A focused runner regression starts with durable `running` work, reaches
  `waiting`, changes route, aborts the wait, and observes `resuming` before the
  next provider call.
- Successful resumed output commits the work item and ends at `idle` rather
  than `recoveryOwnsState`.
- Existing provider-recovery and authoritative-state tests remain green.
- Agent analysis passes.

## Full transition audit

After the focused fix, audit every producer and consumer of
`SessionWorkState` and `SessionExecutionState` across admission, queueing,
provider recovery, automatic failover, manual retry, provider change, Stop,
restart restoration, and terminal commit. Technical inconsistencies are fixed
with focused regressions. Any transition whose desired behavior depends on a
product choice rather than durable ownership or safety is recorded and raised
for explicit product direction before implementation.

## Audit findings implemented

- Interrupted retry wakeups now claim `waiting -> resuming` before another
  provider call.
- Provider failures during `resuming` now return to `waiting` or `blocked`
  instead of leaving a false busy snapshot.
- Fatal notices project durable execution as `blocked` because the work-state
  graph has no fatal terminal owner.
- Atomic auto-failover now publishes its committed execution snapshot through
  the canonical execution stream.
- Resuming notices preserve the current run owner and clear only on real
  provider progress.
- Controlled restart now waits for executing tools to persist a safe
  `after_tool_result` checkpoint before the daemon exits.

The complete work-state graph was checked against admission, queueing, Stop,
retry, provider handoff, automatic failover, restart restoration, checkpoint
metadata writes, and terminal commit. No additional ambiguous transition
remains after confirming that a daemon Restart must continue the active turn.
