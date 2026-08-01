# Device Conversation Continuity Fix

## Goal

Preserve the active device, current conversation, cached sidebar, and workspace expansion through temporary local/cloud disconnects, device switches, daemon restarts, and client restarts without routing a session through the wrong device.

## Invariants

- Temporary unreachability never clears the active conversation projection or conversation cache selection.
- A merged local device recognizes its cloud device id as the same inventory identity.
- Cold start waits for a persisted cloud device while inventory is pending and restores its device-scoped destination only after the device resolves.
- Authoritative deletion may clear a missing cloud identity; a cloud identity represented by the merged local device is not missing.
- Sidebar selection requires both device id and session id and follows the selected destination.
- Session history is loaded only through the resolved destination device.

## Verification

- Device manager test for persisted cloud id represented by the merged local device.
- Device cubit tests for alias continuity and transient inventory gaps.
- Session cubit test proving temporary no-active state preserves cache selection and selected session.
- Sidebar row test or focused state test proving selection is device-scoped.
- Existing restart and device-switch recovery tests.
- Flutter analyzer and focused client tests.
- Live client restart through `sanad-dev restart client` after verification.
