---
title: "Bound Invalid Runtime Switch Manifest Warnings"
description: "Prevent the managed launcher from printing the same invalid runtime-switch manifest warning every polling cycle."
---

# Bound Invalid Runtime Switch Manifest Warnings

## Problem

The managed `sanad-dev` launcher polls its port-scoped runtime-switch manifest every 250 ms. If a stale or newer incompatible manifest remains on disk, every read throws and the launcher emits the same warning indefinitely.

## Change

- Preserve fail-closed manifest validation and leave incompatible records untouched.
- Emit one warning for each distinct on-disk invalid manifest revision rather than once per poll.
- Reset warning suppression after the manifest becomes valid or disappears.
- Cover unchanged, replaced, and reset behavior with focused unit tests.

## Definition of done

- An unchanged invalid manifest produces one report decision across repeated polls.
- Replacing the invalid manifest permits one new report.
- A successful or absent-manifest read resets suppression.
- Runtime-switch unit tests and static analysis pass.
