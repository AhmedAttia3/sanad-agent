---
title: "sanad-dev Orphan Client Status Consistency"
description: "Make run, status, and stop agree when an IDE leaves a Flutter client alive without a matching Sanad agent."
status: "completed"
priority: "high"
scope: "sanad-dev runtime process selection, diagnostics, focused regression tests, and developer guidance"
depends_on: "Fix sanad-dev Attach for Primary IDE Clients"
---

# sanad-dev Orphan Client Status Consistency

## Problem

Real-time discovery can find a Flutter client launched from the current source
tree after its matching Sanad agent has stopped or when an IDE launch never
started an agent. `sanad-dev run` correctly refuses to start a duplicate client,
but `sanad-dev status` previously hid that process because it listed clients only
after finding a matching agent. The resulting `not started` status contradicted
the subsequent `runtime is already active` error and gave no PID to clean up.

## Decision

Use one runtime-process selection model for `run`, `status`, and `stop`.
Distinguish clients paired to the selected agent from source-matched clients that
have no such pairing. A client-only state is reported as
`incomplete (client without matching agent)`, and diagnostics include the
device, VM-service port, and PID. Starting remains fail-closed and never kills an
IDE process automatically; `sanad-dev stop` is the explicit cleanup operation.

## Definition of Done

- `run`, `status`, and `stop` select matching agents and source clients through
  the same helper.
- A client-only runtime is not reported as `not started`.
- The `run` conflict explains that the Flutter client is unpaired and prints its
  PID, device, and VM-service port.
- `stop` terminates both paired clients and source-matched unpaired clients.
- Focused tests cover client-only and mixed paired/unpaired process states.
- Developer guidance describes detection and recovery.

## Result

- Runtime process selection is shared by `run`, `status`, and `stop`.
- Client-only discovery now reports an incomplete runtime and exposes actionable
  process identity instead of contradicting `run`.
- The focused script suite passes with 43 tests, and both the script analyzer
  and full Flutter analyzer report no issues.
