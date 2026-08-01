---
title: "Remote Workspace Folder Management QA"
description: "Regression matrix for create, rename, delete, validation, correlation, refresh, and error behavior in the remote workspace picker."
---

# Remote Workspace Folder Management QA

## Product Boundary

- Local same-device workspace selection continues to use the native operating-system folder picker.
- Folder-management controls appear only in Sanad's daemon-backed remote workspace browser.
- The browser manages directories, not file contents.

## Automated Coverage Matrix

| Area | Required behavior |
|---|---|
| Runtime create | Creates one direct child and returns its normalized path. |
| Runtime create conflicts | Existing files and directories fail rather than being treated as success. |
| Name validation | Empty, dot, parent traversal, slash, and backslash names fail. |
| Runtime rename | Renames within the existing parent and returns the new normalized path. |
| Rename collision | Existing target file, folder, or link leaves the source unchanged. |
| Runtime delete | Deletes confirmed folders recursively, including nested files. |
| Protected targets | Files, filesystem roots, missing paths, and symbolic links fail. |
| Protocol correlation | Every success and error preserves the original request id. |
| Client transport | Create sends parent plus name; rename and delete send exact target identities. |
| Client acknowledgment | Only the operation-specific canonical success event completes the request. |
| Create UI | A valid name invokes the callback and refreshes the current path. |
| Rename UI | A changed valid name invokes the callback and refreshes the current path. |
| Delete UI | Cancel performs no mutation; Delete confirms recursive destructive intent and refreshes. |
| Error UI | Mutation failure keeps the current snapshot visible and renders the failure. |
| Abstract roots | Empty-path system-root snapshots expose no create, rename, or delete controls. |
| Daemon boundary | A spawned isolated daemon performs create, rename, and recursive delete over the real socket protocol. |

## Manual Regression Scenarios

### Remote macOS/Linux agent

1. Open workspace selection for a remote agent and navigate to a writable directory.
2. Create a folder and verify it appears after refresh.
3. Rename that folder and verify the old name disappears.
4. Add content to the folder, choose Delete, inspect the recursive warning, and cancel; verify the folder remains.
5. Confirm deletion and verify the folder disappears.
6. Attempt a duplicate name or a protected location and verify the current listing remains visible with an error.

### Remote Windows agent

1. Open the remote browser at the abstract drive list and verify mutation controls are absent.
2. Enter a drive and a writable directory; verify controls become available.
3. Repeat create, rename, cancel-delete, confirmed-delete, duplicate-name, and permission-denied scenarios.

### Local sanad project

1. Open workspace selection for the confirmed same-device local agent.
2. Verify the operating system native folder picker still opens.
3. Verify no Sanad remote-browser folder-management dialog replaces it.

## Safety Regression

- Names containing `../`, `..\`, `/`, or `\` never create or rename outside the displayed parent.
- A filesystem root cannot be renamed or recursively deleted.
- A symbolic link is not followed and its target is not renamed or deleted.
- A daemon error cannot be mistaken for success because the envelope transport type is `event`; matching uses the canonical `event` field.
