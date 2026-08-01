# Contributing to Sanad Agent

Thank you for helping improve Sanad Agent. This repository contains the Dart local agent, Flutter client, public documentation, tests, and public development tooling. EastStar AI hosted-service implementation is maintained separately and is not required for local development.

## Choose the Right Starting Point

- Search existing Discussions, Issues, and pull requests before opening new work.
- Use Discord for quick help, a Discussion for an idea or architectural RFC, and an Issue for accepted or reproducible work.
- Use a tracked plan under `docs/plans/tasks/` only for a public API or protocol, schema or migration, security/privacy boundary, release contract, cross-component architecture, major UX workflow, or coordinated multi-PR change.
- Report vulnerabilities through [SECURITY.md](SECURITY.md), never through a public Issue, Discussion, pull request, or Discord.
- Keep one pull request focused on one coherent change.

See [GOVERNANCE.md](.github/GOVERNANCE.md) for source-of-truth ownership and [SUPPORT.md](.github/SUPPORT.md) for routing.

## Development Setup

Install FVM, then prepare both Dart and Flutter packages from the repository root:

```bash
fvm install
cd agent && fvm dart pub get
cd ../client && fvm flutter pub get
cd ..
```

Use the repository launcher for an isolated agent/client pair:

```bash
scripts/sanad-dev run --no-cloud
```

The cloud-connected development profile uses optional EastStar AI development services; their source code is not required.

## Change Requirements

- Follow the nearest `AGENTS.md` contract for every changed file.
- Update the owning page under `docs/` when behavior or architecture changes.
- Keep README claims grounded in owning public documentation.
- Never commit credentials, private keys, tokens, personal paths, or private deployment configuration.
- Add focused tests for behavior changes and run the relevant analyzer.
- Use `fvm dart` in `agent/` and `fvm flutter` in `client/`.
- For large or sensitive work, keep the owning task plan checklist and evidence current.

## Pull Requests

Use a branch in an isolated worktree when the change is parallel, broad, risky, or review-bound. A pull request must:

1. link its Issue with `Closes #...` when it completes actionable work;
2. explain the problem, chosen change, affected components/platforms, security and privacy impact, and verification;
3. update the nearest contracts and owning documentation when required;
4. include screenshots for visible changes and migration/rollback notes when applicable;
5. use a Conventional Commits title, because the title becomes the squash commit message.

Direct and force pushes to `main` are prohibited. Human pull requests use squash merge only. Required checks and sensitive-path review labels must pass, and review conversations must be resolved. During the initial single-maintainer phase there is no general approval-count gate; [GOVERNANCE.md](.github/GOVERNANCE.md) defines protected review labels and the transition to one required approval plus CODEOWNERS review when an independent maintainer joins.

## Contribution Rights and Attribution

Sanad Agent does not require a Contributor License Agreement, Developer Certificate of Origin, `Signed-off-by` trailer, or `git commit -s`.

By submitting a contribution, you agree that it may be distributed under the repository's [MIT License](LICENSE) and represent that you have the right to submit it. You retain copyright in your contribution unless applicable law says otherwise.

Attribute human collaborators with Git authorship and `Co-authored-by` trailers where appropriate. You may disclose AI-assisted tooling in the pull request, but do not list an AI tool as an author or copyright holder.

## Community Conduct

Participation in Issues, Discussions, pull requests, reviews, and official community spaces follows [CODE_OF_CONDUCT.md](.github/CODE_OF_CONDUCT.md).
