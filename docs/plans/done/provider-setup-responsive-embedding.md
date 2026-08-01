---
title: "Provider Setup Responsive Embedding"
description: "Make the shared provider setup flow usable in both Settings and bounded setup overlays without vertical overflow."
---

# Provider Setup Responsive Embedding

Status: Complete

## Problem

`ProviderSetupFlow` is shared by the Providers page and the provider-required
overlay. The Providers page supplies an unbounded, page-level scroll view, while
the overlay supplies a bounded content area. Long setup steps currently rely on
the page scroll owner, so they overflow when rendered inside the overlay.

## Triage

- Keep one shared provider setup workflow and one cubit/state owner.
- Do not add overlay-specific copies of provider forms.
- Preserve the existing page-level Settings scrolling behavior.
- Give the reusable flow a bounded-height scroll path when its host constrains
  vertical space.

## Implementation

1. Add regression coverage for a short bounded overlay and an unbounded
   Settings-style embedding.
2. Make `ProviderSetupFlow` adapt its scroll extent to the incoming height
   constraints while retaining full-height loading and terminal presentation.
3. Record the responsive embedding invariant in the provider feature contract
   and provider protocol/QA documentation.

## Definition of Done

- A long provider instance form renders without `RenderFlex` overflow in a
  bounded overlay and can scroll to its final action.
- The same flow remains fully visible inside the Settings page's outer scroll
  view without imposing a fixed height.
- Focused widget tests and `fvm flutter analyze` pass.
- Graphify is updated after the code change when a graph exists in the worktree.

## Verification

- `fvm flutter analyze`
- `fvm flutter test test/widget/provider_setup_flow_test.dart`
- Focused provider setup bloc and widget suites
- Graphify update skipped because this worktree has no `graphify-out/graph.json`.
