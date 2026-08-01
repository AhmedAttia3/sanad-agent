# Query, path, and explain

Load this reference only when operating on an existing graph.

## Select the operation

| Need | Operation |
|---|---|
| Locate an unknown entry point | `query` |
| Inspect one known symbol | `explain` |
| Connect two known symbols | `path` |
| Find downstream impact | `affected` |

Prefer `explain` or `path` whenever the user already supplied exact symbols.
They produce substantially less noise than BFS traversal.

## Narrow query workflow

1. Confirm `graphify-out/graph.json` exists. If absent, report that a build is
   required; do not silently build a large corpus.
2. Extract 3–8 distinctive project terms from the request. Prefer class,
   method, event, table, task, and file names.
3. Exclude generic language/runtime tokens such as `List`, `Map`, `String`,
   `async`, common package names, and prose words.
4. Run:

   ```bash
   graphify query "TERM1 TERM2 TERM3" --budget 800
   ```

   Use `--budget 600` for a stack trace and no more than `--budget 1500` for a
   broad architecture question. Add a repeated `--context` only when the desired
   edge context is already known.
5. If the output exceeds 80 nodes, is truncated, or is dominated by unrelated
   files/generic symbols, mark it noisy and stop expanding it. Use an exact
   `explain`/`path`, or search the surfaced files with `rg`.
6. Read the relevant source and tests. Cite Graphify as navigation evidence,
   not as the final proof of code behavior.

Do not dump the traversal into the response. Retain only relevant node names,
relationships, and source locations.

## Focused operations

```bash
graphify explain "NODE_NAME"
graphify path "NODE_A" "NODE_B"
graphify affected "NODE_NAME"
```

If a focused operation chooses an obviously wrong partial-name match, retry once
with the exact graph label. Do not fall back to a broad query unless the focused
operation cannot locate the concept.

## Vocabulary mismatch

The CLI uses literal graph vocabulary; cross-language wording and synonyms may
miss. Inspect labels in the graph or use known source identifiers to choose up
to 12 terms that actually exist. Do not invent an edge when vocabulary matching
fails. State that the graph did not surface relevant evidence and use direct
source search.

## CLI fallback

If the Graphify CLI is unavailable, read `graphify-out/graph.json` with a small
script that:

1. ranks labels by exact term overlap;
2. selects at most three starting nodes;
3. traverses at most two hops;
4. prints at most 800 tokens of ranked nodes and edges;
5. includes source paths and confidence values.

Never print the raw graph JSON or an unbounded NetworkX traversal.

## Provenance and feedback

- Confirm that relevant node source paths belong to the intended repository.
- Treat missing/deleted source paths as stale-graph evidence.
- Save a result with `graphify save-result` only when it will materially improve
  future graph work; do not save routine code lookups or noisy/dead-end output.
- Never state a runtime conclusion without checking the owning source or test.
