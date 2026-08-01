---
title: "Fix Active Tail Alignment and Tagged Reasoning Streaming"
description: "Keep active conversations bottom-aligned on open and emit tagged provider reasoning while it is still streaming."
status: "complete"
priority: "high"
design_contracts:
  - "docs/technical/client_conversation_navigation.md"
  - "docs/technical/reasoning_thoughts_separation.md"
---

# Fix Active Tail Alignment and Tagged Reasoning Streaming

## Problem

- Opening a session with authoritative active work anchors the latest event near
  the top of the conversation viewport instead of placing its end immediately
  above the composer.
- OpenAI-compatible models that encode reasoning in a leading text tag can have
  their full reasoning buffered until the provider stream ends. A following
  tool event then supersedes the transient reasoning row before Flutter gets a
  useful interval in which to render it. MiniMax M3 may use
  `<mm:think>...</mm:think>`, but the lifecycle issue applies to every supported
  tagged fallback.

## Design

1. Preserve the centered-sliver, lazy-history layout. For active work, put the
   latest event in the sliver before the center and place that center at the
   visible bottom boundary above the composer. Idle restored anchors continue
   to start near the visible top.
2. Replace whole-stream tagged buffering with a small incremental state machine.
   Buffer only an undecided opening marker or a possible split closing marker;
   emit confirmed reasoning immediately, then pass post-tag answer content
   through normally.
3. Preserve the existing structured-reasoning precedence and all supported
   tagged markers, including the current uncommitted MiniMax marker work.

## Verification

- Widget test asserts that active work opens with the latest event bottom-aligned
  above the composer while old history remains lazily unbuilt.
- Parser tests cover split opening/closing markers, immediate reasoning deltas,
  post-tag answer streaming, untagged passthrough, and unclosed reasoning.
- Focused client and agent tests pass.
- Client and agent analyzers pass.
- Relevant technical and QA documentation is updated.

## Result

- Active-session tail alignment is covered by the focused conversation scroll
  widget suite: 7 tests passed.
- Tagged parser coverage: 4 tests passed; OpenAI-compatible adapter coverage:
  40 tests passed.
- Reasoning presentation/mapping regression coverage: 14 tests passed.
- MiniMax title cleanup coverage: 1 focused test passed.
- `fvm dart analyze` and `fvm flutter analyze`: no issues.

## Performance Follow-up

The correct active-tail position exposed a separate presentation cost: ordinary
post-layout growth still started a 220ms scroll animation. Streaming or opening
updates could restart that animation repeatedly, producing visible movement and
frame pressure. Opening and follow-tail growth must settle directly at the
latest extent after layout, without animation. The one deliberate animation for
a newly submitted local user message remains unchanged.

Additional verification must prove that streamed growth reaches the new maximum
extent in the first settled frame and leaves no active scroll animation.

Direct follow-tail settling removed repeated stream animations, but live review
surfaced two remaining transitions. First, the active-tail anchor depended on an
estimated composer height for its first frame and shifted after the real composer
measurement. The timeline must remain unpainted until that first measurement,
then appear once at its final position. Second, a newly accepted local user
message must become the top opening anchor without animation so the assistant
response grows below it; it must not inherit active-tail bottom alignment.

Additional regression coverage owns both first-paint stability and local-user
message placement before this follow-up can close.

A final follow-up separates user-message placement from automatic tail tracking.
A new user message may become a top anchor only when the prior timeline is
empty; otherwise it appends without changing the viewport. Automatic assistant
follow requires both preserved follow eligibility and the latest content
reaching the composer boundary. Short output below a top-anchored first user
message must not move the viewport. Manual movement away from the tail disables
eligibility; manually returning to the tail enables it again.

Regression coverage must verify empty versus non-empty user insertion, boundary-
gated activation, already-following stream growth, and manual opt-out before the
plan returns to complete.

The final follow-up is complete. The focused scroll suite passes 10 tests and the
combined timeline/composer scope passes 30 tests. Flutter analysis reports no
issues. The live client accepted the final Hot Restart, preserving the connected
main-branch runtime while loading the explicit eligibility/boundary follow state.

## Minimal-Reveal Correction

