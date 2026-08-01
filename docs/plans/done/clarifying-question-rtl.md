---
title: "Clarifying Question RTL Presentation"
description: "Render every agent-provided question and answer choice using its own detected text direction."
status: "completed"
priority: "medium"
scope: "Flutter conversation suspension and ask-user result presentation"
---

# Clarifying Question RTL Presentation

## Problem

The client renders `system_ask_user` questions and choices inside the application's default LTR direction. Arabic glyph shaping still occurs, but paragraph alignment and mixed Arabic/Latin content do not follow the direction of each dynamic string. Completed ask-user question/answer rows have the same limitation.

## Implementation

- Reuse the conversation presentation text-direction utility for each dynamic question and choice independently.
- Keep fixed English controls and the surrounding card layout LTR.
- Apply dynamic direction to custom answer input as its content changes.
- Submit a non-empty custom answer with `Enter`; reserve `Shift+Enter` for inserting a line break, matching the primary composer.
- Apply the same behavior to completed ask-user question/answer rows and fallback output.
- Extend Arabic Unicode detection to the supported Arabic extended blocks.

## Definition of Done

- Arabic questions and choices render RTL and right-aligned.
- English content remains LTR and left-aligned, including mixed-language question sets.
- Custom Arabic answers use RTL while being entered.
- `Enter` submits custom answers while `Shift+Enter` keeps the editor open for multiline input.
- Completed question/answer output respects each string's direction independently.
- Focused widget tests and static analysis pass.
- The development client is running with the updated code for review.
