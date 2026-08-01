---
title: "Stable Workspace Identity, Rename, and Relocation"
description: "فصل هوية مساحة العمل عن مسارها مع الحفاظ على الجلسات عند نقل المجلد أو تغيير اسمه."
status: "completed"
scope: "agent persistence/runtime protocol and Flutter conversation workspace UX"
---

# Stable Workspace Identity, Rename, and Relocation

## Goal

Replace path-derived workspace identity with a stable UUID. A workspace keeps its sessions and client identity when its folder moves, exposes its current availability, and supports independent display-name editing and Change Path repair.

## Invariants

- `workspace_id` is an immutable UUID; it is never a filesystem path.
- `display_name` and `path` are independent mutable properties.
- Missing folders remain in workspace listings and their historical sessions remain queryable.
- Workspace tools, MCP, skills, and permission access resolve UUID to the current available path through the daemon.
- Relocation updates only the workspace path; session and work-item identities remain unchanged.
- Existing databases migrate atomically from path ids, including recoverable runtime rows.
- The client remains a projection of daemon workspace authority and does not infer relocation success.

## Gates

### Gate A — Persistence identity and migration

- Replace the legacy `workspaces(path PK)` schema with `workspaces(id PK, display_name, path UNIQUE, source, created_at, updated_at)`.
- Build one old-path-to-UUID map from stored workspaces and every persisted workspace reference.
- Migrate sessions and recoverable runtime workspace columns in one transaction.
- Preserve legacy paths that only appear in sessions by creating missing workspace records.
- Add repository operations to read, create, rename, relocate, and resolve workspaces.
- Cover fresh schema, legacy migration, missing paths, and runtime references.

### Gate B — Runtime and protocol

- Return available and missing workspaces from `list_workspaces`.
- Resolve UUID to path for tools, browsing, MCP, skills, and permissions.
- Add correlated `workspace.rename` and `workspace.relocate` commands.
- Validate non-empty names and relocation targets; reject a path already owned by another workspace through a correlated error response without terminating the transport.
- Keep folder-picker mutations distinct from workspace metadata mutations.

### Gate C — Client model, cache, and UX

- Add workspace availability to `DeviceWorkspace` and persisted cache encoding.
- Add repository/client commands for rename and relocate.
- Project authoritative mutation results into the cache and preserve correlated failure reasons for the project error toast.
- Keep missing workspace groups and historical sessions visible.
- Present missing-folder warning and disable new conversation creation until repair.
- Show a settings gear only while hovering a workspace row; route it to `/settings` with the exact device and workspace scope.
- Own `Rename Workspace` and `Change Path` actions on the workspace Settings page, not in a sidebar menu.
- Safely invalidate/remap legacy path-keyed cache state when daemon UUID identities arrive.

### Gate D — Verification and documentation

- Agent analyzer plus focused persistence/runtime/protocol tests.
- Client analyzer plus focused model/cache/widget tests.
- Daemon-backed coverage for migration and client/daemon command compatibility where mocks are insufficient.
- Update database schema, protocol/design documentation, and workspace QA coverage.
- Run `graphify update .` after code changes.

## Definition of Done

- Renaming or moving a folder outside Sanad leaves its workspace and sessions visible as unavailable.
- Change Path preserves workspace UUID and all session associations.
- Editing the display name does not mutate the filesystem path.
- Legacy path-based databases open without data loss.
- No path is emitted or persisted as a new workspace identity.
- Relevant analyzers and focused tests pass.
