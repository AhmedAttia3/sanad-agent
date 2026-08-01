# Evolution Memory Contract

## Scope
This contract applies to `agent/lib/evolution/memory/`.

## Storage Ownership
- Long-term memory is file-backed under `SANAD_HOME/memories/`, not SQLite-backed.
- `MEMORY.md` stores durable environment/project notes and `USER.md` stores user-profile facts.
- Separate entries with the established `§` delimiter and preserve the file format required for user inspection and manual editing.
- The memory tool delegates to this store and must not maintain another durable cache.

## Frozen Session Snapshot
- Load one frozen memory snapshot at session start for prompt use.
- Mid-session memory mutations write files immediately but do not mutate the current prompt snapshot.
- New memory becomes prompt-visible only in a later session so the stable prompt prefix remains coherent.
- Do not inject raw file mutations directly into persisted conversation history.

## Mutation and Persistence Safety
- Serialize each target's read-modify-write cycle, reload authoritative disk state under lock, flush a same-directory temporary file, and atomically replace the destination.
- Destructive mutations and batches are all-or-nothing. Refuse files that cannot round-trip safely through the established entry format; preserve the source and provide recoverable backup/remediation.
- Mutation success is compact and terminal. Return live entries only for explicit reads or bounded recovery context, and never expose an absolute host path in ordinary model-facing results.
- Cap consecutive recoverable maintenance failures per turn so memory work cannot trap the tool loop; reset the budget on successful progress and at a new turn.

## Safety and Verification
- Keep memory operations scoped to the two owned targets and prevent traversal to arbitrary files.
- One memory-owned scanner protects writes and startup snapshots while retaining blocked source entries for user inspection/removal.
- Return explicit ambiguity/capacity outcomes so callers can correct exact replacements safely.
- Daemon-backed memory coverage verifies real tool execution and persistence across restart, not unit behavior only.