A non-empty timeline must not treat “preserve pixels” as permission to leave a
new user message obscured by the composer or wholly below the viewport. After
the canonical user row is laid out, the client performs an animation-free
minimal reveal: no movement when the complete row is already visible, otherwise
only the distance needed to place its bottom at the visible boundary above the
composer. The existing center anchor is not rebuilt, and the tail itself is not
the positioning target.

Minimal reveal is independent from the two follow states. It neither grants nor
revokes follow eligibility and never activates active tail follow. Eligibility
is granted only by opening authoritative active work at the tail or by a manual
return to the bottom. Active tail follow begins only when that eligibility is
present and the latest rendered content reaches the composer boundary. Manual
movement away clears both states immediately; reasoning, tool, final-answer,
informational, and runtime-derived timeline updates cannot restore either state
or change the reading offset.

Correction verification adds widget coverage for fully visible, partially
obscured, and below-viewport user rows; preserved disabled-follow offsets across
multiple event kinds; manual return-to-tail reactivation; first-message top
anchoring; lazy history; and the absence of active scroll animations after every
programmatic placement.

The correction is complete. The focused timeline suite passes 12 tests, the
combined timeline/composer regression scope passes 32 tests, and
`fvm flutter analyze` reports no issues.

## Short-Content Top Clamp

Tail alignment must never leave a short conversation attached to the composer
with an empty upper viewport. Active opening therefore keeps its current lazy
tail layout only when rendered content fills or exceeds the visible timeline
height. When the complete short timeline is already built, the client measures
its first visible row before painting, shifts the opening anchor upward by the
otherwise-empty gap, preserves follow eligibility, and leaves active tail follow
disabled until later growth reaches the composer boundary.

The clamp must not eagerly build old history, animate, expose a transient bottom
position, alter idle-session restoration, or affect minimal reveal. Regression
coverage must prove that short active content opens at the top, long active
history still opens at the tail lazily, and eligible short content transitions
to active tail follow only after it fills the viewport.

## In-Place Stream Growth Correction

Updating the text or layout of an existing reasoning, thinking, or final-answer
event must never perform an unconditional tail jump. While follow eligibility is
disabled, the exact viewport offset is preserved. While the user actively
follows the tail, growth performs only a geometry-based minimal reveal when the
row bottom crosses behind the composer; fully visible growth does not move. An
eligible short active timeline may activate this minimal follow when growth
first reaches the composer boundary.

Structurally new agent events retain the eligibility and boundary gates and gain
a paint-only entrance transition (fade plus slight upward slide). The transition
must not alter layout, scroll offset, history opening, user-message placement, or
re-run for stream updates to the same event id.

Active opening keeps the latest mutable row in the downward-growing sliver,
resolves short-content top alignment before paint, and marks a non-empty initial
projection as already opened so later user-message state updates cannot rebuild
the opening anchor. Regression coverage owns followed-growth minimal reveal,
manual opt-out stability, new-event entrance motion, and no ScrollController
animation.

The completed focused timeline suite passes 16 tests, the combined
timeline/composer scope passes 36 tests, and `fvm flutter analyze` reports no
issues.

## Entrance Compositing Correction

The entrance transition must not leave every completed event inside permanent
`RepaintBoundary`, opacity, or fractional-transform layers. Those layers include
usage statistics, copy controls, and tool details, so hover and unrelated event
repaints can re-rasterize text and icons at subtly different sub-pixel origins.
Use a non-composited layout measurement box, retain fade/slide only for the
220ms entrance interval, then replace the transition subtree with the raw event
child. Regression coverage must prove the transition exists while entering,
disappears after completion, does not replay for same-id updates, and leaves
control geometry stable.

The compositing correction is complete. The focused timeline suite remains 16
passing tests, the combined timeline/composer scope remains 36 passing tests,
and `fvm flutter analyze` reports no issues.

## Active-Follow New-Event Scroll Motion

Restore smooth ScrollController motion only when a structurally new agent event
arrives while active tail follow was already set. Use a latest-generation 280ms
`easeOutCubic` animation, increased slightly from the historical 220ms value,
then directly settle any final extent drift. User messages, opening placement,
minimal reveal, composer correction, manual opt-out, and same-id thinking/final
stream growth remain non-animated. A later mutation or manual action must cancel
stale animation ownership.

The active-follow motion is complete. The focused timeline suite passes 16
tests, the combined timeline/composer scope passes 36 tests, and
`fvm flutter analyze` reports no issues.
