# Agent Evolution Contract

## Scope
This contract applies to `agent/lib/evolution/`.

## Evolution Ownership
- Own session/message persistence, title generation, scheduling, memory, and durable runtime state.
- Keep interface admission, engine history, capability execution, and protocol delivery outside this domain.
- Durable tables have one repository owner and share one agent-state database connection.

## Sessions and Titles
- Persist every accepted interaction through `SessionManager` with workspace and selected model as first-class session state.
- Automatic placeholders persist as pending title ownership; explicit, generated, fallback, manual, and migrated titles are final.
- Pending sessions remain eligible for intelligent title generation after a committed assistant response, including resumed turns, and interrupted pending work is recovered from persisted history at daemon startup.
- Start live title generation only after terminal commit/delivery and pass the immutable successful-turn LLM route.
- Title work outlives the active run but writes through compare-and-set against both the captured placeholder and pending state; rename, delete, or newer title wins.
- Emit session update only after compare-and-set succeeds.
- Clean title output to the user's language, preserve the 3–7 word request and 80-character storage cap, and remove reasoning/prefix/quote artifacts.

## Scheduling
- Persist scheduled tasks and restore them on startup.
- Scheduled events preserve originating session identity and enter through normal gateway/orchestrator admission.
- Scheduler and curator tests remain isolated from provider-instance routing unless explicitly under test.

## Suspension Boundary
- Persist execution-suspending tool calls before waiting.
- Decision acceptance is a conditional single-winner transition and survives daemon/client restart.
- A matching unresolved suspension remains the active waiting owner across restart until a decision claims it or Stop clears it.
- Store enough tool, identity, origin, and continuation context to redisplay and resume through normal runtime paths.
