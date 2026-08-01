---
title: "Provider API-Key Edit Verification Fix"
description: "Complete verification after adding or replacing an API key on an existing provider instance so a successful edit does not remain draft."
status: "completed"
priority: "high"
scope: "Flutter provider setup edit flow, agent secret-store reconciliation, focused regression tests, and provider setup documentation"
depends_on: "Task 57 provider management UX; Plan 29 provider credential revisions"
---

# Provider API-Key Edit Verification Fix

## Problem

Adding or replacing the API key of an existing provider correctly increments its
credential revision. The daemon then invalidates the model verification bound to
the previous revision and demotes the instance to `draft`. The Flutter edit flow
currently returns to the configured-provider list immediately and reports that
changes were saved without testing the new credential, so the instance remains
incomplete even when the new key is valid.

## Decision

Keep daemon fail-closed behavior unchanged. A credential revision must not remain
`ready` until the current endpoint/model combination has been verified with the
new secret. For an existing API-key instance, the Flutter save workflow must run
the canonical instance connection test after an explicit `replace` action and
only report successful completion after the test succeeds. `keep` and `remove`
retain their existing behavior.

If verification fails, keep the edit form visible and explain that the key was
saved but could not be verified. The instance remains non-ready according to the
daemon's authoritative status.

The secret file may contain records for UUIDs that no longer exist in provider
metadata after legacy or interrupted deletion/setup flows. Every mutating
credential operation reconciles the store against authoritative instance UUIDs
before changing the target record when state and secrets share one Sanad Home.
This preserves all live sibling credentials, removes orphaned records, and then
replaces the target UUID rather than allowing the file to retain stale entries
indefinitely. An explicit isolated state-home boundary disables pruning because
its shared secret file can legitimately contain ids from another state database.

## Definition of Done

- Replacing or adding a key on an existing instance invokes canonical connection verification before returning to the configured list.
- A successful verification reloads authoritative instances and reports success.
- A failed verification keeps the edit surface visible with safe, accurate feedback.
- New-instance setup and non-mutating `keep` behavior remain unchanged.
- Focused Cubit tests cover successful and failed existing-instance replacement.
- Agent tests prove replacement preserves live sibling secrets, replaces the target record, and removes orphaned UUID records.
- Provider protocol and QA documentation describe the completed edit workflow.
