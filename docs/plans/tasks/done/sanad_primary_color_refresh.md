---
title: "Sanad Primary Color Refresh"
description: "Repository-wide alignment of Sanad Agent identity surfaces to the approved blue primary while preserving EastStar AI and semantic status colors."
---

# Sanad Primary Color Refresh

## Goal

Replace the active Sanad Agent primary identity color `#5745F9` with `#60A5FA` across canonical artwork, Flutter themes, Web/PWA metadata, generated platform assets, documentation, and regression tests. Content rendered directly on the primary color uses `#0A0A0A` where contrast is required.

## Boundaries

- Update Sanad Agent identity sources and outputs only.
- Keep EastStar AI identity assets unchanged.
- Keep semantic status colors, including success, warning, error, connectivity, and code accents, unchanged.
- Retain legacy owner-supplied PNGs under `docs/assets/brand/source/` unchanged as provenance rather than active identity sources.
- Preserve unrelated working-tree changes and do not commit or push before owner review.

## Implementation

1. Align canonical Sanad SVG marks and wordmarks with the new primary.
2. Align Flutter `ColorScheme.primary` and `onPrimary`, Web/PWA metadata, and launcher configuration.
3. Update the deterministic brand generator and regenerate all owned raster, launcher, favicon, social, and platform outputs.
4. Update active brand/design documentation and tests to assert canonical vectors, generated pixels, theme colors, and contrast tokens.
5. Verify no active tracked source still uses the retired primary, then run formatting, focused brand tests, Flutter analysis, diff checks, and the required Graphify update.

## Definition of Done

- Active Sanad identity references use `#60A5FA`; primary foreground content uses `#0A0A0A` where applicable.
- Generated platform and handoff assets are reproduced from updated canonical sources.
- EastStar AI identity and semantic status colors have no task-induced changes.
- Focused tests and Flutter analysis pass.
- Existing unrelated uncommitted changes remain present.
- The complete uncommitted result is presented for review without commit or push.
