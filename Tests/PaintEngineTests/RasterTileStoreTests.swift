import Foundation
import PaintModel
import Testing
@testable import PaintEngine

struct RasterTileStoreTests {
    @Test
    func pixelBoundariesUseFloorDivision() {
        let layerID = UUID()

        assertLocation(layerID: layerID, pixel: 0, tile: 0, local: 0)
        assertLocation(layerID: layerID, pixel: 255, tile: 0, local: 255)
        assertLocation(layerID: layerID, pixel: 256, tile: 1, local: 0)
        assertLocation(layerID: layerID, pixel: -1, tile: -1, local: 255)
        assertLocation(layerID: layerID, pixel: -256, tile: -1, local: 0)
        assertLocation(layerID: layerID, pixel: -257, tile: -2, local: 255)
    }

    @Test
    func tileRejectsIncorrectByteLength() {
        #expect(
            throws: RasterTileStoreError.invalidTileByteCount(
                expected: RasterTile.byteCount,
                actual: 3
            )
        ) {
            try RasterTile(bytes: Data([0, 1, 2]))
        }
    }

    @Test
    func batchIsOneGenerationAndCoalescesDuplicateKeys() async throws {
        let store = RasterTileStore()
        let artboardID = UUID()
        let layerID = UUID()
        let firstKey = RasterTileKey(layerID: layerID, x: 0, y: 0)
        let secondKey = RasterTileKey(layerID: layerID, x: 1, y: 0)
        let firstTile = try tile(red: 10)
        let finalFirstTile = try tile(red: 20)
        let secondTile = try tile(red: 30)

        let commit = try await store.apply(
            [
                RasterTileMutation(key: firstKey, replacement: firstTile),
                RasterTileMutation(key: secondKey, replacement: secondTile),
                RasterTileMutation(key: firstKey, replacement: finalFirstTile)
            ],
            artboardID: artboardID,
            expectedGeneration: 0
        )

        let tileCount = await store.tileCount()
        let storedFirstTile = await store.tile(at: firstKey)
        #expect(commit.generation == 1)
        #expect(commit.deltas.count == 2)
        #expect(tileCount == 2)
        #expect(storedFirstTile == finalFirstTile)
        #expect(commit.deltas.allSatisfy { $0.before == .absent })
    }

    @Test
    func transparentTilesRemainSparseAndNoOpDoesNotAdvanceGeneration() async throws {
        let store = RasterTileStore()
        let key = RasterTileKey(layerID: UUID(), x: 12, y: 8)

        let commit = try await store.setTile(
            .transparent,
            at: key,
            artboardID: UUID()
        )

        let tileCount = await store.tileCount()
        #expect(commit.generation == 0)
        #expect(commit.deltas.isEmpty)
        #expect(tileCount == 0)
    }

    @Test
    func deltasRoundTripForwardAndBackward() async throws {
        let store = RasterTileStore()
        let artboardID = UUID()
        let key = RasterTileKey(layerID: UUID(), x: 0, y: 0)
        let original = try tile(red: 42)
        let replacement = try tile(red: 99)

        _ = try await store.setTile(
            original,
            at: key,
            artboardID: artboardID
        )
        let commit = try await store.setTile(
            replacement,
            at: key,
            artboardID: artboardID
        )
        #expect(commit.generation == 2)

        let undoGeneration = try await store.apply(
            deltas: commit.deltas,
            direction: .backward,
            expectedGeneration: 2
        )
        let tileAfterUndo = await store.tile(at: key)
        #expect(undoGeneration == 3)
        #expect(tileAfterUndo == original)

        let redoGeneration = try await store.apply(
            deltas: commit.deltas,
            direction: .forward,
            expectedGeneration: 3
        )
        let tileAfterRedo = await store.tile(at: key)
        #expect(redoGeneration == 4)
        #expect(tileAfterRedo == replacement)
    }

    @Test
    func deltaRefusesToOverwriteUnexpectedCurrentState() async throws {
        let store = RasterTileStore()
        let artboardID = UUID()
        let key = RasterTileKey(layerID: UUID(), x: 0, y: 0)
        let first = try tile(red: 1)
        let second = try tile(red: 2)
        let third = try tile(red: 3)

        _ = try await store.setTile(first, at: key, artboardID: artboardID)
        let commit = try await store.setTile(
            second,
            at: key,
            artboardID: artboardID
        )
        _ = try await store.setTile(third, at: key, artboardID: artboardID)

        await #expect(
            throws: RasterTileStoreError.deltaDoesNotMatchCurrentState(key: key)
        ) {
            _ = try await store.apply(
                deltas: commit.deltas,
                direction: .backward
            )
        }
    }

    @Test
    func snapshotCannotObserveSubsequentWrites() async throws {
        let store = RasterTileStore()
        let artboardID = UUID()
        let key = RasterTileKey(layerID: UUID(), x: 0, y: 0)
        let first = try tile(red: 15)
        let second = try tile(red: 25)

        _ = try await store.setTile(first, at: key, artboardID: artboardID)
        let snapshot = await store.snapshot()
        _ = try await store.setTile(second, at: key, artboardID: artboardID)

        let generation = await store.currentGeneration()
        let storedTile = await store.tile(at: key)
        #expect(snapshot.generation == 1)
        #expect(snapshot[key] == first)
        #expect(generation == 2)
        #expect(storedTile == second)
    }

    @Test
    func dirtySetIsDeterministicAndConsumable() async throws {
        let store = RasterTileStore()
        let artboardID = UUID()
        let layerID = UUID()
        let later = RasterTileKey(layerID: layerID, x: 2, y: 1)
        let earlier = RasterTileKey(layerID: layerID, x: 1, y: 0)

        _ = try await store.apply(
            [
                RasterTileMutation(key: later, replacement: try tile(red: 1)),
                RasterTileMutation(key: earlier, replacement: try tile(red: 2))
            ],
            artboardID: artboardID
        )

        let consumed = await store.consumeDirtyTiles()
        let remaining = await store.dirtyTiles()
        #expect(consumed.generation == 1)
        #expect(consumed.keys == [earlier, later])
        #expect(remaining.keys.isEmpty)
    }

    private func assertLocation(
        layerID: UUID,
        pixel: Int,
        tile: Int,
        local: Int
    ) {
        let location = RasterTileKey.containing(
            layerID: layerID,
            pixelX: pixel,
            pixelY: pixel
        )
        #expect(location.key.coordinate.x == tile)
        #expect(location.key.coordinate.y == tile)
        #expect(location.localX == local)
        #expect(location.localY == local)
    }

    private func tile(red: UInt8) throws -> RasterTile {
        var bytes = Data(repeating: 0, count: RasterTile.byteCount)
        bytes[0] = red
        bytes[3] = 255
        return try RasterTile(bytes: bytes)
    }
}
