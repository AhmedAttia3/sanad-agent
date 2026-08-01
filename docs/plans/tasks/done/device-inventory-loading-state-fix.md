---
title: "Device Inventory Loading State Fix"
description: "Distinguish an in-flight device inventory request from an authoritative empty inventory in the sidebar without trapping the UI in loading."
status: "completed"
priority: "medium"
scope: "Flutter DeviceCubit loading projection, sidebar presentation, focused regression tests, and client/QA documentation"
depends_on: "Plan 32c device workspace sidebar"
---

# Device Inventory Loading State Fix

## Problem

The sidebar previously rendered `No devices` while the first cloud inventory request was still in flight. The current draft adds a loading flag, but ties completion to an internal boolean that is not republished when a request times out and can be changed incorrectly by unrelated local inventory events. This can leave `Loading devices…` visible indefinitely or clear it before the backend request settles.

## Decision

Project loading directly from tracked inventory requests. `DeviceCubit` owns a bounded in-flight count for all inventory fetches it starts, publishes loading only while at least one request is pending and the inventory is empty, and clears loading in `finally` on success, timeout-style completion, or failure. Logout starts a new request epoch so late completions from the previous account cannot mutate current state. Local inventory updates do not independently declare a backend request complete.

The sidebar renders `Loading devices…` only for an empty inventory with a pending request; after settlement it renders the authoritative empty state.

## Definition of Done

- Empty inventory shows `Loading devices…` while a DeviceCubit-owned fetch is pending.
- Loading clears when the fetch settles even if no inventory stream event is emitted.
- Local inventory events cannot prematurely complete a pending backend fetch.
- Logout invalidates stale fetch completions and does not claim a new backend request is running.
- Focused Cubit and widget tests cover pending and settled empty-inventory states.
- Product and sidebar QA documentation describe the behavior.
- Flutter analysis and focused tests pass.
