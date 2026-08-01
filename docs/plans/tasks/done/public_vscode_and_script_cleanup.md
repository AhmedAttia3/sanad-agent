---
title: "Public VS Code Workflow and Script Cleanup"
description: "Provide portable VS Code workflows, remove obsolete scripts, and keep the public repository root focused before publication."
status: "completed"
---

# Public VS Code Workflow and Script Cleanup

## Goal

Make the standalone public repository convenient and safe to open in VS Code
without bypassing the managed `sanad-dev` runtime ownership model. Remove legacy
helpers that mutate tracked configuration or documentation using assumptions
from the private monorepo.

## Decisions

- Track only reviewed repository-level VS Code files through an allowlist.
- Launch full-pair development through the FVM-backed `sanad_dev.dart` entry
  point with the public repository root preserved as the caller workspace.
- Provide explicit manual-debug launch configurations for the Agent, client,
  and full pair, plus attach to an already running client. These configurations
  are intentionally classified as manual until an explicitly authorized
  `sanad-dev takeover` performs its controlled relaunch.
- Provide managed full-pair tasks, read-only `status` and `doctor` tasks, plus
  FVM analyzer tasks.
- Do not provide VS Code shortcuts for `switch`, `stop`, `restart`, takeover,
  cleanup, or any other ownership-sensitive mutation.
- Remove `scripts/update_local_ip.dart`; `sanad-dev` owns endpoint and port
  injection without rewriting tracked client configuration.
- Remove `scripts/reorder_plans.dart`; semantic plan paths and tracked links
  must not be renamed from filesystem timestamps.
- Retain `scripts/brand/generate_brand_assets.sh` and `scripts/community/` as
  reproducible public brand and governance tooling.
- Keep `README.md`, `README.ar.md`, `CONTRIBUTING.md`, and `SECURITY.md` at the
  repository root for immediate contributor and GitHub discoverability.
- Move repository-community policies to `.github/`: `CODE_OF_CONDUCT.md`,
  `SUPPORT.md`, and `GOVERNANCE.md`.
- Move the release-specific signing policy to
  `docs/operations/code_signing_policy.md`; keep `release/` and `shared/` at the
  root because build, update, and dependency contracts consume them directly.

## Definition of Done

- [x] `.vscode/launch.json`, `tasks.json`, and `extensions.json` are portable,
  contain no credentials or machine paths, and use only relative workspace
  variables.
- [x] Full-pair tasks preserve managed launcher ownership on macOS, Linux, and
  Windows through FVM.
- [x] The developer guide explains managed tasks, manual launch/compound debug,
  attach behavior, clone conflicts, and the explicit takeover boundary.
- [x] Brand generation documentation states its complete host-tool boundary.
- [x] Obsolete IP mutation and plan renumbering scripts are removed with no
  active references remaining.
- [x] JSON parsing, documentation lint, governance checks, analyzers,
  `git diff --check`, and Graphify update pass.
- [x] Community policy files move without content loss and remain discoverable
  through GitHub-supported `.github/` locations and updated repository links.
- [x] The code-signing policy moves under operations documentation while
  security classification, CODEOWNERS, and public navigation remain intact.
- [x] `release/` and `shared/` remain unchanged and all active links, governance
  validation, documentation lint, and Graphify update pass after the moves.

## Verification Results

- The three tracked VS Code JSON files parsed successfully and passed the exact
  CI allowlist, machine-path, and sensitive-mutation checks.
- The portable task invocation selected the current workspace correctly for
  `status` and read-only `doctor`. A local `run --no-cloud --dry-run` refused
  the existing manual primary runtime as designed and performed no mutation.
- Community governance validation passed with 43 labels and 15 YAML files;
  label synchronization and workflow simulations passed.
- Agent and client analyzers completed with no issues.
- Documentation generation and lint completed successfully.
- Active-source search found no references to either removed legacy script.
- `git diff --check` and `graphify update .` completed successfully.
- GitHub community policies moved to `.github/`; all repository and
  cross-policy links resolve at their new locations.
- The code-signing policy is indexed under operations documentation, remains a
  protected security path in CI/CODEOWNERS, and is linked from both READMEs.
- `release/` and `shared/` remained byte-for-byte unchanged by the root cleanup.
