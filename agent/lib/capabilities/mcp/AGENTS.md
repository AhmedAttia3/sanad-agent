# Capability MCP Contract

## Scope
This contract applies to `agent/lib/capabilities/mcp/`.

## Configuration Ownership
- Merge user and workspace MCP configuration in the daemon; workspace scope takes precedence for same-name entries.
- Persist client-requested mutations through the same settings owner used by runtime discovery.
- Clients consume refreshed daemon snapshots and never become configuration truth.
- Keep secret values out of snapshots, logs, and protocol errors.

## Runtime Manager
- Own discovery and execution for enabled stdio, SSE, and streamable-HTTP servers.
- Maintain persistent managed sessions rather than spawning and closing a server for each turn.
- Cache tool specifications by a fast fingerprint of merged effective configuration.
- Invalidate cache and rebuild connections when effective configuration changes.
- Recover dropped connections through managed reconnect and bounded retry without duplicating tool execution.

## Tool Catalog
- Namespace MCP tools to avoid collision with built-ins and other servers.
- Preserve MCP source/owner metadata in `LocalToolSpec`.
- Rebuild workspace-sensitive MCP tools per turn through `LocalRuntimeCatalog`.
- Inspection/testing queries must not mutate saved configuration unless an explicit mutation succeeds.
