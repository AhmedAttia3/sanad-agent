# Task 58 — Safe Daemon Restart and Ambiguous Tool Recovery

## Problem

Controlled daemon restart currently waits at most 30 seconds for durable restart-safe checkpoints, then exits even when one or more running tools remain unsafe. The local restart endpoint also reports success before the safety decision is known. A forced exit can therefore leave a non-idempotent tool marked as executing without a completed result. Startup correctly blocks that ambiguous work, but every later manual Retry reaches the same restore guard and fails again, trapping the conversation indefinitely.

A restart invoked by an agent tool has a self-dependency: the invoking tool cannot persist its result until the restart HTTP response is returned, while the daemon must not exit until that result reaches a durable checkpoint.

## Goals

1. Drain restart safety across every active session, not only the requesting session.
2. Accept `force` and `timeout_seconds`; default timeout is 60 seconds.
3. Use one HTTP response:
   - safe restart returns success only after all non-requester blockers are safe;
   - non-forced timeout returns a clear failure and does not exit;
   - forced timeout returns success and exits only after the response is flushed.
4. Preserve the requester-tool handshake: after the one response is delivered, wait for its durable completion checkpoint before a normal restart exit.
5. Prevent new work from making the global restart drain boundary unsafe.
6. Keep automatic startup recovery fail-closed for ambiguous non-idempotent tools.
7. Make an explicit manual Retry/Change Provider controllable: do not replay an ambiguous non-idempotent tool; persist a neutral interrupted/unknown-outcome tool result, clear executing ownership, and continue the model loop.
8. Never claim that interruption was caused by force restart unless the cause is independently durable and proven.
9. Preserve the exact worktree-scoped Flutter launch profile across `sanad-dev restart client` and `reload client`; never replace dynamic gateway/home/preferences defines with primary-checkout defaults.

## Design

### Restart request

`DaemonRestartCoordinator` owns one serialized restart attempt and returns a typed result. It starts a global drain in `SessionRunOrchestrator`, waits up to the requested timeout, and reports blocking session/tool identities without tool arguments.

The local HTTP endpoint parses `force` and `timeout_seconds`, awaits the coordinator, writes exactly one response, then allows the coordinator to exit only after the response callback completes. A timeout with `force == false` cancels the drain and leaves the daemon running. A timeout with `force == true` exits with the latest durable state after replying.

When the restart request originates inside a daemon tool, that tool is the one unavoidable requester blocker. The restart boundary must identify it explicitly rather than guessing. Other active sessions must reach safe checkpoints before success. After the response is delivered, normal restart waits for the requester tool result to become durable before exit.

### Ambiguous manual recovery

Checkpoint restore keeps its strict default for automatic startup. Explicit user recovery supplies a manual policy that converts each executing, non-replay-safe tool lacking a durable result into a bounded neutral error result whose completion state is unknown. This repair and removal from `currently_executing_tools` are persisted before model continuation; the original side effect is never re-executed.

The repair must use the durable assistant tool-call batch even when
`resume_history_length` points to the earlier model-request boundary. Completed
results remain completed, ambiguous started tools receive the neutral result,
and tools that provably never started remain eligible for ordinary execution.
The repaired batch must contain one provider-visible result for every original
tool call before model continuation.

### Review hardening decisions

- A controlled restart drain closes admission for queued, restored, and newly
  received turns. Incoming work remains durable and FIFO, and is released only
  when the drain is cancelled or by startup recovery after a successful exit.
- Waiting for restart safety must not serialize the local HTTP/WebSocket accept
  loop. Health, stop, and existing runtime traffic remain responsive.
- Permanent stop wins over an in-progress restart and cancels its drain;
  concurrent restart attempts fail immediately as already in progress.
- Client launch discovery must reconstruct exact process arguments on each
  supported desktop platform rather than tokenizing a lossy process listing.
  The matched Sanad Home and preferences namespace are validated against the
  current runtime and any incomplete or contradictory profile fails closed.

### Worktree-safe client restart

Client discovery extracts the exact non-secret Flutter launch profile from the matched live `flutter run` command: config-file arguments, compile-time defines, target, and device. Attach/restart reuses that profile instead of injecting `config/local.json`. Linked-worktree restart validates the worktree marker, branch, Sanad Home, preferences namespace, and local gateway port against the currently running worktree agent. Missing or contradictory identity fails closed. Flutter attach always uses the worktree FVM SDK or `fvm flutter`; it never falls back to a global Flutter executable.

## Verification

- Coordinator unit tests: all-session wait, 60-second default contract, configurable timeout, non-forced timeout does not exit, forced timeout exits only after response completion, and concurrent restart serialization.
- Local endpoint tests: valid/default flags, invalid timeout, one response with blocker reason, and requester identity propagation.
- Runtime checkpoint tests: sequential completion clears executing state atomically.
- Recovery tests: startup remains blocked; manual Retry and Change Provider synthesize neutral unknown-outcome tool results, execute no duplicate side effect, and reach a terminal/controllable state.
- Multi-session restart regression: a second session with an unsafe tool blocks restart; force/non-force outcomes follow policy.
- Client launch-profile tests: two simultaneous worktrees remain isolated after attach restart/reload; missing profile fields or a gateway/worktree mismatch fail closed; no hardcoded `config/local.json` or global Flutter fallback remains.
- Run `fvm dart analyze`, focused tests, required daemon-backed restart coverage, and `graphify update .`.

## Definition of Done

- No normal restart exits while any non-requester tool has ambiguous execution state.
- A non-forced timeout produces one explicit failure response and leaves the daemon available.
- A forced timeout produces one response and exits deliberately with durable ambiguity preserved.
- Manual Retry cannot loop forever on the same ambiguous non-idempotent tool and cannot replay its side effect.
- Relevant architecture and QA documentation describe the final protocol and recovery semantics.
