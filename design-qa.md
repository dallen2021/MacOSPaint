# MacOSPaint final design QA

## Source truth

- Light: `docs/design/selected-light.png` — 1487×1058 px at 72 DPI.
- Graphite: `docs/design/selected-dark.png` — 1487×1058 px at 72 DPI.

## Implementation under test

- Native SwiftUI/AppKit application in `Sources/MacOSPaintApp`.
- Raw captures: `docs/design/qa/implementation-light-native.png` and
  `docs/design/qa/implementation-dark-native.png` — 1132×768 px at 72 DPI.
- Normalized captures: `docs/design/qa/implementation-light.png` and
  `docs/design/qa/implementation-dark.png` — 1560×1058 px at 72 DPI.
- Native application; CSS viewport and device-pixel ratio are not applicable.

The captured state uses the Essentials workspace at 63% zoom, Social Square as
the active artboard, the headline selected, the Layers inspector open, and the
Properties tab visible.

## Comparison evidence

- Full light comparison: `docs/design/qa/comparison-light.png` — 3047×1058 px.
- Full graphite comparison: `docs/design/qa/comparison-dark.png` — 3047×1058 px.
- Pinned-shelf focus: `docs/design/qa/focus-top-dark.png` — 3047×190 px.
- Square/inspector focus:
  `docs/design/qa/focus-inspector-square-dark.png` — 1674×700 px.

Each comparison places the selected visual target and the current native
implementation in one image before judging visible differences.

## Final findings

No remaining P0, P1, or P2 findings.

- The top area is now a distinct Pinned Tools shelf rather than a duplicate of
  the left rail. Any of the 25 rail tools can be pinned, alongside special
  workflow actions; items can be reordered or unpinned and overflow
  responsively.
- Gouache is fully readable and uses the generated dry-brush swatch.
- The graphite palette, light appearance, typography hierarchy, artboard
  geometry, bottom filmstrip, inspector density, imagery, selection bounds,
  icons, and spacing match the chosen direction closely.
- Flattened campaign fixtures consistently present as read-only, while a brush
  action creates and selects an editable Paint Layer.
- Painted content has explicit raster-layer ownership, commits to sparse tiles,
  and renders after save/reopen on the canvas and filmstrip.
- Keyboard shortcuts, focusable artboards/layers, VoiceOver labels, light/dark
  appearance, and reduced-transparency handling remain present.

Accepted P3 differences:

- The normalized evidence is softer than the raw 1:1 captures.
- Native window and panel proportions vary slightly from the concept frame.
- Light mode intentionally shares the graphite target's taller pinned-shelf
  structure for cross-appearance consistency.
- Future-milestone commands use honest explanatory notices rather than
  simulated results.
- The light native capture retains a cursor/screen-sharing artifact; the
  graphite capture and normalized side-by-side evidence are clean enough to
  judge the selected direction.
- Exact shelf persistence is covered at the public model and package-schema
  boundaries; a dedicated app-level StudioState save/reopen test remains a
  useful future strengthening.

## Comparison history

- P0: none found in any pass.
- P1 resolved: painted work was transient and document windows reopened a fresh
  studio. Strokes now commit to sparse raster tiles, package URLs hydrate the
  loaded manifest/snapshot, and a manual draw → save → quit → reopen test
  restored seven touched tiles.
- P1 resolved: brush marks could exist without a Paint Layer. Selecting a brush
  now creates/selects the owned raster layer, painting requires that visible
  layer, and deleting it removes its transient strokes and persisted tiles.
- P2 resolved: bundled flattened layers exposed contradictory visibility,
  duplicate, delete, text, and transform controls. Fixture controls now use a
  uniform read-only state and explanation.
- P2 resolved: the Gouache label was truncated. Its card is now 132 points wide.
- P2 resolved: the selected square lacked the target badge, footer, CTA, and
  coral underline; those generated assets are now present.
- P2 resolved: selection bounds crossed the tagline and the inspector left a
  large empty gap; both were corrected.
- P2 resolved: placeholder actions were silent. Implemented actions now work,
  and deferred actions surface explicit milestone notices.
- P2 resolved: asynchronous empty SwiftUI canvas overlays could stall initial
  window layout. Raster previews now use image-backed tile overlays and the
  final native launch is responsive.
- P2 resolved: custom shelves could lose actions or collapse distinct items
  sharing one engine tool after reopening. The public schema now stores exact,
  ordered tool/action identities while retaining a validated legacy
  `pinnedTools` projection; 41 tests cover round-trip and old-manifest
  behavior.

final result: passed
