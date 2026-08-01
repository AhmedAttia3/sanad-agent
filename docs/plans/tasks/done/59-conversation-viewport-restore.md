---
title: "Task 59 — Persistent Conversation Viewport Restore"
description: "Persist a stable per-session event anchor after manual scrolling and restore it for idle sessions without overriding active work."
---

# Task 59 — Persistent Conversation Viewport Restore

## Goal

Let users resume reading an idle conversation from the event where they last
stopped, while preserving the existing last-user-message opening fallback and
always showing the latest activity when the session has authoritative active
work.

## Behavioral Contract

Opening an existing conversation chooses exactly one initial anchor in this
order:

1. latest event when the authoritative execution snapshot has active work;
2. persisted event anchor when that event still exists in loaded history;
3. latest user message;
4. latest available event when no user message exists.

The opening decision runs once per presented session. Later execution-state
changes must not pull a user away from history they are reading.

A viewport anchor is recorded only after user-driven scrolling settles. Initial
positioning, programmatic follow-tail animation, content growth, and layout
changes must not overwrite it. Persistence stores a stable event id keyed by
device plus session rather than a pixel offset.

A newly accepted user message invalidates the prior viewport anchor because it
starts a newer turn. Session/device deletion also removes owned anchors.

## Ownership and Scope

- `BrainActivityView` owns user-scroll detection and visible-event selection.
- `ConversationCacheStore` owns in-memory viewport anchors and cleanup.
- `ConversationCacheRepository` exposes typed read/write intents to
  presentation.
- The existing versioned conversation-cache persistence stores anchors across
  restart.
- The agent, socket protocol, and agent database remain unchanged.

## Implementation Steps

1. Add persisted per-session event anchors to the conversation cache snapshot,
   codec, store, repository, and cleanup paths.
2. Pass the restored event id and authoritative active-work projection into
   `BrainActivityView` from the active device/session presentation.
3. Select the opening anchor according to the behavioral precedence and record
   the top visible event after manual scroll completion.
4. Add store, codec, and widget regression coverage.
5. Update product and QA documentation, analyze the client, run focused tests,
   and refresh Graphify.

## Definition of Done

- Active-work sessions open at the latest event even when an older anchor is
  persisted.
- Idle sessions restore a valid persisted event anchor.
- Missing/stale anchors fall back to the latest user message.
- Programmatic scrolling never creates a persisted reading anchor.
- Manual scrolling records an event id and survives codec round-trip/restart.
- New user turns and session/device deletion clear stale anchors.
- Client analysis and focused tests pass.
