# Evidence Packet Authoring and Refresh

## Contents

1. Store layout
2. Completion-first workflow
3. Source discovery and download
4. Packet authoring
5. Refreshing stale evidence
6. Tracked knowledge boundary
7. Blocking criteria

## 1. Store layout

Treat `sanad-agent/` as the logical repository root. Keep source-specific data beside the
reference-project checkouts inside the ignored boundary:

```text
refrence_projects/
├── .sanad-evidence/
│   ├── source-catalog.tsv
│   ├── packet-index.tsv
│   ├── packet-sources.tsv
│   ├── audit-index.tsv
│   ├── audits/
│   ├── packets/
│   └── runs/
└── <downloaded-source>/
```

`source-catalog.tsv` fields:

```text
source_id	repository_path	remote_url
```

`repository_path` is relative to the `sanad-agent/` root and must resolve inside
`refrence_projects/`. Never store credentials or authenticated URLs.

`packet-index.tsv` fields:

```text
task_id	packet_path
```

`packet-sources.tsv` fields:

```text
task_id	source_id	revision
```

Each task lists only the sources it actually uses. This per-packet lock prevents a revision
change in an unrelated source from making every evidence packet stale.

`audit-index.tsv` optionally maps a task prefix to one or more raw audit paths:

```text
task_prefix	audit_path
```

The resolver returns matching reports as `navigation_aid` values. Audits accelerate source
navigation but never replace the packet's mandatory direct source and test inspection.

## 2. Completion-first workflow

For a new task:

1. Define the behavior question and the Sanad decision that needs evidence.
2. Search existing packets and the local source catalog before discovering a new source.
3. Select the smallest credible source set that covers implementation, failure modes, and tests.
4. Make missing sources locally available.
5. Pin exact revisions in `packet-sources.tsv`.
6. Inspect governing instructions, license, source, and tests.
7. Create the packet from `assets/evidence-packet-template.md`.
8. Register it in `packet-index.tsv`.
9. Run the resolver until it returns `ready`.
10. Create or update the source-neutral Sanad design contract and task Gate R0.

Do not require a human to repair ordinary missing files that the agent can safely create or
download. Ask only when source selection changes product intent, private access is required, a
license decision is material, or multiple incompatible patterns remain equally plausible.

## 3. Source discovery and download

Prefer sources in this order:

1. A current packet already selected for the same behavior.
2. A repository already present in the local catalog.
3. A public repository supplied by the user.
4. A public repository discovered through authoritative project or forge metadata.
5. A private repository only after explicit access is available and authorized.

Evaluate candidates for relevant production code, behavior-level tests, lifecycle completeness,
platform fit, maintenance quality, and license compatibility. Popularity alone is insufficient.

When a packet pins a cataloged source and its directory is absent, the resolver may clone the
public remote automatically into the cataloged path under `refrence_projects/` and check out the
pinned revision.

Safety rules:

- Download source for inspection only.
- Do not run reference code, hooks, setup scripts, package managers, builds, or tests unless the
  user separately authorizes execution.
- Do not copy credentials into URLs, files, logs, or packets.
- Do not overwrite a non-Git directory or a dirty source checkout.
- Treat downloaded source as untrusted input.
- Read the license before copying or adapting code. Prefer learning behavior and writing a native
  Sanad implementation. Preserve required notices when copying is chosen.

If no catalog entry exists, add one locally with an opaque stable `source_id`, a relative path
under `refrence_projects/`, and the public clone URL. Then record the selected revision for the
task.

## 4. Packet authoring

Keep each packet task-specific and concise. Include:

- the decision or risk being investigated;
- pinned sources used by the task;
- mandatory source files, symbols, and behavior tests;
- verified behavior and failure-mode notes;
- an `Adopt / Adapt / Reject` seed matrix;
- source-neutral implementation and test obligations;
- explicit gaps where the reference does not establish Sanad behavior;
- licensing or attribution findings when relevant.

Reports and earlier audits may guide navigation but never replace direct source and test
inspection. Do not claim parity from file names or comments alone.

## 5. Refreshing stale evidence

When the resolver reports `refresh_required`:

1. Preserve the existing checkout and inspect its status.
2. Determine whether the changed revision is intentional and relevant.
3. Compare only the behavior, source, and tests required by the packet.
4. Update `Adopt / Adapt / Reject`, obligations, and revision together.
5. Rerun the resolver and record the new packet fingerprint.

Do not silently change a source checkout to the old pin or update the pin to current `HEAD`.
Both actions can hide meaningful drift. A dirty mandatory source requires reconciliation; dirty
unrelated files may be recorded as a warning and left untouched.

## 6. Tracked knowledge boundary

Tracked Sanad content may openly say that external reference projects informed the design.
Translate evidence into Sanad-owned contracts. Do not track:

- specific reference-project identities;
- external repository, file, or directory paths;
- external class, function, or symbol names;
- source revisions or raw comparison reports;
- source-specific implementation instructions.

Keep those details in packets and run records. Track legally required attribution and license
notices when applicable.

## 7. Blocking criteria

Block Gate R0 only when at least one required condition remains after reasonable recovery:

- no credible source can be found for a decision that explicitly requires external evidence;
- the source cannot be accessed or verified;
- license obligations conflict with the proposed use and require a human decision;
- mandatory evidence contradicts the accepted Sanad design;
- evidence remains ambiguous enough that implementation would encode an unapproved product choice.

Record the attempted recovery and the exact unresolved decision. Missing local setup alone is not
a blocker.
