---
title: "Workspace Browser Folder Management"
description: "Corrective implementation plan for safe folder creation, rename, and deletion while selecting a remote workspace."
---

# Workspace Browser Folder Management

## Goal

Allow a user browsing a daemon-owned filesystem to create a direct child folder, rename a visible folder, or delete a visible folder before selecting the resulting directory as a workspace.

This scope manages directories only. Editing file contents is outside the workspace-selection experience.

## Current-State Triage

- The initial implementation accepts arbitrary target paths and recursively deletes them without rejecting filesystem roots or non-directory entities.
- Folder names are assembled by the client, allowing separators and traversal syntax to cross the displayed parent directory.
- Client error detection checks the envelope `type` instead of the canonical `event`, so daemon failures can be treated as success.
- No behavioral tests cover runtime mutation, canonical dispatch, transport correlation, confirmation, refresh, or failure presentation.
- No active technical or QA specification documents the feature.

## Design

1. The daemon remains authoritative for all filesystem mutation.
2. Create receives `parent_path` plus one validated `name`; rename receives an existing folder `path` plus one validated `new_name`; delete receives an existing folder `path`.
3. Folder names must be one path segment and cannot be empty, `.` or `..`.
4. Rename and delete reject filesystem roots, symbolic links, files, missing folders, and existing rename destinations.
5. Delete remains recursive only after explicit client confirmation.
6. Success responses preserve `request_id` and return the resulting normalized path. Failures use a request-correlated canonical `error` event.
7. The browser refreshes the current daemon snapshot after a successful mutation and keeps the current snapshot visible when mutation fails.

## Verification

- Runtime service tests cover create, rename, recursive delete, invalid names, collisions, roots, files, and symbolic links.
- Bridge tests cover all three commands, response correlation, and failure envelopes.
- Client command tests cover payloads, canonical acknowledgments, daemon errors, and disconnected requests.
- Widget tests cover create, rename, delete confirmation/cancellation, refresh, callback failures, and unavailable root mutation.
- Agent and client analyzers pass, followed by the focused test suites and the required daemon-backed protocol test for the changed socket boundary.
