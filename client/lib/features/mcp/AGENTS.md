# MCP Feature Contract

## Scope
This contract applies to `client/lib/features/mcp/`.

## Runtime Ownership
- The daemon owns MCP catalogs, effective configuration, mutations, and scope precedence.
- Query and mutate MCP state through `DeviceCommandClient` with an explicit target `DeviceConfig`.
- Let `DeviceConnectionCoordinator` choose local or cloud transport; MCP must not force a socket or send an empty device id.
- Presentation must not call `SanadSocketService`, inspect agent-owned files, or synthesize MCP entries from local client state.

## Scope Presentation
- Device MCP views show device scope only.
- Workspace detail views may show effective device and workspace entries but must label origins and communicate same-name workspace precedence.
- Pending suspension and recovery state must come from daemon-owned conversation/history metadata, not MCP-local dialogs or caches.
