---
title: "sanad-dev Runtime Ownership and Continuous Source Handoff"
description: "Unify clone isolation, managed-launcher ownership, safe orphan reconciliation, and same-tool-call source-switch completion."
status: "completed"
---

# sanad-dev Runtime Ownership and Continuous Source Handoff

## Goal

Make `sanad-dev` the authoritative owner of development runtime groups across
primary checkouts, linked worktrees, independent clones, IDE/manual launches,
and source handoffs. Every mutating command must prove ownership before acting.
An authorized `switch --runtime current` must preserve the active session and
return its terminal `complete` or `rolled_back` outcome through the original
tool call without requiring a follow-up `status`.

This file is the single task plan for both the completed independent-clone
hardening and the remaining managed-runtime/handoff work.

## Incident and source triage

SANAD-11 public-clone verification exposed three ownership gaps that combine into an unsafe stop path:

1. `discoverSanadDevRuntime` equates every non-linked Git checkout with the primary checkout, selecting the primary Sanad Home and agent port even when the checkout is an independent clone.
2. `handleRuntimeStatus` gives inherited requester gateway variables priority over the caller workspace hash, so a command in one checkout can display another checkout's agent.
3. `selectRuntimeProcessState` treats a Flutter process as relevant when only its source directory matches. `handleRuntimeStop` then signals every relevant client without validating its gateway agent, Home, preferences namespace, workspace marker, or launch profile.

The existing source-switch record is also rendered as current activity (`Source switch`) even though it is historical state.

### Same-request replay race correction

A live main-to-worktree or worktree-to-main handoff exposed a continuation race:
the launcher accepted the requester-bound switch and the restart boundary
persisted its deferred result, but startup `HistoryHealer` inserted a synthetic
cancellation for the still-unanswered shell tool before resume consumed that
result. The resumed model then invoked `switch` again while no Flutter client
was discoverable, returned `Switch aborted: the selected agent has no
discoverable clients`, and the original launcher transaction completed.

The correction must preserve deferred result ownership during history healing:

- collect requester-bound deferred tool-call ids from non-terminal durable work
  items before healing loaded history;
- never synthesize cancellation for a tool whose valid deferred descriptor owns
  the eventual launcher result;
- ignore malformed, cross-session, mismatched-tool, completed, and cancelled
  deferred metadata;
- retain normal history healing for genuinely abandoned unanswered tools;
- cover deferred protection and metadata filtering with focused unit tests and
  document the replay behavior in the runtime source-switch QA matrix.

## Ownership model

A normal command derives its runtime identity from the invoking Git workspace. Environment requester ports are ignored outside the explicitly authorized source-switch selector. An explicit `--port` remains a diagnostic selector where the command contract permits it, but it does not prove mutation ownership.

A client is owned only when all available identity dimensions agree:

- its gateway targets the selected workspace-owned agent;
- its source root matches the selected runtime source;
- its launch profile is complete;
- its Sanad Home and preferences namespace are internally consistent;
- its workspace hash marker matches the invoking workspace;
- linked-worktree name and branch markers match when applicable.

A source-matched client connected to another workspace agent is cross-owned. A client with missing or contradictory identity is ambiguous. Either classification blocks mutation of the entire selected group. Process termination and agent-stop transport are injectable so ownership tests cannot signal real processes.

Independent clones retain the normal primary experience only while no conflicting primary runtime is active. If the canonical primary endpoint is owned by another workspace, a standalone clone fails closed and requests an explicit absolute `--home`. An absolute Home selects workspace-hashed agent and VM-service ports plus a Home-derived preferences namespace.

## Managed runtime model

A process group is **managed** only when a live `sanad-dev run` launcher owns it
through one runtime identity containing:

- a random runtime nonce;
- the launcher PID and a live process check;
- the workspace hash, source root, Agent port, Sanad Home, and preferences
  namespace;
- every attached client PID, VM-service port, device, and launch profile;
- a launcher-owned runtime record updated atomically across source handoff.

`SANAD_DEV_SWITCH_CAPABLE=true` or a workspace hash alone never proves launcher
ownership. Manual Terminal/IDE processes are classified separately:

- **manual:** complete source/gateway identity but no live launcher lease;
- **orphaned:** only part of the runtime group remains;
- **cross-owned:** identity belongs to another runtime/workspace;
- **unverifiable:** required identity is absent or contradictory;
- **ambiguous:** more than one candidate can own the requested operation.

Only a fully managed group may switch. Ordinary mutation fails closed for every
other class unless the user invokes one explicit reconciliation command whose
preflight proves its exact bounded target.

## Command behavior

### Idempotent run

- If the current workspace already owns a healthy managed runtime,
  `sanad-dev run` prints its status and exits successfully without launching a
  duplicate.
- Manual, orphaned, cross-owned, unverifiable, and ambiguous states never cause
  implicit process termination.
