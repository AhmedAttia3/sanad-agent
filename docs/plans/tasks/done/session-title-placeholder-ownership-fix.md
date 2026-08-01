---
title: "Session Title Placeholder Ownership Fix"
description: "Restore intelligent title generation for client-created conversations by preserving automatic placeholder ownership across create_session."
status: active
---

# Session Title Placeholder Ownership Fix

## Problem

The client eagerly creates a session before dispatching the first message and sends a bounded first-message snippet in `title`. The daemon currently classifies every non-empty client title as explicit and final. Since live title generation now correctly runs only for durable `pending` ownership, normal client-created sessions skip `TitleService` entirely: no title request, failure/fallback log, or generated-title update occurs.

## Design

- Extend `create_session` with an optional `title_is_placeholder` boolean.
- The New Conversation first-send path sends its automatic snippet with `title_is_placeholder: true`.
- The daemon persists that title as `pending`; omitted/false retains the existing explicit-title `final` behavior.
- Keep generated-title compare-and-set, manual rename protection, fallback, startup recovery, and title request behavior unchanged.
- Add focused protocol/client tests proving automatic versus explicit ownership and post-terminal generation eligibility.

## Definition of Done

1. A first message sent from New Conversation creates a bounded visible snippet marked as an automatic placeholder.
2. The daemon stores that title with `SessionTitleStatus.pending` and schedules intelligent title generation after the first successful terminal response.
3. Explicit client titles remain final and are never replaced automatically.
4. Existing clients that omit the new field retain their current explicit-title semantics.
5. Client and agent focused tests pass, both analyzers pass, and title-generation protocol/QA documentation reflects the field.
