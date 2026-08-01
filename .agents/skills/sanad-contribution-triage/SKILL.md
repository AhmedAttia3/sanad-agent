---
name: Sanad Contribution Triage
description: Route Sanad community requests to Discord, Discussions, Issues, or tracked plans and apply the versioned label taxonomy without exposing sensitive reports.
---

# Sanad Contribution Triage

Use this skill to classify an incoming question, idea, bug, documentation request, or accepted work item. It advises or prepares repository-native work; it does not mutate GitHub without explicit authorization.

## Routing

1. Stop immediately if the report may describe an undisclosed vulnerability. Direct it to GitHub Private Vulnerability Reporting or `security@eaststarai.com`; do not quote, summarize, or recreate sensitive details publicly.
2. Search existing Discussions, Issues, and pull requests for a duplicate.
3. Route quick help to Discord, an open-ended idea or RFC to a Discussion, and reproducible or accepted work to an Issue.
4. Require an Epic Issue plus one `docs/plans/tasks/` plan only when the change affects a protocol/API, schema/migration, security/privacy boundary, release contract, cross-component architecture, major UX workflow, or coordinated multi-PR delivery.
5. When a Discussion direction is accepted, have a maintainer record the decision and open or approve the actionable Issue. Votes alone do not accept a design.

## Labels

Read `.github/labels.yml` before classifying. Never invent or apply a label that is absent from the manifest.

- Start a new Issue with `needs-triage` and exactly one `type/*` label.
- Add at least one `comp/*` label and a platform label only when the scope is platform-specific.
- A maintainer assigns exactly one priority and one size after triage.
- Add `ready-for-contributor` only after scope, acceptance, and dependencies are clear.
- Add `good-first-issue` only when no architectural decision remains.
- Keep `type/security` limited to publicly safe hardening; private vulnerabilities never become ordinary Issues before coordinated disclosure.
- Protected review labels require an authorized maintainer and are not triage decoration.

## Output

Return: destination, duplicate-search result, proposed existing labels, missing information, plan threshold result, and the next human decision. On request, draft content but do not create, close, assign, or relabel work without explicit authorization.

## Local Simulation

Run `ruby scripts/community/simulate_workflows.rb` to exercise the routing boundaries without GitHub mutation.
