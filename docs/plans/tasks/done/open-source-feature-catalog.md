---
title: "Open-Source Feature Catalog"
description: "Audit Sanad Agent capabilities and produce an evidence-backed source for README, documentation, and launch messaging."
status: "completed"
priority: "high"
scope: "Product documentation and public feature claims"
---

# Open-Source Feature Catalog

## Goal

Create one curated product document that explains Sanad Agent's value, organizes
its capabilities into coherent product themes, and prevents planned or
unverified behavior from being advertised as available.

## Triage

- Reconcile the proposed feature list with active documentation, source code,
  tests, release assets, and current platform targets.
- Mark claims as available, available with a caveat, planned, or requiring a
  reproducible measurement.
- Replace absolute marketing language such as "unlimited" with accurate,
  defensible wording.
- Preserve the current README work in progress; this task produces the factual
  source that a later README rewrite can consume.

## Deliverables

- `docs/product/features.md` as the public user-facing product source; the audit catalog remains private.
- A discoverability entry in `docs/product/MOC.md` and `docs/llms.txt`.
- A concise evidence and claim-safety matrix inside the catalog.

## Definition of Done

- Every user-provided capability is represented, corrected, or explicitly
  classified as unverified/planned.
- Additional implemented capabilities discovered in the repository are added.
- Public-ready wording is separated from engineering evidence and caveats.
- Documentation lint and index generation pass without modifying product code.
