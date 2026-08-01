---
title: "Refresh Sanad Self-Development Skills"
status: done
---

# Refresh Sanad Self-Development Skills

## Goal

Align the repository's development and testing skills with the current `sanad-dev` runtime contract and document both supported self-development modes:

1. live development of the currently running source checkout with durable controlled restart and continuation; and
2. isolated worktree development for parallel, risky, or review-bound changes.

## Triage

The current skills contain stale guidance:

- `sanad-agentic-developer` describes linked-worktree isolation through `SANAD_STATE_HOME` while the runtime now assigns one worktree-scoped `SANAD_HOME` and removes inherited `SANAD_STATE_HOME`.
- `sanad-client-tester` repeats the old state-home model and says driver/worktree runs disable cloud by default, while local and cloud connections are enabled by default and local-only verification requires `--no-cloud`.
- `sanad-subagent-developer` tells agents to offset ports and construct a relative `SANAD_HOME` manually instead of delegating runtime allocation to `sanad-dev`.
- several skill links and client paths still use stale `.agent/skills/` or parent-repository `sanad-agent/` prefixes.
- the skills do not explain the stronger live self-development path in which the active daemon edits its current source, observes live logs, requests its own controlled restart, persists the tool result/checkpoint, and resumes after the supervisor starts the updated source.

## Scope

- Refresh `.agents/skills/sanad-agentic-developer/SKILL.md`.
- Refresh stale runtime guidance and paths in `.agents/skills/sanad-client-tester/SKILL.md`.
- Refresh `.agents/skills/sanad-subagent-developer/SKILL.md` and stale local skill links in `.agents/skills/sanad-orchestrator/SKILL.md`.
- Update the developer guide and product feature documentation so the self-development modes are discoverable outside the skills.

## Definition of Done

- No active development/testing skill instructs linked worktrees to use `SANAD_STATE_HOME` or manual port offsets.
- Skills state that linked worktrees receive one isolated `SANAD_HOME`, while the primary checkout uses the normal user home unless explicitly overridden.
- Skills state that local and cloud connections are enabled by default and that `--no-cloud` selects local-only verification.
- The live current-checkout restart workflow describes pre-restart verification, bounded agent log reads, `sanad-dev restart agent`, durable checkpoint waiting, supervisor restart, and post-restart validation.
- Agent tool calls never use `sanad-dev logs -f` or `--follow`; continuous log streams are human-terminal-only because agent calls would block until interruption or timeout.
- Isolated worktrees remain the required path for parallel, risky, or PR-bound development.
- Workspace-relative links use current repository paths.
- Documentation lint/index generation succeeds.
