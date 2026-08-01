# Model Snapshot Loop Guard

## Problem

The conversation composer model chip resolves provider instance display names from the provider runtime snapshot. The lookup is triggered from the widget build path, and a completed lookup updates widget state. If the active provider id does not match any returned snapshot instance id, every state update can schedule another snapshot lookup, producing a tight `model.snapshot` request loop.

## Scope

- Keep the daemon-owned provider runtime surfaces as the source of truth for model and provider display metadata.
- Keep the model picker dialog behavior unchanged, including its explicit refresh flow.
- Make the composer model-chip display-name lookup idempotent across rebuilds.

## Design

- Move lookup scheduling out of the synchronous build path.
- Track the last attempted `(agent, provider)` lookup key so a missing provider mapping is still treated as a completed attempt until the active provider or agent changes.
- Keep normal retries for empty runtime data, where no provider instances are returned at all.
- Avoid redundant `setState` calls when a lookup returns the same display-name map already stored for the agent.

## Verification

- Add widget coverage for repeated rebuilds with an unmatched active provider id.
- Confirm the provider setup and conversation widget tests still pass for the touched behavior.
