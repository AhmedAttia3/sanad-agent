---
title: "Agent Contract Decomposition Traceability Audit"
description: "Classify existing client and agent contracts before splitting agent runtime contracts, with explicit preservation and documentation-gap checks."
status: "completed"
priority: "high"
scope: "Client split verification and agent AGENTS.md hierarchy"
---

# Agent Contract Decomposition Traceability Audit

## 1. Audit Goal

Prevent contract splitting from silently discarding durable laws or leaving
architecture details available only in Git history. Every existing statement
must be classified as one of:

- **LAW:** retained in the nearest owning `AGENTS.md`.
- **DESIGN:** retained in an active page under `docs/`.
- **SOP:** retained in a skill or operational procedure rather than a contract.
- **STALE:** removed only after source and current documentation confirm it no
  longer describes supported behavior.

## 2. Client Split Traceability Result

### Preserved Laws

The split contracts preserve the behavioral ownership of the previous aggregate
contract:

- portal-owned authentication and credential safety;
- gateway bootstrap and selected-device readiness gating;
- explicit device routing and persisted-device cold-start restore;
- daemon-authoritative delivery, queue, steer, stop, replay, and provider routes;
- session identity, eager creation, and immediate local selection sync;
- single-owner cache, drafts, request generations, persistence, and pagination;
- device-scoped destinations and cross-device selection invalidation;
- composer, suspension, atomic presentation, sidebar, navigation, and deletion
  fallback invariants;
- provider instance-first setup and runtime readiness;
- MCP, Settings, voice, and local-daemon ownership boundaries.

No source-code behavior was removed by the contract split.

### Verified Design Coverage

| Removed aggregate detail | Active documentation result |
|---|---|
| Voice capture/playback formats, packages, transport, and barge-in | Covered by `docs/technical/voice_streaming.md`. |
| Conversation cache schema, stale-while-revalidate, drafts, and typed destinations | Covered by `docs/technical/client_conversation_cache_schema.md`. |
| Provider templates, instances, readiness, credentials, and model refresh | Covered by `docs/technical/provider_protocol.md`. |
| Sidebar component topology and compatibility shell | Present in completed Plan 32c, but not in an active technical page. |
| Atomic navigation, generations, delayed loading, and deletion fallback | Present in product documentation and completed Plan 32e; implementation detail is not consolidated in an active technical page. |
| Standalone/source daemon-controller implementation | Present in operations pages and a `done_not_documented` plan; no focused active technical design exists. |
| Portal auth endpoints and polling-token lifecycle | Present mainly in `done_not_documented` plans; no active technical auth contract exists. |
| Auth persistence path and permission mode | Path is documented, but owner-only permission detail remains primarily in a historical plan. |

### Gaps and Contradictions

1. **Active auth design gap:** create an active technical page for portal-owned
   client authentication, token storage, polling-token secrecy, and refresh.
2. **Voice port contradiction:** `docs/technical/voice_streaming.md` hardcodes
   `127.0.0.1:58085`; local voice routing must derive from
   `AppConfig.localGatewayUrl` and support worktree-assigned ports.
3. **Atomic-loading detail gap:** the current 300 ms delayed-loading threshold is
   enforced by source/tests but not stated in an active design page.
4. **Daemon-controller design gap:** source versus standalone controller behavior
   lacks one active technical owner.
5. **Sidebar/navigation discoverability gap:** detailed topology and atomic-swap
   mechanics are discoverable mainly through completed plans rather than one
   current technical reference.

These gaps are now closed by active technical pages for client authentication,
local daemon control, and conversation navigation; voice routing now derives
from `AppConfig.localGatewayUrl`. The technical MOC indexes each new owner.

## 3. Agent Contract Triage

### `agent/AGENTS.md`

Current concerns:

- combines root laws, architecture, provider-runtime schema, recovery design,
  distribution details, and operational commands;
- contains workspace-root path inconsistencies;
- repeats detailed laws owned by engine, interfaces, capabilities, and evolution.

Target:

- keep only agent-wide laws, verification boundary, and package ownership
  summary; generated `docs/llms.txt` owns contract discovery;
- move provider/auth/state ownership to `agent/lib/core/AGENTS.md`;
- move platform, filesystem, process, and voice infrastructure ownership to
  `agent/lib/infrastructure/AGENTS.md`;
- move operational procedures to the developer skill;
- move schemas and runtime design to active technical/agent-engine pages.

### `agent/lib/interfaces/AGENTS.md`

Current concerns:

- largest contract at 179 lines;
- combines runtime orchestration, durable recovery, gateway routing, delivery
  models, platforms, protocol handlers, history reconstruction, voice design,
  implementation guidance, and component catalogs.

