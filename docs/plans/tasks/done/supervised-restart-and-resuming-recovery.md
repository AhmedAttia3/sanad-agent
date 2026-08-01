# Supervised Restart and Resuming Recovery

## Problem

A source daemon launched directly with the documented Dart command can accept `POST /restart` without having a parent supervisor. The restart coordinator then exits successfully, but no process exists to relaunch it. If shutdown interrupts a work item already in `resuming`, startup can classify its checkpoint as replay-safe, convert it to `waiting`, and then incorrectly pass it through the legacy waiting-owner guard before automatic resume is scheduled. The safe request becomes blocked even when durable run ownership exists.

## Scope

- Automatically supervise source-mode `daemon` and `start` commands.
- Remove the `ENABLE_HOT_RESTART` setting; `--child-process` remains the internal recursion guard.
- Supervise compiled executable `daemon` and `start` commands so settings-triggered restarts work in production.
- Auto-resume interrupted `resuming` work only when durable run id, generation, checkpoint kind, and tool replay safety prove ownership.
- Clear stale persisted `resuming` notices before issuing the new startup resume claim.
- Keep ambiguous legacy and unsafe-tool recovery blocked.
- Add focused supervisor-selection and startup-recovery regression tests.

## Definition of Done

- Source and compiled daemons are relaunched after the restart endpoint exits their child.
- `ENABLE_HOT_RESTART` is absent from runtime configuration and environment templates.
- A safely owned interrupted `resuming` work item resumes exactly once after startup.
- Legacy ownerless and unsafe interrupted work remains blocked.
- Focused tests and static analysis pass.
