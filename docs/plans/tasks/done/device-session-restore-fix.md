---
title: "Device and Session Restore Coherence"
description: "Preserve the selected device during cold start and restore the matching device-scoped conversation selection."
status: "completed"
priority: "high"
scope: "Flutter client device inventory and conversation cache projection"
---

# Device and Session Restore Coherence

## Problem

Cold start resolved the persisted device against an inventory that initially
contained only the local device. This could select the local device before the
cloud inventory arrived and then request a remote session from the wrong
transport. Device switches could also retain the previous device's selected
session, leaving the newly visible sidebar without a highlighted row.

## Design

- Read the persisted active device identity independently from the currently
  loaded device configuration.
- While the cloud inventory is pending, do not replace a missing persisted
  cloud device with a default device.
- Treat a successful cloud device response as authoritative for cloud device
  membership. Clear a persisted cloud identity that the authoritative response
  no longer contains before publishing the merged inventory, then allow the
  cubit to choose a valid fallback.
- Preserve a persisted local identity when the local daemon is temporarily
  unreachable; cloud inventory does not own local-device membership.
- When the active cache device changes, discard a selected session belonging to
  another device and restore the new device's last session destination.

## Definition of Done

- A persisted cloud device is restored when it arrives after initial local
  inventory construction.
- The local device is not selected while that cloud inventory is pending.
- A deleted persisted cloud device cannot leave the client permanently in
  `DeviceNoActive`; an authoritative absence falls back deterministically.
- Switching devices selects the destination belonging to the new device.
- Focused device/session tests and Flutter analysis pass.
- Device selection and conversation-cache documentation are updated.
