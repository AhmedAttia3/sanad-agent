---
title: "Fix sanad-dev Attach for Primary IDE Clients"
description: "Allow safe restart/reload of primary-checkout Flutter clients launched by an IDE with canonical implicit defaults."
status: "complete"
priority: "high"
design_contract: "docs/operations/developer_guide.md"
---

# Fix sanad-dev Attach for Primary IDE Clients

## Problem

An IDE-launched primary-checkout client may expose an exact native argv with
`--dart-define-from-file=config/dev.json` but omit compile-time values whose
application defaults already select the canonical local daemon, primary Sanad
Home, and empty preferences namespace. `sanad-dev restart client` discovers the
correct VM service and source directory, then rejects the profile because those
values are absent from argv.

## Design

- Resolve implicit launch identity only for the primary checkout.
- Accept omission only when the matched daemon uses the canonical primary port,
  the runtime uses the canonical primary Sanad Home, and the missing preferences
  namespace therefore resolves to empty.
- Preserve every discovered compile argument exactly for `flutter attach`; do
  not inject a config file or alter compile-time behavior.
- Explicit values remain authoritative and contradictory values fail closed.
- Linked worktrees continue requiring explicit gateway, home, preferences,
  worktree, and branch identity.

## Verification

- Unit tests cover valid primary IDE argv, explicit conflicting values, a
  non-default daemon port, and unchanged linked-worktree rejection.
- Focused script tests and analyzer pass.
- The currently running primary client accepts `sanad-dev restart client` and
  reconnects to the matched daemon.

## Result

- Native discovery retained the IDE client's exact config and target arguments.
- Canonical primary defaults were resolved only for validation/environment; no
  compile argument was injected or overridden.
- Focused launch-profile suite: 18 tests passed.
- Script and Flutter analyzers: no issues.
- Live `sanad-dev restart client`: succeeded; files synced, application hot
  restarted, and local/cloud connections recovered without startup errors.