Target:

- `agent/lib/interfaces/AGENTS.md`: interface-wide transport and ownership laws;
- `agent/lib/interfaces/runtime/AGENTS.md`: active-run identity, admission,
  durable recovery, FIFO, stop, retry, replay, and terminal commit;
- `agent/lib/interfaces/platforms/AGENTS.md`: platform lifecycle and delivery
  routing;
- `agent/lib/interfaces/platforms/sanad_gateway/AGENTS.md`: canonical envelope,
  protocol bridge, handlers, queries, and local/cloud parity;
- `agent/lib/interfaces/models/AGENTS.md`: typed delivery/envelope identity if
  enough independent model laws remain.

Move platform/component topology and voice architecture to docs rather than
copying it into child contracts.

### `agent/lib/capabilities/AGENTS.md`

Current concerns:

- combines tool metadata, registry, permissions, runtime catalog, workspace
  handlers, MCP, skills, web search, concrete tool list, code examples, and
  adding-tool procedure.

Target:

- `agent/lib/capabilities/AGENTS.md`: capability-wide ownership and registry law;
- `agent/lib/capabilities/tools/AGENTS.md`: execution, replay safety, context,
  shell/workspace safety;
- `agent/lib/capabilities/runtime/AGENTS.md`: per-turn catalog/context,
  workspace, and web runtime;
- `agent/lib/capabilities/mcp/AGENTS.md`: merged settings, connections, cache,
  and daemon authority;
- `agent/lib/capabilities/permissions/AGENTS.md`: policy, durable suspension,
  once/session/workspace decisions;
- tool creation steps and examples move to a skill; component catalogs move to
  docs.

### `agent/lib/engine/AGENTS.md`

Current concerns:

- size is moderate, but adapter and runner/runtime laws are mixed with a long
  component inventory.

Target:

- `agent/lib/engine/AGENTS.md`: engine-wide model neutrality, prompt ordering,
  state ownership, and request identity;
- `agent/lib/engine/adapters/AGENTS.md`: adapter statelessness, codec ownership,
  provider-state namespace/issuer, model discovery, and retry boundaries;
- `agent/lib/engine/runtime/AGENTS.md`: runner collaborators, history ownership,
  checkpoints, steering, tools, usage, and model-step identity.

### `agent/lib/evolution/AGENTS.md`

Current concerns:

- mixes memory, titles, scheduling, session persistence, runtime database
  repositories, future plans, and detailed component descriptions.

Target after the higher-priority splits:

- keep cross-evolution persistence laws in the parent;
- add `agent/lib/evolution/db/AGENTS.md` for database connection and aggregate
  ownership;
- add `agent/lib/evolution/db/runtime/AGENTS.md` for work items, notices,
  pending input, transition graph, and cleanup;
- add `agent/lib/evolution/memory/AGENTS.md` for file-backed memory and frozen
  snapshots only if memory rules continue growing;
- move future plans and schema descriptions to docs.

### `agent/lib/plugins/AGENTS.md`

No split is currently justified. Convert any component-description prose to a
small lifecycle law set when the parent cleanup reaches this directory.

## 4. Recommended Execution Order

1. Close the five client documentation gaps above.
2. Build a line-level LAW/DESIGN/SOP/STALE matrix for `agent/AGENTS.md` and
   `agent/lib/interfaces/AGENTS.md`.
3. Add `agent/lib/core/AGENTS.md` and `agent/lib/infrastructure/AGENTS.md`.
4. Split interfaces into runtime, platforms, and Sanad protocol ownership.
5. Split capabilities into tools, runtime, MCP, and permissions.
6. Split engine adapters/runtime.
7. Reassess evolution after the higher-level ownership map is stable.
8. Regenerate `docs/llms.txt` and run documentation integrity checks before any
   commit is requested.

## 5. Completion Result

The implementation satisfies the decision gate:

- durable laws were reassigned to the nearest package owner;
- client auth, local daemon control, conversation navigation, interface runtime,
  and capability runtime now have active design pages;
- agent root preserves cross-domain execution, engine, protocol, persistence,
  provider/capability, security, and test-scope laws while leaf contracts own
  local implementation invariants;
- client root preserves thin-client, device, conversation, provider, endpoint,
  security, and test-scope laws while feature contracts own local invariants;
- interfaces, capabilities, engine, evolution, and plugins no longer mix
  component catalogs or operational procedures with runtime laws;
- generated `docs/llms.txt` is the sole contract index;
- contracts do not embed paths to other contract files;
- removed details were retained in active design/operations documentation or
  confirmed as historical planning rather than current law.
