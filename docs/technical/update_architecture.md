---
title: "Release and Update Architecture"
description: "The shared release manifest and the update ownership of the Sanad agent and client on every runtime."
---

# Release and Update Architecture

## Shared release contract

`release/release-contract.json` defines the stable version, build, tag, channel,
repository, canonical filenames, platform, architecture, and expected signature
type. The shared Dart package under `shared/release_contract/` parses and
validates that contract and the generated release manifest.

The public release manifest is generated only after every public and private
handoff artifact required by the contract exists. Its public entries include
the immutable download URL, byte size, SHA-256 digest, platform, architecture,
component, version, and signature metadata. Private AAB and Web handoffs remain
protected workflow artifacts and are verified by their build attestations. The
workflow refuses version/tag/commit mismatches, missing artifacts,
non-canonical filenames, or checksum differences.

## Agent update ownership

`AgentUpdateService` is the only owner of native-agent replacement.

- `sanad update` calls the service directly.
- The standalone desktop client requests the daemon's update endpoint; it does
  not implement a competing downloader.
- A source/FVM runtime returns `source_managed` immediately and never performs
  Git operations or modifies the checkout.
- A standalone runtime selects the exact operating-system and architecture
  artifact, validates its size and SHA-256, stages it beside the installed
  executable, acquires an update lock, preserves a backup, and performs an
  atomic replacement.
- Replacement failure restores the previous executable. Windows uses a
  detached replacement process because the running executable cannot replace
  itself in place.

The public status vocabulary is `up_to_date`, `update_available`, `updating`,
`restart_required`, `source_managed`, `unsupported_target`,
`verification_failed`, `rollback_completed`, and `failed`.

## First-install exception

When a packaged desktop client cannot find an installed local agent, it may use
`VerifiedAgentBootstrapInstaller` once. This bootstrap consumes the same
release manifest, platform selection, size check, SHA-256 validation, staging,
backup, and atomic replacement rules as the agent updater. After installation,
the operating-system service owns the daemon lifecycle and all later updates
return to `AgentUpdateService`.

Source-mode clients never bootstrap or replace a source daemon.

## Client self-update ownership

Client application updates remain separate from `sanad update`:

- macOS and Windows use the generated Appcast and their native Sparkle/
  WinSparkle signature mechanisms.
- Linux exposes a user-approved release flow; it does not silently replace an
  installed package.
- Android delegates package installation and signature enforcement to the
  operating system.
- iOS is updated through Internal TestFlight for the first release.
- Web compares the deployed `version.json` with its compiled version without
  forcing a reload loop; the browser loads the newer deployment on the next
  user-initiated reload.
- Source/FVM clients disable packaged self-update and leave the checkout under
  developer control.

## Appcast

The Appcast is derived deterministically from the verified release manifest
after the signed macOS and Windows client packages exist. It contains separate
platform entries and update signatures. The file is never tracked in Git and
is published atomically to
`https://updates.sanad.eaststarai.com/appcast.xml`.

## Trust boundaries

Runtime replacement always requires a matching manifest entry and checksum.
Platform code signing adds publisher identity on Apple, Windows, and Android.
GitHub artifact attestations bind release outputs to the public workflow and
commit; Linux users and distributors can verify that provenance independently.
No updater accepts tokens, provider credentials, or deployment secrets.
