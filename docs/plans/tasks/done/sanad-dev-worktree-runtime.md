---
title: "Sanad Dev Worktree Runtime"
description: "تصميم مشغل تطوير موحد يعزل حالة الوكيل ومنافذه لكل Git worktree ويجهز Flutter للاختبار البشري والتفاعلي."
---

# Sanad Dev Worktree Runtime

## Problem

Parallel development worktrees currently require developers and AI agents to coordinate local daemon ports, Flutter VM service endpoints, and runtime state manually. The existing `sanad-dev` utility can discover and control running processes, but it cannot launch a matched daemon/client pair, it loses the caller worktree when invoked through a global symlink, and parts of the Flutter client still probe the fixed daemon URL on port `58085`.

Using one writable Sanad Home for concurrent processes is unsafe because identity, credentials, sessions, scheduled tasks, memories, and request dumps can overlap. The original split-state decision has been superseded: linked worktrees now receive one complete worktree-scoped Sanad Home, while the primary checkout retains the normal Sanad Home.

## Target Design

`sanad-dev` resolves the Git worktree from the caller directory and derives a stable runtime identifier from its canonical path. The main checkout prefers the default daemon port, while linked worktrees deterministically probe an isolated port range. Every run records process and endpoint metadata beneath the user's Sanad development runtime directory. The CLI entry point remains thin; runtime context, process supervision, instance discovery, and developer actions live in focused modules under `scripts/sanad_dev/`.

The daemon and Flutter client use the same active Sanad Home. Linked worktrees resolve a deterministic home containing identity, provider credentials, configuration, session database, memories, and request dumps. The primary checkout retains the standard home, and an explicit absolute override may select another complete home.

The Flutter client receives the selected daemon URL through compile-time configuration. Development runs start local and cloud transports by default; explicit local-only mode suppresses the cloud session. Linked-worktree runs also receive a readable worktree name and branch so the home status bar can identify the isolated environment without exposing the internal hashed runtime identifier.

## Command Surface

- `sanad-dev run` launches the daemon and standard Flutter client for human review.
- `sanad-dev run --driver` launches `client/lib/driver_main.dart` with a stable VM service port for interactive UI tools.
- `sanad-dev status` reports the current worktree runtime and verifies recorded processes/endpoints.
- `sanad-dev stop` stops only processes recorded for the current worktree.
- Existing `logs`, `restart`, and `reload` commands remain compatible; current-worktree metadata is preferred before global process discovery.

The fixed backend URL continues to come from the selected client configuration. The local daemon URL, VM service port, cloud-mode flag, worktree identity, and unified Sanad Home are injected dynamically.

## Safety Boundaries

- Git is the source of truth for worktree discovery; directory-name pattern matching is not used.
- Runtime state is isolated per worktree without copying or relocating credentials.
- A run never edits checked-in environment or JSON configuration files.
- Process cleanup targets recorded child PIDs and validates daemon health metadata before control requests.
- Port allocation is deterministic when possible and always verifies availability before launch.
- `sanad-dev` keeps cloud enabled by default; local-only operation requires an explicit cloud-disable selection.

## Verification

1. Unit-test worktree identity, deterministic port selection, metadata serialization, and stale runtime detection.
2. Unit-test client compile-time local URL and isolated-cloud configuration.
3. Run Dart and Flutter formatting/static analysis before tests.
4. Run relevant agent and client unit tests sequentially.
5. From a linked worktree, run the launcher in validation mode, start a daemon on the allocated port, verify `/health` reports the same worktree path, and stop it without touching another daemon.
6. Launch driver mode on macOS when the desktop environment is available and verify the recorded VM service endpoint can be used by `inspect_ui.dart`.
7. Verify the home status bar renders the linked-worktree badge without overflow and omits it when no worktree label is injected.

## Documentation Definition of Done

- Update the repository and client/agent runtime contracts with the worktree runtime boundary.
- Update the developer setup design and machine-readable documentation index.
- Rewrite the Sanad client tester SOP to use current `sanad-agent/agent`, `sanad-agent/client`, and `bin/sanad_agent.dart` paths and the unified launcher.
- Remove related active references to the former `sanad-agent-local` and `sanad-client` directory names.
