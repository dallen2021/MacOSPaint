import Foundation
import PaintModel

/// The stable address of one sparse raster tile.
///
/// Tile coordinates are layer-local. Including the layer identifier in the key
/// prevents data from one artboard's layer tree from being accidentally
/// composited into another.
public struct RasterTileKey: Hashable, Codable, Sendable, Comparable {
    public let layerID: UUID
    public let coordinate: TileCoordinate

    public init(layerID: UUID, coordinate: TileCoordinate) {
        self.layerID = layerID
        self.coordinate = coordinate
    }

    public init(layerID: UUID, x: Int, y: Int) {
        self.init(layerID: layerID, coordinate: TileCoordinate(x: x, y: y))
    }

    public static func < (lhs: RasterTileKey, rhs: RasterTileKey) -> Bool {
        if lhs.layerID.uuidString != rhs.layerID.uuidString {
            return lhs.layerID.uuidString < rhs.layerID.uuidString
        }
        if lhs.coordinate.y != rhs.coordinate.y {
            return lhs.coordinate.y < rhs.coordinate.y
        }
        return lhs.coordinate.x < rhs.coordinate.x
    }

    /// Locates a pixel without assuming non-negative coordinates.
    public static func containing(
        layerID: UUID,
        pixelX: Int,
        pixelY: Int
    ) -> (key: RasterTileKey, localX: Int, localY: Int) {
        let tileX = floorDiv(pixelX, by: RasterTileStore.tileSize)
        let tileY = floorDiv(pixelY, by: RasterTileStore.tileSize)
        return (
            RasterTileKey(layerID: layerID, x: tileX, y: tileY),
            pixelX - tileX * RasterTileStore.tileSize,
            pixelY - tileY * RasterTileStore.tileSize
        )
    }
}

/// Immutable, validated RGBA8 tile storage.
public struct RasterTile: Equatable, Sendable {
    public static let bytesPerPixel = 4
    public static let byteCount =
        RasterTileStore.tileSize * RasterTileStore.tileSize * bytesPerPixel

    public let bytes: Data

    public init(bytes: Data) throws {
        guard bytes.count == Self.byteCount else {
            throw RasterTileStoreError.invalidTileByteCount(
                expected: Self.byteCount,
                actual: bytes.count
            )
        }
        self.bytes = bytes
    }

    public static var transparent: RasterTile {
        RasterTile(
            validatedBytes: Data(repeating: 0, count: byteCount)
        )
    }

    public var isFullyTransparent: Bool {
        guard !bytes.isEmpty else { return true }
        var index = bytes.index(bytes.startIndex, offsetBy: 3)
        while index < bytes.endIndex {
            if bytes[index] != 0 {
                return false
            }
            index = bytes.index(
                index,
                offsetBy: Self.bytesPerPixel,
                limitedBy: bytes.endIndex
            ) ?? bytes.endIndex
        }
        return true
    }

    public func rgba(x: Int, y: Int) throws -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        guard (0..<RasterTileStore.tileSize).contains(x),
              (0..<RasterTileStore.tileSize).contains(y)
        else {
            throw RasterTileStoreError.pixelOutsideTile(x: x, y: y)
        }
        let offset = (y * RasterTileStore.tileSize + x) * Self.bytesPerPixel
        let start = bytes.index(bytes.startIndex, offsetBy: offset)
        return (
            bytes[start],
            bytes[bytes.index(start, offsetBy: 1)],
            bytes[bytes.index(start, offsetBy: 2)],
            bytes[bytes.index(start, offsetBy: 3)]
        )
    }

    private init(validatedBytes: Data) {
        bytes = validatedBytes
    }
}

public enum RasterTileStoreError: Error, Equatable, Sendable {
    case invalidTileByteCount(expected: Int, actual: Int)
    case pixelOutsideTile(x: Int, y: Int)
    case generationConflict(expected: UInt64, actual: UInt64)
    case deltaDoesNotMatchCurrentState(key: RasterTileKey)
}

/// A proposed replacement. `nil` removes a tile from sparse storage.
public struct RasterTileMutation: Equatable, Sendable {
    public let key: RasterTileKey
    public let replacement: RasterTile?

    public init(key: RasterTileKey, replacement: RasterTile?) {
        self.key = key
        self.replacement = replacement
    }
}

public struct RasterTileCommit: Equatable, Sendable {
    public let generation: UInt64
    public let deltas: [TileDelta]

    public init(generation: UInt64, deltas: [TileDelta]) {
        self.generation = generation
        self.deltas = deltas
    }
}

public struct DirtyTileBatch: Equatable, Sendable {
    public let generation: UInt64
    public let keys: [RasterTileKey]

    public init(generation: UInt64, keys: [RasterTileKey]) {
        self.generation = generation
        self.keys = keys
    }
}

/// A generation-stamped value snapshot. Its dictionary and tile values are
/// copied on write, so render and save tasks cannot observe later mutations.
public struct RasterTileSnapshot: Equatable, Sendable {
    public let generation: UInt64
    public let tiles: [RasterTileKey: RasterTile]

    public init(generation: UInt64, tiles: [RasterTileKey: RasterTile]) {
        self.generation = generation
        self.tiles = tiles.filter { !$0.value.isFullyTransparent }
    }

    public subscript(key: RasterTileKey) -> RasterTile? {
        tiles[key]
    }

    public var orderedKeys: [RasterTileKey] {
        tiles.keys.sorted()
    }
}

