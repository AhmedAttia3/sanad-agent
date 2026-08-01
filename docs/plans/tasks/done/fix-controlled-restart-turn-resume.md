# Fix Controlled-Restart Turn Resume

## Problem

A `running` work item with a valid continuation checkpoint was converted to `queued` during daemon startup, but the restored queue lost whether the item represented a continuation. Queue bootstrap therefore executed it as a new turn, repeated the user echo, and called `streamMessage()` instead of `resumeStream()`.

## Plan

- Preserve explicit resume intent on reconstructed queue entries whose durable work item has a recognized checkpoint.
- Propagate that intent through both queue bootstrap and normal FIFO draining.
- Keep ordinary queued user messages on the new-turn path.
- Add a regression assertion that a controlled restart calls `resumeStream()` and emits no duplicate user message.

## Definition of Done

- The controlled-restart regression passes.
- Restored checkpoint execution does not call `streamMessage()` or emit a user echo.
- Interface runtime documentation describes the queue-to-resume boundary.
