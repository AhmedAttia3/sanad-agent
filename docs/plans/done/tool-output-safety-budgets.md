---
title: "Tool Output Safety Budgets"
description: "Plan for bounded model-visible output across built-in, workspace, platform, and MCP tools."
status: completed
---

# Tool Output Safety Budgets

## Problem

Tool results currently enter execution checkpoints, client tool events, and model history without a universal size boundary. Individual services have inconsistent protections: web fetch and glob search are bounded, while MCP, platform tools, shell output, and several parameterized searches can return arbitrarily large strings. A large result can consume the model context window or daemon memory before the next model invocation.

## Reference Review

Hermes uses complementary defenses rather than relying on one tool-specific limit:

1. producer-side limits for terminal, file reads, and searches;
2. a universal per-result budget after any tool returns, including extension tools;
3. an aggregate budget across all tool results in one assistant turn;
4. optional persistence of oversized raw results with a small in-context preview;
5. later history compression and old-result pruning.

Its universal defaults are 100,000 characters per result and 200,000 characters per turn, scaled down for small model context windows. Terminal output has a separate 50,000-character head/tail limit. Oversized results can be written to sandbox storage and referenced from the model-visible preview.

## Sanad Design

Adopt the same layered shape with the smallest safe runtime change:

- Add a provider-neutral output guard in the engine tool-execution boundary. Every result is guarded before tool events, checkpoints, or history, regardless of whether it came from a built-in, workspace callback, MCP server, or platform tool.
- Apply a 50,000-character per-result ceiling and a 100,000-character aggregate batch ceiling. Keep both the beginning and end and insert an explicit omission marker.
- Do not add raw-result persistence in this change. Sanad's `file_read` is workspace-confined, so persisting outside the workspace would produce an unreadable reference; persisting inside it would unexpectedly mutate user projects. A future result-artifact service can add retrievable storage without weakening workspace isolation.
- Add producer-side bounds where a universal post-return guard is too late to prevent excessive buffering: shell streams, file reads, and grep search.
- Clamp model-controlled result-count parameters in schemas and runtime code. Schema maximums improve model behavior, while runtime clamps remain authoritative.

## Tool Audit

| Surface | Current protection | Change |
|---|---|---|
| All registered tools, MCP, platform tools | None globally | Universal per-result and per-batch guard |
| `shell_execute` | Timeout only; stdout/stderr joined without a size cap | Bounded head/tail stream collection |
| `search_grep` | Default 100 lines, but caller values/context and line length are unbounded | Clamp counts/context, truncate long lines, cap structured content |
| `file_read` | 10 MB file cap and 2,000-char line cap, but requested/default line count is not enforced | Enforce page line and content budgets with continuation metadata |
| `search_glob` | 500 paths | Retain; universal guard covers pathological path sizes |
| `web_fetch` | Five URLs and 3,000 characters per page | Retain |
| `web_search` | Caller-controlled result count | Clamp result count |
| `tool_search` | Caller-controlled result count | Clamp result count |
| write/edit result patches | Can be large | Universal guard protects context; producer-side patch generation can be optimized separately if profiling shows memory pressure |
| memory, scheduling, skills, delegation, future tools | Varies | Universal guard is the fallback |

## Definition of Done

- Every tool result is bounded before event emission, checkpoint persistence, and model-history insertion.
- Parallel, sequential, resumed, forced, MCP, platform, and future registered tool paths share the same guard.
- A batch of individually valid results cannot exceed the aggregate model-visible budget.
- Shell collection remains bounded while the process is still producing output.
- Grep and file-read pagination cannot be expanded beyond their hard runtime limits.
- Truncated output explicitly reports original size and omitted characters.
- Focused tests cover per-result, aggregate, shell, grep, file-read, and runtime schema limits.
- Agent analysis and focused tests pass.
