# Architecture

MacOSPaint separates durable document truth from transient editor state and
GPU-facing render state.

## Modules

```text
MacOSPaintApp
    ├── PaintIO
    ├── PaintEngine
    └── PaintModel
```

- `PaintModel` contains platform-light, codable project records and editing
  contracts.
- `PaintEngine` owns sparse raster tiles, brush sampling, dirty regions, and
  immutable render snapshots.
- `PaintIO` owns atomic package reads/writes and format adapter seams.
- `MacOSPaintApp` owns AppKit/SwiftUI windowing, commands, workspaces, panels,
  and input translation.

## Document model

A project has one working color space and a freeform ordered list of artboards.
Every artboard owns exactly one independent layer tree. Moving content between
artboards is an explicit copy or move transaction.

Raster edits are destructive at commit time but retain tile deltas for undo.
Vector and text records remain editable until the user explicitly rasterizes
them. Rendering and persistence consume immutable generation-stamped snapshots
so they never observe a partially committed edit.

## Rendering direction

The vertical slice supplies the contracts and CPU-visible sparse tile store.
The production renderer will use an `MTKView`, Metal-backed tile cache, Core
Image previews, and Core Graphics/Core Text vector fallback. Tiles are 256×256
pixels and no operation may allocate a full 32,768² backing bitmap.

## Concurrency

- UI and undo registration are main-actor isolated.
- `RasterTileStore` and `ProjectPackageStore` are actors.
- Snapshot records are immutable and `Sendable`.
- File writes use a temporary sibling package followed by atomic replacement.

## Privacy and security

The app sandbox grants access only through user-selected URLs. V1 has no
network entitlement, telemetry, accounts, or plug-in loader. SVG import will
reject scripts and external resources before parsing supported geometry.