- A primary/clone resource conflict remains fail-closed.

### Doctor

`sanad-dev doctor` is read-only and reports runtime class, ownership evidence,
launcher lease, source/target conflicts, active handoffs, and exact safe next
actions. `doctor --fix` may repair only stale files/leases whose owner PID and
runtime endpoints are both absent. It never signals a live process.

### Takeover

`sanad-dev takeover` converts a complete manual pair into a managed pair only
through a controlled relaunch that preserves the proven Home and endpoints.
It requires explicit user authorization, refuses ambiguous/incomplete groups,
and cannot target the requester runtime while an active session depends on it
unless the same durable drain, continuation, rollback, and terminal-result
contract as source switch is used.

### Target orphan cleanup

`sanad-dev cleanup-target-orphans` is an explicit, target-only operation:

- it can never select the source Agent port, source launcher nonce, requester
  session runtime, or any client attached to that source;
- it accepts only source-matched target processes with no live owning launcher
  or Agent and no contradictory Home/preferences identity;
- it prints and validates every PID before mutation;
- it refuses cross-owned, unverifiable, ambiguous, or live IDE-owned groups;
- failure prevents creation of the switch request.

No generic `replace` option exists.

## Continuous source-switch result contract

`switch --runtime current` is a durable two-phase handoff owned jointly by the
launcher and daemon runtime:

1. The CLI performs complete source/target/lease/port/Home/client preflight and
   persists a transaction correlated to requester session id and tool-call id.
2. The originating shell tool records a typed deferred-result descriptor rather
   than a terminal `Switch accepted` result.
3. The restart coordinator permits drain only after that descriptor is durable;
   it never waits for a terminal result that requires the daemon to exit.
4. The launcher drains the source, starts and verifies the target group, and
   atomically records `complete`; on target failure it restores and verifies the
   previous group and records `rolled_back`.
5. Startup recovery resolves the deferred descriptor exactly once and persists
   the terminal output as the original tool-call result.
6. The restored model turn therefore receives one of:
   - `complete`: target source is healthy and the session resumed there;
   - `rolled_back`: target failed, previous source is healthy, and the session
     resumed there;
   - `recovery_failed`: neither target nor previous source could be verified;
   - `failed`: preflight/drain failed before source replacement.

`Switch accepted` is progress only and is never exposed as the terminal tool
result. `status` continues showing `Last source switch` for diagnostics, but is
not required for the requester to learn the outcome.

## Safety invariants

- Source runtime protection is evaluated before any cleanup, takeover, or
  switch mutation.
- A preflight failure changes no process and writes no active handoff.
- All process-group mutations belong to the live launcher; helper CLIs do not
  kill independently discovered clients and then attempt Agent shutdown.
- Explicit `--port` is diagnostic unless the command has a separate
  authorization contract and revalidates ownership.
- A transport/termination failure is reported as partial/failed and can never
  be printed as `Stopped`.
- Runtime records and handoff records are atomic, versioned, port-scoped, and
  validated against the live launcher nonce.
- Deferred results contain no secrets or command output beyond bounded,
  redacted terminal diagnostics.

## Implementation checklist

- [x] Extend runtime context with an explicit primary-resource/isolation mode and pure conflict detection for standalone clones.
- [x] Add a workspace-hash client launch marker and a reusable client ownership validator.
- [x] Replace source-only process selection with owned, cross-owned, and ambiguous client classifications shared by `run`, `status`, `stop`, and developer-action discovery.
- [x] Remove inherited requester-port selection from ordinary status/stop paths while preserving explicit-port diagnostics and the authorized switch selector.
- [x] Make stop preflight all selected clients before invoking injectable client termination or agent-stop transport.
- [x] Render cross-owned/ambiguous clients without recommending stop and label handoff state as `Last source switch`.
- [x] Preserve source-switch group ownership by replacing the workspace-hash marker during an authorized handoff without changing its approval contract.
- [x] Update the developer design guide, technical ownership design, QA matrix, machine index, and closest runtime contract.
- [x] Add versioned launcher identity/lease records and propagate the runtime
  nonce to Agent and client processes.
- [x] Extend discovery/status with managed, manual, orphaned, cross-owned,
  unverifiable, and ambiguous classifications.
- [x] Make `run` idempotent for a healthy managed runtime.
- [x] Split diagnostic selectors from mutating selectors; explicit ports cannot
  mutate foreign runtime groups.
- [x] Move complete-group stop under verified launcher ownership and make every
  partial failure observable.
- [x] Add read-only `doctor` and bounded stale-record `doctor --fix`.
- [x] Add controlled `takeover` for a fully proven manual pair.
- [x] Add source-protected `cleanup-target-orphans`; do not add generic replace.
- [x] Require a live launcher lease for source switch and preserve it across
  target/rollback launches.
