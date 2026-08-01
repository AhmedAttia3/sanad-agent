---
title: "Task 45: Conversation Last-Destination Recovery"
description: "Persist and restore the exact typed conversation destination, including New Conversation with or without a workspace."
status: "completed"
completed_at: "2026-07-16"
priority: "high"
---

# Task 45: Conversation Last-Destination Recovery

## Goal

Restore the exact conversation destination that was visible when the client stopped: an existing session, New Conversation without a workspace, or New Conversation with a workspace.

## Design

- `ConversationDestination` is the single typed representation used by routing, cache state, and restart recovery.
- `DeviceConversationContext.lastDestination` stores the current restorable destination.
- `ConversationCacheRepository.restartDestination(deviceId)` is the single resolver consumed by `HomeScreen`; it applies the New Conversation default and removed-workspace fallback.
- `lastSelectedSessionId` remains separate and is used only to inherit context from the most recently opened session when starting a new conversation.
- Missing persisted destination defaults to New Conversation. Older cache fields are not interpreted as a destination.
- A removed workspace is dropped from a restored New Conversation destination.
- A missing saved session falls back to New Conversation.

## Verification

- Store tests cover session, workspace-free New Conversation, workspace-scoped New Conversation, and destination transitions.
- Codec tests cover typed destination round trips and missing-destination defaults.
- Session state tests cover restart projection without selecting the previous session.
- Home restoration consumes the cached typed destination rather than inferring it from selected-session state.
