---
title: "Memory Tool Reliability QA"
description: "Regression matrix for compact memory results, atomic batches, file safety, bounded recovery, and frozen prompt snapshots."
---

# Memory Tool Reliability QA

## Result Contract

| Scenario | Expected behavior |
|---|---|
| Successful add, replace, remove, or batch | Result is terminal and contains target, usage, entry count, and a short message; it contains neither full entries nor an absolute path. |
| Explicit read | Returns the selected target's live entries and capacity metadata without an absolute path. |
| Missing or unmatched `old_text` | Returns bounded current entries and enough guidance for one corrected retry. |
| Ambiguous substring | Returns bounded content previews instead of internal numeric indices. |
| Repeated recoverable failures | Early failures remain actionable; the bounded terminal result stops further memory retries and allows the user response to continue. |

## Atomic Mutation Matrix

| Scenario | Expected behavior |
|---|---|
| Valid multi-operation batch | All operations commit once against final capacity. |
| Invalid middle operation | No operation is persisted. |
| Remove plus otherwise-overflowing add | Final-capacity validation permits the batch when the resulting store fits. |
| Exact duplicate add | Succeeds idempotently without adding a second entry. |
| Concurrent cooperating writers | Each writer reloads authoritative state under the target lock; neither accepted update is lost. |
| Reader during commit | Reader observes either the previous complete file or the new complete file, never a partial file. |
| Commit failure | Previous destination remains complete and temporary artifacts are cleaned. |

## Drift and Recovery

| Scenario | Expected behavior |
|---|---|
| Clean `§`-delimited file | Mutation proceeds normally. |
| Non-roundtrippable or oversized externally edited entry | Destructive mutation is refused, source bytes stay unchanged, and recovery backup/remediation is returned. |
| Backup creation failure | Source remains unchanged and the failure is explicit. |
| Same behavior on `USER.md` and `MEMORY.md` | Both targets preserve identical safety semantics. |

## Content Safety

- Injection, exfiltration, persistent configuration mutation, secret-like values,
  hidden markup, and invisible Unicode are rejected with stable finding IDs.
- Normal preferences, environment descriptions, and descriptive references to
  project instruction files remain accepted.
- Unsafe content planted directly on disk remains inspectable through explicit
  read but is replaced by a blocked marker in the frozen prompt snapshot.

## Session and Restart

- Mid-session writes update disk and explicit reads immediately but never mutate
  the current session's frozen prompt snapshot.
- A later session loads the committed complete version.
- Restart recovery never replays an ambiguous memory mutation automatically,
  because the tool remains mutation-unsafe at the crash boundary.