- [x] Persist a typed deferred switch result before drain and teach controlled
  restart safety to accept that exact durable requester descriptor.
- [x] Resolve `complete`, `rolled_back`, `failed`, or `recovery_failed` into the
  original tool call exactly once after startup recovery.
- [x] Keep `Last source switch` as historical diagnostics only.
- [x] Update Agent/runtime contracts, technical design, developer guide, QA
  matrix, and machine index for the unified behavior.

## Automated definition-of-done checklist

- [x] Conflict-free primary defaults.
- [x] Linked-worktree Home and port isolation.
- [x] Standalone-clone conflict refusal and explicit absolute-Home isolation.
- [x] Inherited requester port ignored by normal selection.
- [x] Explicit port selection retained for diagnostics.
- [x] Cross-owned, missing-profile, contradictory-profile, and workspace-hash client refusal.
- [x] Stopping only a completely owned fake client/agent group through injected fakes.
- [x] Dry-run classification and messaging without process/runtime mutation or a stop recommendation.
- [x] Historical source-switch wording.
- [x] Inactive linked worktree returns `No active sanad-dev runtime found` without selecting primary.
- [x] No ownership test path calls `Process.killPid`, a real agent stop endpoint, or live process discovery.
- [x] Managed lease validation rejects missing, stale, PID-reused, mismatched,
  and nonce-mismatched launchers.
- [x] `run` is a successful no-op for one healthy managed group.
- [x] Manual/orphaned/foreign states never trigger implicit cleanup.
- [x] `doctor` is read-only; `doctor --fix` removes only proven stale records.
- [x] Takeover preserves proven identity or rolls back without stranding the
  source group.
- [x] Target cleanup cannot select the requester/source runtime and refuses a
  live IDE owner.
- [x] Explicit diagnostic ports cannot restart, reload, stop, or switch a
  foreign group without the command-specific authorization contract.
- [x] Stop transport/client termination failures never report full success.
- [x] Switch preflight failure leaves the source untouched.
- [x] Target success returns `complete` through the original tool call.
- [x] Target failure plus successful restoration returns `rolled_back` through
  the original tool call and resumes the same session.
- [x] Target and restoration failure returns `recovery_failed` without claiming
  session continuity.
- [x] Deferred switch completion is persisted exactly once across duplicate
  startup recovery.
- [x] Status shows the same final historical outcome without being needed by the
  requester.
- [x] Unit tests cover protocol parsing, ownership classification, and all
  terminal states.
- [x] SQLite-backed restart tests cover durable deferred-result recovery.
- [x] Daemon-backed isolated E2E covers one successful switch and one forced
  target-start failure with verified rollback; tests never target the active
  primary runtime.

## Verification checklist

- [x] Format the modified Dart files with FVM.
- [x] Run focused `sanad_dev` ownership and source-switch tests.
- [x] Run the complete fast `client/test/unit/scripts` suite.
- [x] Run `fvm flutter analyze` for the owning client/test package.
- [x] Generate the machine-readable documentation index.
- [x] Run the documentation linter successfully.
- [x] Run `graphify update .` after code changes.
- [x] Repeat final bounded analyzer/tests/docs lint after the last review edits.
- [x] Run final `git diff --check` and review the complete changed-file set.
- [x] Mark this plan complete after every final check passes.
- [x] Format and analyze every changed Dart surface with FVM.
- [x] Run focused launcher/ownership/switch/deferred-result tests.
- [x] Run the complete fast `client/test/unit/scripts` suite.
- [x] Run focused and full fast Agent suites for runtime/checkpoint changes.
- [x] Run the required isolated daemon-backed E2E with unique temporary Home,
  ports, and deterministic provider.
- [x] Run documentation generation/lint, `git diff --check`, and
  `graphify update .`.
- [x] Review all changed files, record exact results, and mark this unified plan
  complete only after every unchecked gate passes.

## Verification results

- Dart formatting: 26 changed files checked; no formatting changes remained.
- Flutter analyzer: no issues.
- Agent analyzer: no issues.
- Complete `client/test/unit/scripts` suite: 57 tests passed.
- Complete Agent suite: 946 tests passed with 2 skipped.
- Isolated source handoff: target success returned `complete`; forced target
  startup failure returned `rolled_back`, restored the same Home and ports, and
  left the previous source managed.
- Isolated manual takeover: `doctor` classified the pair as `manual`;
  `takeover` crossed the safe checkpoint, permanently stopped the old
  supervisor, relaunched the pair as `managed`, and launcher-owned `stop`
  removed the complete group.
- Documentation generation and lint: success.
- Graphify incremental update: success.
- Primary runtime: not targeted or mutated.

Live primary runtime control, canonical primary endpoint targeting, and source
handoff of any user-owned runtime are prohibited during implementation. All
system-boundary verification must use isolated disposable runtime groups.