/// Sparse, transaction-shaped raster storage.
///
/// A commit advances the generation once, even when it touches many tiles.
/// Transparent replacements are canonicalized to absence so a large blank
/// layer never allocates a full backing bitmap.
public actor RasterTileStore {
    public static let tileSize = 256

    private var tiles: [RasterTileKey: RasterTile]
    private var generation: UInt64
    private var dirtyKeys: Set<RasterTileKey>

    public init() {
        tiles = [:]
        generation = 0
        dirtyKeys = []
    }

    public init(snapshot: RasterTileSnapshot) {
        tiles = snapshot.tiles
        generation = snapshot.generation
        dirtyKeys = []
    }

    public func currentGeneration() -> UInt64 {
        generation
    }

    public func tileCount() -> Int {
        tiles.count
    }

    public func tile(at key: RasterTileKey) -> RasterTile? {
        tiles[key]
    }

    public func snapshot() -> RasterTileSnapshot {
        RasterTileSnapshot(generation: generation, tiles: tiles)
    }

    public func dirtyTiles() -> DirtyTileBatch {
        DirtyTileBatch(generation: generation, keys: dirtyKeys.sorted())
    }

    /// Returns and clears the dirty set at the current generation.
    public func consumeDirtyTiles() -> DirtyTileBatch {
        let batch = dirtyTiles()
        dirtyKeys.removeAll(keepingCapacity: true)
        return batch
    }

    @discardableResult
    public func setTile(
        _ tile: RasterTile?,
        at key: RasterTileKey,
        artboardID: UUID,
        expectedGeneration: UInt64? = nil
    ) throws -> RasterTileCommit {
        try apply(
            [RasterTileMutation(key: key, replacement: tile)],
            artboardID: artboardID,
            expectedGeneration: expectedGeneration
        )
    }

    /// Atomically applies a batch and returns deltas suitable for one undo step.
    ///
    /// If the same coordinate occurs more than once, the final replacement wins
    /// and the resulting delta still captures the state before the whole batch.
    @discardableResult
    public func apply(
        _ mutations: [RasterTileMutation],
        artboardID: UUID,
        expectedGeneration: UInt64? = nil
    ) throws -> RasterTileCommit {
        try check(expectedGeneration)

        var finalReplacements: [RasterTileKey: RasterTileMutation] = [:]
        for mutation in mutations {
            finalReplacements[mutation.key] = mutation
        }

        var changes: [(RasterTileKey, RasterTile?, RasterTile?)] = []
        changes.reserveCapacity(finalReplacements.count)
        for (key, mutation) in finalReplacements {
            let replacement = canonicalized(mutation.replacement)
            let before = tiles[key]
            if before != replacement {
                changes.append((key, before, replacement))
            }
        }
        changes.sort { $0.0 < $1.0 }

        guard !changes.isEmpty else {
            return RasterTileCommit(generation: generation, deltas: [])
        }

        for (key, _, replacement) in changes {
            tiles[key] = replacement
            dirtyKeys.insert(key)
        }
        generation &+= 1

        let deltas = changes.map { key, before, after in
            TileDelta(
                artboardID: artboardID,
                layerID: key.layerID,
                coordinate: key.coordinate,
                before: snapshotData(before),
                after: snapshotData(after)
            )
        }
        return RasterTileCommit(generation: generation, deltas: deltas)
    }

    /// Applies model-owned deltas in either direction after verifying that the
    /// current tile state matches the expected side of every delta.
    @discardableResult
    public func apply(
        deltas: [TileDelta],
        direction: TileDeltaDirection,
        expectedGeneration: UInt64? = nil
    ) throws -> UInt64 {
        try check(expectedGeneration)

        let sortedDeltas = deltas.sorted {
            RasterTileKey(layerID: $0.layerID, coordinate: $0.coordinate)
                < RasterTileKey(layerID: $1.layerID, coordinate: $1.coordinate)
        }
        for delta in sortedDeltas {
            let key = RasterTileKey(
                layerID: delta.layerID,
                coordinate: delta.coordinate
            )
            let expected = try tile(from: direction == .forward ? delta.before : delta.after)
            guard tiles[key] == canonicalized(expected) else {
                throw RasterTileStoreError.deltaDoesNotMatchCurrentState(key: key)
            }
        }

        var changed = false
        for delta in sortedDeltas {
            let key = RasterTileKey(
                layerID: delta.layerID,
                coordinate: delta.coordinate
            )
            let replacement = try tile(
                from: direction == .forward ? delta.after : delta.before
            )
            let canonical = canonicalized(replacement)
            if tiles[key] != canonical {
                tiles[key] = canonical
                dirtyKeys.insert(key)
                changed = true
            }
        }

        if changed {
            generation &+= 1
        }
        return generation
    }

    private func check(_ expectedGeneration: UInt64?) throws {
        if let expectedGeneration, expectedGeneration != generation {
            throw RasterTileStoreError.generationConflict(
                expected: expectedGeneration,
                actual: generation
            )
        }
    }

    private func canonicalized(_ tile: RasterTile?) -> RasterTile? {
        guard let tile, !tile.isFullyTransparent else {
            return nil
        }
        return tile
    }

    private func snapshotData(_ tile: RasterTile?) -> TileDataSnapshot {
        if let tile {
            return .bytes(tile.bytes)
        }
        return .absent
    }

    private func tile(from snapshot: TileDataSnapshot) throws -> RasterTile? {
        switch snapshot {
        case .absent:
            nil
        case let .bytes(data):
            try RasterTile(bytes: data)
        }
    }
}

public enum TileDeltaDirection: Sendable {
    case forward
    case backward
}

private func floorDiv(_ value: Int, by divisor: Int) -> Int {
    precondition(divisor > 0)
    let quotient = value / divisor
    let remainder = value % divisor
    return remainder < 0 ? quotient - 1 : quotient
}
