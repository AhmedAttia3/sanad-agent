# Plan 34 — Settings Hub and Device Runtime Settings

Implementation references:

- `docs/product/settings_hub.md`
- `docs/technical/device_runtime_settings_protocol.md`

## Goal

Replace the placeholder Settings screen and separate Manage Devices screen with one responsive, device-scoped Settings Hub backed entirely by the shared Sanad protocol. Local and cloud transports remain implementation details selected by `DeviceConnectionCoordinator`; feature clients never bypass that routing layer.

In this plan, a **device** means one installation of the `agent/` project on a user's machine. A locally reachable agent and a cloud-reachable agent are not two feature types and do not expose different capabilities. The client always speaks the same Sanad protocol to the selected agent; only the unified connection layer decides whether that protocol travels over the direct local connection or Sanad Gateway.

The redesign must preserve every working device-management capability while moving its discovery and presentation into Settings. Removing Manage Devices means removing the separate page as a user-facing destination, not deleting pairing, add, rename, activate, reconnect, update, restart, or remove capabilities that are currently supported.

## Information Architecture

The Settings navigation contains:

- **Personal**
  - Profile
  - General
- **Devices**
  - Add device
  - Selectable device rows with online, active, and current-route hints
  - Sections for the selected device:
    - Overview
    - Providers
    - MCP Servers
    - Skills
    - Workspaces
      - First six workspaces
      - Show all / Show less when more exist

Selecting a device changes only the Settings context. The active conversation device changes only through an explicit Overview action.

Selecting a workspace opens one detail page containing Overview, MCP Servers, and Skills sections. It does not add another nested navigation level.

The wide layout uses a persistent Settings sidebar and content pane. Compact layouts expose the same hierarchy through a collapsible navigation surface without changing destinations or introducing a different feature set. Loading, empty, offline, permission-denied, externally-managed, mutation-in-progress, success, and failure states must be explicit and must not replace already loaded content with an avoidable blank screen.

### Personal sections

- **Profile** reuses the existing authenticated account/profile capabilities and sign-out flow.
- **General** contains client-owned application preferences such as theme and other app-level presentation preferences. These settings are not scoped to a device and must not be sent to the agent.

### Device navigation behavior

- Device rows show enough context to distinguish machines and communicate online, active-conversation, and resolved-route state.
- Adding and managing a device remains available inside the Settings experience.
- Selecting a row changes the Settings inspection target only; it must never silently change the conversation target.
- The active conversation device changes only through an explicit **Set as active** action with visible feedback.
- The workspace list belongs directly in the main Settings sidebar below the selected device's MCP Servers and Skills entries. It is not placed inside a second flyout or nested sidebar.
- Render at most six workspace rows initially. Render **Show all** only when more than six exist, and **Show less** after expansion.

## Scope Semantics

### Device MCP

The device MCP page displays and edits only device-level servers. Workspace servers are not mixed into this page.

### Workspace MCP

The workspace detail page displays the effective device plus workspace inventory. Every server is labeled `Device` or `Workspace`, and the page explains that a same-name workspace server overrides its device-level counterpart. The merge is keyed by the server's canonical name: an enabled workspace definition is the effective definition for that name, while the overridden device definition remains identifiable as inherited-and-shadowed rather than appearing as a second effective server.

### Device Skills

The device Skills page displays only user/device skills discovered from the agent's user-level skill roots, including the primary `~/.sanad/skills` location supported by the runtime. Inventory is daemon-owned and returned through the shared protocol; the client does not inspect these paths itself.

### Workspace Skills

The workspace detail page displays device and workspace skills together using the runtime's existing skill discovery and precedence rules. Every skill is labeled `Device` or `Workspace`; active versus shadowed status is visible, and a same-name workspace skill is explained as taking precedence over the device skill. The client renders the inventory returned by the agent rather than reimplementing path or precedence logic.

## Device Overview

Overview contains:

- Device identity, health, version, online state, active state, and current connection route.
- Explicit Set as active action.
- Cloud Connection switch only when the selected endpoint currently resolves through the local transport.
- Computer Use enablement and OS permission state.
- Web Search provider and masked Serper credential state.
- Runtime actions such as restart/update where supported.
- Destructive actions in a separate danger area.

Diagnostics are deferred.

The Cloud Connection switch is rendered only when `DeviceConnectionCoordinator` currently resolves the selected device through the local route. It is not merely disabled on a cloud route: it is absent, because a client connected through Sanad Gateway must not be allowed to switch off the transport carrying its own command. The current route indicator remains visible regardless of route.

The Web Search editor supports the runtime's valid providers (currently DuckDuckGo and Serper). The Serper API key control is relevant only when Serper is selected, accepts replacement or clearing intentionally, and never receives the stored secret back from the agent. The UI may show only configured/not-configured or a non-reversible masked state.

### Reviewed environment-setting boundary

The device UI exposes only settings that are meaningful and safe as product controls:

- `ENABLE_GATEWAY` as Cloud Connection.
- `COMPUTER_USE` as Computer Use, alongside actual OS permission state.
- `WEB_SEARCH_PROVIDER` and `SERPER_API_KEY` as Web Search.
- `PROVIDER_AUTO_FAILOVER` as the Providers master failover policy.

The following are deliberately outside this Settings scope unless a later product decision adds them:

