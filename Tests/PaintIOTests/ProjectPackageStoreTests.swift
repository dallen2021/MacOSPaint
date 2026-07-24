import Foundation
import PaintEngine
import PaintModel
import Testing
@testable import PaintIO

struct ProjectPackageStoreTests {
    @Test
    func packageRoundTripPersistsManifestAndDeduplicatedTiles() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let packageURL = temporaryDirectory.appendingPathComponent(
            "RoundTrip.macospaint",
            isDirectory: true
        )
        let fixture = try makeFixture(twoIdenticalTiles: true)
        let store = ProjectPackageStore()

        let saved = try await store.save(fixture.contents, to: packageURL)
        let loaded = try await store.load(at: packageURL)

        #expect(loaded.manifest == saved.manifest)
        #expect(loaded.rasterTiles.generation == 0)
        #expect(loaded.rasterTiles.tiles == fixture.contents.rasterTiles.tiles)

        let raster = try #require(rasterContent(in: loaded.manifest))
        #expect(raster.tileReferences.count == 2)
        #expect(Set(raster.tileReferences.map(\.relativePath)).count == 1)

        let blobURLs = try FileManager.default.contentsOfDirectory(
            at: packageURL.appendingPathComponent("tiles"),
            includingPropertiesForKeys: nil
        )
        #expect(blobURLs.count == 1)
        #expect(
            FileManager.default.fileExists(
                atPath: packageURL
                    .appendingPathComponent("manifest.json")
                    .path
            )
        )
    }

    @Test
    func fileWrapperRoundTripIncludesEveryReferencedRasterBlob() throws {
        let fixture = try makeFixture(twoIdenticalTiles: true)

        let wrapper = try ProjectPackageStore.fileWrapper(
            for: fixture.contents
        )
        let tileDirectory = try #require(
            wrapper.fileWrappers?["tiles"]
        )
        #expect(tileDirectory.isDirectory)
        #expect(tileDirectory.fileWrappers?.count == 1)

        let loaded = try ProjectPackageStore.load(from: wrapper)
        let raster = try #require(rasterContent(in: loaded.manifest))
        #expect(raster.tileReferences.count == 2)
        #expect(
            raster.tileReferences.allSatisfy { reference in
                let filename = String(
                    reference.relativePath.split(separator: "/").last ?? ""
                )
                return tileDirectory.fileWrappers?[filename]?
                    .regularFileContents != nil
            }
        )
        #expect(
            loaded.rasterTiles.tiles
                == fixture.contents.rasterTiles.tiles
        )
        #expect(
            loaded.manifest.workspace
                == fixture.contents.manifest.workspace
        )
    }

    @Test
    func nonemptyMaskReferencesAreRejectedInsteadOfBeingDropped() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let packageURL = temporaryDirectory.appendingPathComponent(
            "UnsupportedMask.macospaint",
            isDirectory: true
        )
        let fixture = try makeFixture()
        var manifest = fixture.contents.manifest
        let maskReference = RasterTileReference(
            coordinate: TileCoordinate(x: 0, y: 0),
            relativePath: "masks/mask.tile",
            byteCount: RasterTile.byteCount
        )
        manifest.artboards[0].layers[0].mask = LayerMaskRecord(
            tileReferences: [maskReference]
        )
        let contents = ProjectPackageContents(
            manifest: manifest,
            rasterTiles: fixture.contents.rasterTiles
        )
        let expected = ProjectPackageError.unsupportedMaskTiles(
            layerID: fixture.layerID
        )

        #expect(throws: expected) {
            _ = try ProjectPackageStore.fileWrapper(for: contents)
        }

        let store = ProjectPackageStore()
        await #expect(throws: expected) {
            _ = try await store.save(contents, to: packageURL)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        let packageWrapper = FileWrapper(
            directoryWithFileWrappers: [
                ProjectPackageStore.manifestFilename: FileWrapper(
                    regularFileWithContents: manifestData
                ),
                "tiles": FileWrapper(directoryWithFileWrappers: [:]),
                "masks": FileWrapper(
                    directoryWithFileWrappers: [
                        "mask.tile": FileWrapper(
                            regularFileWithContents: Data(
                                repeating: 0,
                                count: RasterTile.byteCount
                            )
                        )
                    ]
                ),
            ]
        )
        #expect(throws: expected) {
            _ = try ProjectPackageStore.load(from: packageWrapper)
        }
        try packageWrapper.write(
            to: packageURL,
            options: .atomic,
            originalContentsURL: nil
        )
        await #expect(throws: expected) {
            _ = try await store.load(at: packageURL)
        }
    }

    @Test
    func edgeTileReferenceRecordsItsValidPixelExtent() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let packageURL = temporaryDirectory.appendingPathComponent(
            "Edge.macospaint",
            isDirectory: true
        )
        let fixture = try makeFixture(
            twoIdenticalTiles: true,
            pixelWidth: 300,
            pixelHeight: 257
        )
        let store = ProjectPackageStore()

        let saved = try await store.save(fixture.contents, to: packageURL)
        let raster = try #require(rasterContent(in: saved.manifest))
        let edge = try #require(
            raster.tileReferences.first { $0.coordinate.x == 1 }
        )
        #expect(edge.pixelWidth == 44)
        #expect(edge.pixelHeight == 256)

        let loaded = try await store.load(at: packageURL)
        #expect(loaded.rasterTiles.tiles == fixture.contents.rasterTiles.tiles)
    }

    @Test
    func corruptTileIsReportedWithoutMutatingPackage() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let packageURL = temporaryDirectory.appendingPathComponent(
            "Corrupt.macospaint",
            isDirectory: true
        )
        let fixture = try makeFixture()
        let store = ProjectPackageStore()
        let saved = try await store.save(fixture.contents, to: packageURL)
        let reference = try #require(
            rasterContent(in: saved.manifest)?.tileReferences.first
        )
        let tileURL = packageURL.appendingPathComponent(reference.relativePath)
        try Data([1, 2, 3]).write(to: tileURL)

        await #expect(
            throws: ProjectPackageError.corruptTileBlob(
                reference.relativePath
            )
        ) {
            _ = try await store.load(at: packageURL)
        }
        #expect(
            (try Data(contentsOf: tileURL)) == Data([1, 2, 3])
        )
    }

    @Test
    func missingTileIsARecoverableCorruptionError() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let packageURL = temporaryDirectory.appendingPathComponent(
            "Missing.macospaint",
            isDirectory: true
        )
        let fixture = try makeFixture()
        let store = ProjectPackageStore()
        let saved = try await store.save(fixture.contents, to: packageURL)
        let reference = try #require(
            rasterContent(in: saved.manifest)?.tileReferences.first
        )
        try FileManager.default.removeItem(
            at: packageURL.appendingPathComponent(reference.relativePath)
        )

        await #expect(
            throws: ProjectPackageError.missingTileBlob(
                reference.relativePath
            )
        ) {
            _ = try await store.load(at: packageURL)
        }
    }

    @Test
    func tileSymlinkCannotEscapePackage() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let packageURL = temporaryDirectory.appendingPathComponent(
            "Symlink.macospaint",
            isDirectory: true
        )
        let fixture = try makeFixture()
        let store = ProjectPackageStore()
        let saved = try await store.save(fixture.contents, to: packageURL)
        let reference = try #require(
            rasterContent(in: saved.manifest)?.tileReferences.first
        )
        let tileURL = packageURL.appendingPathComponent(reference.relativePath)
        let externalURL = temporaryDirectory.appendingPathComponent("outside.tile")
        let bytes = try #require(
            fixture.contents.rasterTiles.tiles.values.first?.bytes
        )
        try bytes.write(to: externalURL)
        try FileManager.default.removeItem(at: tileURL)
        try FileManager.default.createSymbolicLink(
            at: tileURL,
            withDestinationURL: externalURL
        )

        await #expect(
            throws: ProjectPackageError.unsafeTilePath(
                reference.relativePath
            )
        ) {
            _ = try await store.load(at: packageURL)
        }
    }

    @Test
    func futureSchemaOpensAsReadOnlyAndEditableLoadRefusesIt() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let packageURL = temporaryDirectory.appendingPathComponent(
            "Future.macospaint",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: packageURL,
            withIntermediateDirectories: false
        )
        let futureVersion = ProjectManifestV1.currentSchemaVersion + 7
        let raw = Data(
            """
            {
              "schemaVersion": \(futureVersion),
              "futureData": {"must": "be preserved"}
            }
            """.utf8
        )
        try raw.write(
            to: packageURL.appendingPathComponent("manifest.json")
        )
        let store = ProjectPackageStore()

        let result = try await store.open(at: packageURL)
        switch result {
        case .editable:
            Issue.record("A future schema must not open for editing")
        case let .readOnly(package):
            #expect(package.schemaVersion == futureVersion)
            #expect(package.rawManifest == raw)
        }

        await #expect(
            throws: ProjectPackageError.newerSchemaIsReadOnly(
                found: futureVersion,
                supported: ProjectManifestV1.currentSchemaVersion
            )
        ) {
            _ = try await store.load(at: packageURL)
        }
    }

    @Test
    func interruptedSiblingWriteLeavesExistingPackageIntact() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let packageURL = temporaryDirectory.appendingPathComponent(
            "Atomic.macospaint",
            isDirectory: true
        )
        let original = try makeFixture(red: 17)
        let replacement = try makeFixture(
            layerID: original.layerID,
            artboardID: original.artboardID,
            red: 222
        )
        let normalStore = ProjectPackageStore()
        _ = try await normalStore.save(original.contents, to: packageURL)

        let failingStore = ProjectPackageStore { phase in
            if case .beforeAtomicCommit = phase {
                throw ProjectPackageError.writeInterrupted
            }
        }
        await #expect(throws: ProjectPackageError.writeInterrupted) {
            _ = try await failingStore.save(
                replacement.contents,
                to: packageURL
            )
        }

        let loaded = try await normalStore.load(at: packageURL)
        let key = RasterTileKey(
            layerID: original.layerID,
            coordinate: TileCoordinate(x: 0, y: 0)
        )
        #expect(loaded.rasterTiles[key]?.bytes[0] == 17)

        let siblingNames = try FileManager.default.contentsOfDirectory(
            atPath: temporaryDirectory.path
        )
        #expect(
            !siblingNames.contains {
                $0.hasPrefix(".Atomic.macospaint.save-")
            }
        )
    }

    @Test
    func successfulSecondSaveAtomicallyReplacesExistingPackage() async throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let packageURL = temporaryDirectory.appendingPathComponent(
            "Replace.macospaint",
            isDirectory: true
        )
        let original = try makeFixture(red: 10)
        let replacement = try makeFixture(
            layerID: original.layerID,
            artboardID: original.artboardID,
            red: 90
        )
        let store = ProjectPackageStore()

        _ = try await store.save(original.contents, to: packageURL)
        _ = try await store.save(replacement.contents, to: packageURL)
        let loaded = try await store.load(at: packageURL)
        let key = RasterTileKey(
            layerID: original.layerID,
            coordinate: TileCoordinate(x: 0, y: 0)
        )
        #expect(loaded.rasterTiles[key]?.bytes[0] == 90)
    }

    private struct Fixture {
        let contents: ProjectPackageContents
        let artboardID: UUID
        let layerID: UUID
    }

    private func makeFixture(
        layerID: UUID = UUID(),
        artboardID: UUID = UUID(),
        red: UInt8 = 80,
        twoIdenticalTiles: Bool = false,
        pixelWidth: Int = 512,
        pixelHeight: Int = 512
    ) throws -> Fixture {
        let layer = LayerRecord(
            id: layerID,
            name: "Paint",
            kind: .raster(RasterLayerContent())
        )
        let artboard = ArtboardRecord(
            id: artboardID,
            name: "Artboard 1",
            frame: CanvasRect(
                x: 0,
                y: 0,
                width: Double(pixelWidth),
                height: Double(pixelHeight)
            ),
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            dpi: 72,
            rootLayerIDs: [layerID],
            layers: [layer]
        )
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let manifest = ProjectManifestV1(
            projectID: UUID(),
            title: "Fixture",
            createdAt: timestamp,
            modifiedAt: timestamp,
            artboards: [artboard]
        )
        var bytes = Data(repeating: 0, count: RasterTile.byteCount)
        bytes[0] = red
        bytes[3] = 255
        let tile = try RasterTile(bytes: bytes)
        var tiles = [
            RasterTileKey(layerID: layerID, x: 0, y: 0): tile
        ]
        if twoIdenticalTiles {
            tiles[RasterTileKey(layerID: layerID, x: 1, y: 0)] = tile
        }
        return Fixture(
            contents: ProjectPackageContents(
                manifest: manifest,
                rasterTiles: RasterTileSnapshot(
                    generation: 4,
                    tiles: tiles
                )
            ),
            artboardID: artboardID,
            layerID: layerID
        )
    }

    private func rasterContent(
        in manifest: ProjectManifestV1
    ) -> RasterLayerContent? {
        guard let layer = manifest.artboards.first?.layers.first,
              case let .raster(content) = layer.kind
        else {
            return nil
        }
        return content
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MacOSPaint-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: false
        )
        return url
    }
}
