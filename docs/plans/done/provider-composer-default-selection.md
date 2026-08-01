---
title: "Provider composer default selection"
status: "complete"
---

# Provider composer default selection

## Problem

After first-run provider setup succeeds, the daemon reports an authoritative
active provider instance and model, but Home only dismisses the setup surface.
The new-conversation composer can therefore remain unselected and dispatch a
first turn without an explicit provider/model route, leaving the daemon to
reject the request after submission.

## Ownership and design

- Keep provider readiness and the active default route daemon-owned.
- When Home receives a successful readiness result, initialize the conversation
  route from its `active_provider` and `active_model` only while both local
  selections are empty.
- Pass the successful readiness snapshot out of the reusable provider setup
  flow so the Home gate can initialize the composer before dismissal.
- Never replace an existing or partially selected route.
- Reject normal message submission before session creation when either provider
  or model is absent, and show an actionable English error in the composer.

## Verification

- Unit coverage proves an authoritative default initializes an empty route and
  does not replace an existing selection.
- Unit coverage proves a missing provider/model blocks repository dispatch.
- Widget coverage proves the composer surfaces the missing-selection error.
- Provider setup widget coverage proves the ready callback carries the
  authoritative readiness snapshot.
- Client formatting, analysis, and focused tests pass.

## Result

- The Home readiness path and provider-setup completion path initialize an
  empty composer from the daemon's active provider instance and model.
- Provider and model preferences persist together per device.
- UI and cubit validation block dispatch before eager session creation when the
  route is incomplete.
- `fvm flutter analyze` passes.
- The focused provider/composer tests pass (60 tests).
- The complete client fast suite passes (679 tests).
