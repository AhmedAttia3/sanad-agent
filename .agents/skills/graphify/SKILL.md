---
name: graphify
description: "Query or maintain a project's Graphify knowledge graph for codebase architecture, symbol relationships, impact analysis, and corpus exploration. Use for codebase questions when graphify-out/graph.json exists, or when the user explicitly asks to build, update, explain, or navigate a graph."
---

# Graphify

Use Graphify as a bounded discovery map. For code questions, verify conclusions
against source files and tests; the graph may be broad or stale.

## Routing

1. Check for `graphify-out/graph.json`.
2. For a natural-language codebase question with an existing graph, run one
   narrow graph operation before direct source search.
3. Choose the smallest operation:
   - One known symbol: `graphify explain "Symbol"`.
   - Relationship between two known symbols: `graphify path "A" "B"`.
   - Unknown entry point or broad concept: `graphify query "terms" --budget 800`.
   - Reverse impact: `graphify affected "Symbol"`.
4. After Graphify identifies likely files or symbols, use `rg` and read the
   source/tests for the authoritative answer.

For stack traces or exact exception text, query only the top project-owned
symbols once with `--budget 600`, then move immediately to `rg`. Do not use
generic runtime names such as `List`, `Map`, `String`, `async`, or package names
as query anchors.

Read [references/query.md](references/query.md) only for query/path/explain
selection, output-noise handling, or CLI fallback behavior.

## Context budget and noise guard

- Default to 800 output tokens; use 600 for stack traces and at most 1500 for
  broad architecture work.
- Prefer exact identifiers from the request, stack trace, or repository.
- If a query reports more than 80 nodes, is truncated, or mostly returns generic
  language/runtime symbols, classify it as noisy. Do not paste or analyze the
  full traversal and do not retry with a broader query.
- On noisy output, pivot to `explain`/`path` for exact symbols or continue with
  `rg` in the surfaced files.
- Summarize only the few relevant nodes and source locations in the answer.
- Do not treat the presence of a node or path as proof that runtime behavior is
  correct. Confirm behavior in code and focused tests.

Graphify normally returns material from the corpus used to build the current
graph. It can still be outside the immediate question, stale, or sourced from a
previously merged/external corpus. Inspect source paths when provenance matters.

## Existing graph

When a graph exists, do not rebuild it for a question. Dirty `graphify-out/`
files are expected and do not invalidate queries by themselves.

Use `graphify-out/wiki/index.md` for broad navigation when available. Read
`graphify-out/GRAPH_REPORT.md` only for broad architecture audits or when scoped
operations are insufficient.

If the CLI subcommand is unavailable, use the minimal fallback in
[references/query.md](references/query.md). Do not load the full graph into the
conversation.

## Build and maintenance

Only build when the user explicitly requests Graphify output or no graph exists
and graph construction is necessary for the task.

- Full extraction: use `graphify extract <path>`; add `--code-only` when only
  source code is needed.
- Incremental code update: use `graphify update <path>`.
- Recluster: use `graphify cluster-only <path>`.
- Explicit `/graphify --help` or `/graphify -h`: print the concise usage below
  and stop.

```text
/graphify <path>                    build a graph
/graphify query "question"          scoped BFS query
/graphify path "A" "B"              shortest relationship path
/graphify explain "Symbol"          focused node explanation
/graphify update <path>             incremental code update
```

Load advanced references only when the requested operation needs them:

- Multiple repositories: [references/github-and-merge.md](references/github-and-merge.md)
- Audio/video: [references/transcribe.md](references/transcribe.md)
- Semantic extraction schema: [references/extraction-spec.md](references/extraction-spec.md)
- Updates and clustering: [references/update.md](references/update.md)
- Exports: [references/exports.md](references/exports.md)
- URL ingest/watch: [references/add-watch.md](references/add-watch.md)
- Hooks: [references/hooks.md](references/hooks.md)

## Integrity

- Never invent an edge or source location.
- Distinguish extracted, inferred, and ambiguous relationships.
- State when the graph lacks enough evidence.
- After modifying project code, run `graphify update .` when the repository
  contract requires the graph to stay current.
