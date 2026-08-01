---
title: "Remote Workspace Folder Mutation Protocol"
description: "Daemon-owned protocol and validation model for creating, renaming, and deleting folders while selecting a remote workspace."
---

# Remote Workspace Folder Mutation Protocol

## Scope

Sanad uses two workspace-selection experiences:

- A same-device sanad project uses the operating system's native folder picker. Sanad does not replace or augment the native picker's folder-management behavior.
- A remote agent uses `WorkspaceBrowserDialog` and the daemon-owned workspace tree. This browser supports creating, renaming, and deleting directories before the user chooses a workspace path.

The feature manages directories only. It does not create files or edit file contents.

## Ownership and Flow

```text
WorkspaceBrowserDialog
  -> ConversationRepository
  -> ConversationClient
  -> ConversationCommands
  -> Sanad device command
  -> SanadProtocolBridge
  -> WorkspaceCommandHandler
  -> LocalWorkspaceRuntimeService
  -> host filesystem
```

The client sends user intent and refreshes the current tree after success. The daemon validates and executes every filesystem mutation. Client-side validation exists only for immediate feedback and is not an authority boundary.

## Canonical Commands

### Create folder

Command: `workspace.create_folder`

Payload:

```json
{
  "request_id": "opaque-request-id",
  "parent_path": "/selected/parent",
  "name": "new-folder"
}
```

Success event: `workspace.folder_created`

```json
{
  "request_id": "opaque-request-id",
  "path": "/selected/parent/new-folder"
}
```

Create is non-recursive and fails if any filesystem entity already owns the target name.

### Rename folder

Command: `workspace.rename_folder`

Payload:

```json
{
  "request_id": "opaque-request-id",
  "path": "/selected/parent/old-name",
  "new_name": "new-name"
}
```

Success event: `workspace.folder_renamed`, carrying the request id and normalized resulting `path`.

### Delete folder

Command: `workspace.delete_folder`

Payload:

```json
{
  "request_id": "opaque-request-id",
  "path": "/selected/parent/folder"
}
```

Success event: `workspace.folder_deleted`, carrying the request id and normalized deleted `path`.

Delete is recursive. The client must show an explicit destructive confirmation describing that nested files and folders will also be deleted.

## Failure Contract

Validation or operating-system failures return a canonical `error` event with the original `request_id` and a user-presentable `message`. The client accepts a mutation only when the event name exactly matches the expected success event; a null, error, timeout, or unrelated response is failure.

After failure, the remote picker keeps the current tree visible and presents the error. After success, it reloads the current daemon-owned path.

## Validation Model

A folder name is exactly one path segment. Empty names, `.`, `..`, `/`, and `\` separators are rejected by the daemon.

Create requires an existing concrete parent directory. Rename and delete require an existing directory and reject:

- regular files and missing entities;
- symbolic links;
- filesystem roots;
- rename destinations already occupied by any file, directory, or link.

The abstract Windows system-roots snapshot has an empty path and exposes no mutation controls. Host filesystem permissions remain authoritative for locations that pass structural validation.
