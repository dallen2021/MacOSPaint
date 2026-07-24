# `.macospaint` project format

The `.macospaint` format is a Finder package with a versioned public manifest.
The schema is the project's v1 compatibility contract.

```text
Example.macospaint/
├── manifest.json
├── tiles/
│   └── <content-hash>.tile
├── masks/       # reserved; empty in the current implementation
├── resources/   # reserved; empty in the current implementation
└── previews/    # reserved; empty in the current implementation
```

## Manifest

`manifest.json` encodes `ProjectManifestV1`:

- schema version and project identifier
- project name, working color space, and ordered artboards
- each artboard's pasteboard frame, pixel dimensions, DPI, background, and
  independent layer tree
- raster tile references
- retained vector scenes and editable text data
- layer visibility, lock state, opacity, blend mode, transform, and mask
  metadata
- the document's workspace descriptor, including panel placements, the exact
  ordered pinned shelf, and its legacy canvas-tool projection

All identifiers are stable UUID strings. Coordinates use points on the
freeform pasteboard and pixels within each artboard.

### Pinned shelf

`workspace.pinnedItems` is an optional ordered array that preserves each shelf
entry exactly. Every entry has a stable discriminator and identifier:

```json
[
  { "kind": "tool", "identifier": "rectangle" },
  { "kind": "tool", "identifier": "ellipse" },
  { "kind": "action", "identifier": "gouache-brush" },
  { "kind": "action", "identifier": "export-png" }
]
```

Tools and actions remain distinct even when they share an engine tool. For
example, Rectangle and Ellipse both project to `shape`, while Gouache and the
ordinary Brush tool both project to `brush`. Export actions have no canvas-tool
projection.

`workspace.pinnedTools` remains required as the de-duplicated compatibility
projection. Readers prefer `pinnedItems` when present and fall back to
`pinnedTools` for packages written before the exact shelf field was added.
Writers keep both fields synchronized. A missing `pinnedItems` field therefore
remains valid schema-1 data.

### Current mask limitation

`LayerMaskRecord` reserves the v1 manifest shape for grayscale tile
references, but the current raster snapshot cannot distinguish a layer's
pixels from its mask pixels. To prevent data loss, readers and writers reject
any manifest containing nonempty mask tile references with a clear
`unsupportedMaskTiles` error. Empty mask metadata may round-trip. The `masks/`
directory remains reserved until mask pixels have a distinct storage key and
lossless round-trip tests.

The `resources/` and `previews/` directories are likewise reserved by the
current vertical slice. Writers create them empty and do not advertise support
for preserving files placed there by hand.

## Compatibility behavior

- Schema 1 is the first schema; there is no older migration path yet.
- A newer unsupported schema opens read-only.
- Missing or corrupt tiles produce a recoverable error and never overwrite the
  original package.
- Workspace layout is persisted in `manifest.json`.
- Undo history and transient selections are not persisted.

## Atomic writes

Writers create a complete sibling package, flush the manifest and blobs, then
replace the destination atomically. Render and save operations use the same
immutable project generation. The synchronous `NSDocument` `FileWrapper` path
uses the same serializer and embeds every raster blob referenced by the
generated manifest.
