---
title: "Mobile Multiline Enter Behavior"
description: "Keep mobile software-keyboard Enter as a newline action across conversation text inputs while preserving desktop submission shortcuts."
status: "completed"
priority: "high"
scope: "Primary composer, custom clarifying answers, and inline message editing"
---

# Mobile Multiline Enter Behavior

## Problem

Conversation text fields currently expose desktop Enter submission shortcuts around multiline editors. On phones, the software keyboard Enter action must create a line break instead of dispatching content. The primary composer, custom clarifying answer editor, and inline message editor need one consistent platform-aware policy.

## Interaction Contract

| Platform | Enter | Shift+Enter | Submission control |
|---|---|---|---|
| Android/iOS | Insert a line break | Insert a line break when available | Visible Send/Submit button |
| Desktop/Web with hardware keyboard | Submit | Insert a line break | Enter shortcut or visible button |

The primary desktop composer retains its existing Control/Command+Enter queue shortcut. Mobile software-keyboard actions must never trigger desktop shortcut bindings.

## Implementation

- Introduce one reusable platform-aware multiline submission wrapper.
- Skip hardware submission shortcuts on Android and iOS.
- Explicitly configure all three editors for multiline keyboard input and newline IME actions.
- Apply desktop Enter submission to inline message editing as well as the existing composer and custom-answer editor.
- Add focused desktop and simulated-mobile widget coverage for every affected editor.

## Definition of Done

- Mobile Enter inserts a newline and does not invoke send/submit in all three inputs.
- Desktop Enter submits in all three inputs.
- Desktop Shift+Enter inserts a newline without submission in all three inputs.
- Existing primary-composer queue shortcuts remain unchanged on desktop.
- Static analysis and focused widget tests pass.
- The running client is reloaded for review.
