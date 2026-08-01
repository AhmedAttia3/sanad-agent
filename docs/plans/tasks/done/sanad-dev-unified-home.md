---
title: "Sanad Dev Unified Home"
description: "Use one worktree-scoped Sanad Home, support user or absolute home selection, and enable cloud by default."
---

# Sanad Dev Unified Home

## Goal

`sanad-dev` launches a daemon/client pair with one Sanad Home containing identity, authentication, provider configuration, state database, memories, and runtime files. It does not inject `SANAD_STATE_HOME`.

## Runtime Policy

- A linked worktree defaults to `~/.sanad/dev/homes/<worktree-id>`.
- The primary checkout defaults to the ordinary Sanad Home, honoring `SANAD_HOME` when already configured and otherwise using `~/.sanad`.
- `sanad-dev run --home user` selects the primary user's Sanad Home, honoring a configured `SANAD_HOME` and otherwise resolving `~/.sanad`.
- `sanad-dev run --home <absolute-path>` selects an explicit unified home; other relative values are rejected.
- Existing worktree state under the former `~/.sanad/dev/state/<worktree-id>` location is not migrated.
- Cloud and local connections are enabled by default; `--no-cloud` selects local-only mode and `--cloud` remains an explicit compatibility option.

## Implementation

1. Replace `SanadDevRuntime.stateHome` with `sanadHome` and serialize `sanad_home` in runtime metadata.
2. Resolve the default or explicit home during worktree discovery.
3. Pass `SANAD_HOME` to both spawned processes, remove inherited `SANAD_STATE_HOME`, and pass the same path to Flutter through a compile-time define.
4. Derive and inject a deterministic SharedPreferences prefix for isolated/custom homes before any preference access; primary and `user` homes preserve the default namespace.
5. Make desktop client settings honor the injected Sanad Home while preserving the packaged default at `~/.sanad`.
6. Update status output, contracts, design documentation, and command help.

## Verification

- Runtime tests cover linked/default/user/absolute home resolution, metadata, and deterministic preference namespace isolation.
- CLI policy tests cover cloud-default/local-only selection plus user/absolute acceptance and relative rejection without launching processes.
- Client settings tests cover an explicit Sanad Home without adding another `.sanad` segment.
- Static analysis and focused tests pass.
- No runtime is launched as part of verification.