- Legacy provider variables in `agent/.env.example`; provider configuration continues through the existing provider configuration store and `ProviderSetupFlow`.
- Local listener host/port and gateway URL wiring, which are connection/bootstrap configuration rather than ordinary device preferences.
- Context limits, hot-restart development controls, logs, dumps, test flags, and other operational/developer variables.
- Diagnostics, which are explicitly deferred.

## Runtime Settings Contract

The client uses typed device-settings commands over the unified device command layer. The agent owns a whitelist of supported settings; the client never reads or edits `.env` directly.

- Cloud Connection persists `ENABLE_GATEWAY`, acknowledges the request, then performs a controlled restart. The restart coordinator is transport-neutral and shared with the local HTTP restart endpoint.
- Computer Use persists `COMPUTER_USE`, applies through the agent-owned runtime contract, and reports platform permission state.
- Web Search persists `WEB_SEARCH_PROVIDER` and `SERPER_API_KEY`. The web-search service resolves both dynamically at the moment each search tool call executes, so no restart is required and an already-running agent immediately uses the new values. Secret values never leave the agent.
- Provider Auto Failover persists `PROVIDER_AUTO_FAILOVER` and updates `RuntimeRecoveryService.autoFailoverEnabled` immediately. It is displayed as the master switch in Providers; per-instance preferences are preserved and disabled visually while the master switch is off.
- When a process environment variable overrides a persisted value, the response marks that setting as externally managed so the UI cannot offer a misleading mutation.

All mutations use an explicit setting whitelist, typed validation, structured acknowledgement/error responses, and request correlation. Unknown keys and invalid provider values are rejected by the agent. Secret fields are redacted from protocol payloads, logs, errors, and diagnostic state.

For `ENABLE_GATEWAY`, the agent must update its current environment file using the existing environment-file service and its existing resolved environment path. It must send the successful acknowledgement before scheduling the existing controlled self-restart path. The client then treats the expected disconnect as a restart transition and reconnects through the coordinator. A failed write must not restart the agent.

Turning the Provider Auto Failover master switch off does not erase any provider instance's `allowAutoFailover` preference. Those per-instance switches remain visible for context but non-interactive until the master switch is enabled again. Turning the master back on restores their previous values.

## Unified Transport Contract

All feature data clients send a `DeviceConfig` plus command through one request/response abstraction backed by `DeviceConnectionCoordinator.ensureConnectedEndpointForAgent`.

This applies to:

- Device settings
- MCP inventory and mutation
- Skills inventory
- Workspace queries
- Provider settings

No presentation widget calls `SanadSocketService`, no feature forces the local socket, and no client code reads agent-owned files.

This is an architectural correction as well as a UI change. Existing code paths that call `ensureConnectedLocalRuntimeSocket`, send an empty device id, resolve the local daemon directly, or otherwise bypass `DeviceConnectionCoordinator` for MCP, Settings, Skills, Workspaces, or Providers must be migrated to the unified command abstraction. The same command names, request envelopes, response envelopes, validation, and domain behavior must work through both local and cloud transports.

Route selection is evaluated for the target `DeviceConfig` at request time. A feature must not cache an assumption that a device is local or remote. Transport loss, reconnect, and a route transition are handled below the feature layer.

The agent owns environment mutation, workspace resolution, MCP merge behavior, skill discovery, and provider recovery policy. The client owns presentation, navigation state, app preferences, and the explicit active-device choice.

## Navigation Compatibility

- `/settings` is canonical.
- Legacy `/agents` navigation redirects to Settings with Device Overview selected.
- Conversation sidebar and composer settings affordances open the canonical Settings destination.
- Existing MCP deep links remain valid while discovery moves into Settings.
- Back/forward navigation and restorable route state retain the selected Settings section, device, and workspace when the referenced entities still exist; otherwise the UI falls back predictably to General or the first available device.

## Verification Conditions

- Local and cloud transports produce the same protocol results for settings, MCP, skills, and workspace commands.
- Cloud Connection is editable only through a currently local route, persists before restart, returns an acknowledgement, and reconnects after controlled restart.
- A cloud-routed device never renders the Cloud Connection mutation switch.
- Web Search and Provider Auto Failover update live without restart.
- A web search issued after changing provider or Serper key uses the new configuration without recreating `WebSearchService` or restarting the daemon.
- Protocol responses never contain the Serper key; logs and errors do not leak it.
- Invalid or unknown runtime-setting mutations are rejected and do not partially change the environment file.
- Externally managed settings are visibly read-only and cannot present a false successful save.
- Device MCP/Skills pages never mix workspace-scoped entries.
- Workspace detail labels both scopes and exposes precedence.
- Same-name workspace MCP servers and skills are shown as the effective workspace item with the inherited device item clearly shadowed according to agent-owned precedence.
- First six workspaces render in navigation with Show all / Show less behavior.
- Selecting a Settings device does not change the active conversation device; Set as active does.
- Existing add/manage/restart/update/remove device actions remain discoverable in Settings, with destructive actions separated and confirmed.
- General theme changes remain client-owned and do not generate device protocol traffic.
- Provider instance failover preferences remain stored while the global switch is off and become interactive again with their prior values when it is re-enabled.
- Wide and compact layouts expose the same destinations.
- Legacy Manage Devices navigation lands in Settings.
- No changed feature presentation code depends directly on `SanadSocketService`, and MCP no longer forces a local runtime connection.
- Focused agent protocol, service, client data, widget, navigation, and daemon-backed integration tests cover the changed behavior.
