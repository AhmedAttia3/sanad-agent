---
title: "Client Feature Contract Decomposition"
description: "Split the overloaded client feature contract into feature- and layer-owned runtime contracts without duplicating design documentation."
status: "completed"
priority: "high"
scope: "Flutter client AGENTS.md hierarchy"
---

# Client Feature Contract Decomposition

## Problem

`client/lib/features/AGENTS.md` combines global layer laws with detailed rules
for authentication, conversations, devices, Home bootstrap, MCP, settings,
provider setup, and voice. Agents modifying one feature must ingest unrelated
contracts, while implementation ownership is not discoverable from the nearest
directory.

## Target Structure

- Keep only cross-feature ownership and layer laws in
  `client/lib/features/AGENTS.md`.
- Add one contract to each independently owned feature.
- Split conversations further into data, domain, and presentation contracts
  because each layer owns substantial independent invariants.
- Keep architecture explanations in `docs/`; feature contracts contain only
  durable laws and ownership boundaries.
- Keep contract discovery centralized in generated `docs/llms.txt`; contracts do
  not maintain child-file indexes.

## Definition of Done

- Every rule from the previous aggregate contract has a clear owner or is
  removed as duplicated design narrative already owned by documentation.
- Parent and child contracts do not repeat detailed rules.
- Paths are workspace-relative and all UI-language constraints remain inherited
  from `client/AGENTS.md`.
- Documentation indexes regenerate successfully and the wiki linter passes.
- Graphify is updated and PR #35 contains the decomposition.
