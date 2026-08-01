---
title: "Task 31 Authoritative Session State QA Matrix"
description: "Regression coverage for durable execution snapshots, per-session attention isolation, reconnect recovery, and authoritative route failover UX."
---

# Task 31 Authoritative Session State QA Matrix

## Execution-state projections

| Durable state | Sidebar signal | Composer behavior | Stop behavior |
|---|---|---|---|
| `idle` | No activity marker | Normal composition | Hidden |
| `queued` | Queue marker | New messages may join the queue | Enabled |
| `running` | Execution spinner | Existing work remains active | Enabled |
| `waiting` | Waiting marker, never an execution spinner | Recovery notice remains independent | Enabled |
| `blocked` | Error/action marker | Recovery actions remain available | Enabled |
| `resuming` | Execution spinner | Route-change notice clearing must not show idle | Enabled |
| `stopping` | Stopping marker | The accepted stop remains visible until recomputation | Disabled |

Permission and user-question prompts override every execution marker. A fatal
runtime notice overrides waiting, stopping, running, queued, and normal states,
but it does not rewrite the execution snapshot.

## Ordering and identity

| Scenario | Expected result |
|---|---|
| Newer execution revision arrives before an older local/cloud copy | The older copy is rejected without changing the visible state. |
| Equal revision and identical payload arrives twice | The second copy is idempotent and causes no extra rebuild. |
| Equal revision with conflicting state or work identity | The payload is rejected as a diagnosable contract conflict. |
| An old runtime-notice clear follows a newer notice | The newer notice remains visible. |
| An old permission result follows a newer suspended request | The newer request remains visible. |
| History races with live execution state | Both inputs pass through the same reducer; the highest valid revision wins. |

## Session isolation

| Scenario | Expected result |
|---|---|
| Session A receives a permission prompt while session B is open | Only A receives the question/permission marker; B's composer is unchanged. |
| Session A becomes blocked while B is running | A shows blocked and B keeps its execution spinner. |
| Navigation changes while history for the previous session is in flight | The late history cannot replace the open session's composer, notice, permission, or execution state. |
| A draft request exists before `session_created` | Draft pending state stays device-scoped and does not synthesize a session execution snapshot. |

## Restart, reconnect, and delivery

| Scenario | Expected result |
|---|---|
| Restart with durable `running`, `waiting`, `blocked`, or `resuming` work | The daemon recomputes a non-idle snapshot from durable work. |
| Restart with a stale `stopping` snapshot | The daemon discards the transient projection and recomputes from work rows. |
| Reconnect while a non-terminal state is visible | The client retains its snapshot until an equal or newer snapshot arrives; no active/idle flicker occurs. |
| A second client opens during execution | History/list hydration gives it the same authoritative execution snapshot. |
| Local and cloud deliver one logical transition | Both copies carry the same canonical event identity and revision. |

## Task 48 live interaction delivery

| Scenario | Expected result |
|---|---|
| A live runtime notice arrives for the open session | Sidebar attention and the inline recovery card update from the same attention snapshot without history reload or navigation. |
| A notice arrives for background session B while A is open | B's sidebar state updates; A's inline card is unchanged. |
| A live notice arrives while another session history request is pending | `requestedSessionId` keeps stream gating active; the notice cannot replace the retained presentation, and the successful history swap reads the target session's latest attention state. |
| Retry or Change Provider is pressed locally or through cloud | Sanad Client sends `device_command` with explicit `device_id` and `session_id`; provider and model travel atomically when both are known. |
| Local and cloud clients are connected when a permission/question suspends | Both receive copies with identical `event_id`, `request_id`, `session_id`, and canonical content. Registration order does not select a winner. |
| Local and cloud answer the same request concurrently | One daemon claim wins and resumes once; the other receives `tool_permission_resolved(outcome=already_resolved)`. |
| A client submits a suspension answer | It keeps the prompt visible/disabled until `tool_permission_resolved` or another authoritative terminal event arrives. |
| A resolved request is present in stale client state after reconnect | History omits it; a late answer receives `already_resolved` and clears the stale prompt. |
| A synthetic Telegram/WhatsApp origin suspends | Delivery remains `origin`; no Sanad Client family broadcast occurs. |
| Device id does not match the selected client device | Existing device-event filtering rejects the event before conversation state changes. |

## Route and auto-failover

| Scenario | Expected result |
|---|---|
| User or recovery route change succeeds | Session route and every non-terminal work item change atomically and route revision increments once. |
| Identical route change is repeated | No new revision, transition, or confirmation is produced. |
| Route transition persistence fails | Session and work-item routes roll back together. |
| Auto-failover selects an eligible instance | The exact model id is preserved and the client updates only from the authoritative confirmation. |
| Candidate is not ready, opted out, excluded, or cooling down | It is never selected. |
| No exact-model alternative exists | No route revision or switch event is created; ordinary recovery remains available. |
| Auto-failover reaches live and history paths, then the daemon restarts | One informational event is restored immediately after its owning `request_id`, using snapshotted old/new provider display names rather than instance UUIDs, while preserving reason, model, and durable event identity. |

## Terminal and queue races

| Scenario | Expected result |
|---|---|
| Active work completes while queued work remains | Aggregate state becomes `queued`, never `idle`. |
| Stop for run A overlaps a new message/run B | Stop cancels only work owned before the stop barrier; B survives. |
| A cancelled run emits late progress or terminal callbacks | Generation, run, and work-item ownership gates drop every late mutation. |
| Runtime notice clears during Change Provider | Execution remains `resuming` or `running` until its durable terminal transition. |
