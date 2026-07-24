import CryptoKit
import Darwin
import Foundation
import PaintEngine
import PaintModel

public struct ProjectPackageContents: Equatable, Sendable {
    public let manifest: ProjectManifestV1
    public let rasterTiles: RasterTileSnapshot

    public init(
        manifest: ProjectManifestV1,
        rasterTiles: RasterTileSnapshot
    ) {
        self.manifest = manifest
        self.rasterTiles = rasterTiles
    }
}

public struct ReadOnlyProjectPackage: Equatable, Sendable {
    public let url: URL
    public let schemaVersion: Int
    public let rawManifest: Data

    public init(url: URL, schemaVersion: Int, rawManifest: Data) {
        self.url = url
        self.schemaVersion = schemaVersion
        self.rawManifest = rawManifest
    }
}

public enum ProjectPackageOpenResult: Equatable, Sendable {
    case editable(ProjectPackageContents)
    /// The manifest can be inspected or copied, but this version must never be
    /// decoded and saved by a writer that does not understand its schema.
    case readOnly(ReadOnlyProjectPackage)
}

public enum ProjectPackageError: Error, Equatable, Sendable {
    case packageDoesNotExist
    case packageIsNotDirectory
    case missingManifest
    case invalidManifest(reason: String)
    case unsupportedOlderSchema(found: Int, supported: Int)
    case newerSchemaIsReadOnly(found: Int, supported: Int)
    case invalidTileReference(layerID: UUID, coordinate: TileCoordinate)
    case unsafeTilePath(String)
    case duplicateTileCoordinate(layerID: UUID, coordinate: TileCoordinate)
    case missingTileBlob(String)
    case corruptTileBlob(String)
    case unsupportedMaskTiles(layerID: UUID)
    case orphanTile(layerID: UUID)
    case destinationParentDoesNotExist
    case destinationIsNotPackageDirectory
    case atomicCommitFailed
    case writeInterrupted
}

extension ProjectPackageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .packageDoesNotExist:
            "The project package does not exist."
        case .packageIsNotDirectory:
            "The project URL is not a package directory."
        case .missingManifest:
            "The project package has no manifest.json."
        case let .invalidManifest(reason):
            "The project manifest is invalid: \(reason)"
        case let .unsupportedOlderSchema(found, supported):
            "Schema \(found) is older than supported schema \(supported)."
        case let .newerSchemaIsReadOnly(found, supported):
            "Schema \(found) is newer than supported schema \(supported) and can only be inspected read-only."
        case let .invalidTileReference(layerID, coordinate):
            "Layer \(layerID) has an invalid tile reference at \(coordinate.x),\(coordinate.y)."
        case let .unsafeTilePath(path):
            "The tile path is not package-relative: \(path)"
        case let .duplicateTileCoordinate(layerID, coordinate):
            "Layer \(layerID) references tile \(coordinate.x),\(coordinate.y) more than once."
        case let .missingTileBlob(path):
            "The project is missing tile blob \(path)."
        case let .corruptTileBlob(path):
            "Tile blob \(path) is corrupt."
        case let .unsupportedMaskTiles(layerID):
            "Layer \(layerID) contains mask pixels, which this project-format implementation cannot save or open yet."
        case let .orphanTile(layerID):
            "Raster data references unknown or non-raster layer \(layerID)."
        case .destinationParentDoesNotExist:
            "The destination folder does not exist."
        case .destinationIsNotPackageDirectory:
            "The destination exists but is not a package directory."
        case .atomicCommitFailed:
            "The completed package could not be committed atomically."
        case .writeInterrupted:
            "The package write was interrupted before commit."
        }
    }
}

/// Versioned `.macospaint` directory-package persistence.
///
/// The actor serializes saves. Every save is constructed as a complete sibling
/// package and only then atomically replaces the destination.
public actor ProjectPackageStore {
    public static let manifestFilename = "manifest.json"
    public static let supportedSchemaVersion =
        ProjectManifestV1.currentSchemaVersion

    private let fileManager: FileManager
    private let writeHook: (@Sendable (PackageWritePhase) throws -> Void)?

    public init() {
        fileManager = .default
        writeHook = nil
    }

    init(
        fileManager: FileManager = .default,
        writeHook: (@Sendable (PackageWritePhase) throws -> Void)?
    ) {
        self.fileManager = fileManager
        self.writeHook = writeHook
    }

    /// Builds a complete Finder package for the synchronous `NSDocument`
    /// `FileWrapper` path. Raster references and their content-addressed blobs
    /// are generated from the same immutable snapshot used by atomic saves.
    public static func fileWrapper(
        for contents: ProjectPackageContents
    ) throws -> FileWrapper {
        let package = try prepareForWriting(contents)
        var tileWrappers: [String: FileWrapper] = [:]

        for (relativePath, bytes) in package.blobs {
            let components = try safeRelativePathComponents(relativePath)
            guard components.count == 2, components[0] == "tiles" else {
                throw ProjectPackageError.unsafeTilePath(relativePath)
            }
            tileWrappers[components[1]] = FileWrapper(
                regularFileWithContents: bytes
            )
        }

        return FileWrapper(
            directoryWithFileWrappers: [
                manifestFilename: FileWrapper(
                    regularFileWithContents: package.manifestData
                ),
                "tiles": FileWrapper(
                    directoryWithFileWrappers: tileWrappers
                ),
                "masks": FileWrapper(directoryWithFileWrappers: [:]),
                "resources": FileWrapper(directoryWithFileWrappers: [:]),
                "previews": FileWrapper(directoryWithFileWrappers: [:]),
            ]
        )
    }

    /// Reads a current-schema package from the synchronous `NSDocument`
    /// `FileWrapper` path without dropping referenced raster blobs.
    public static func load(
        from fileWrapper: FileWrapper
    ) throws -> ProjectPackageContents {
        guard fileWrapper.isDirectory else {
            throw ProjectPackageError.packageIsNotDirectory
        }
        guard
            let manifestData = fileWrapper.fileWrappers?[manifestFilename]?
                .regularFileContents
        else {
            throw ProjectPackageError.missingManifest
        }

        let manifest = try editableManifest(from: manifestData)
        let snapshot = try loadTiles(manifest: manifest) { relativePath in
            try blobData(
                at: relativePath,
                in: fileWrapper
            )
        }
        return ProjectPackageContents(
            manifest: manifest,
            rasterTiles: snapshot
        )
    }

    public func open(at packageURL: URL) throws -> ProjectPackageOpenResult {
        let manifestData = try readManifestData(at: packageURL)
        let schemaVersion = try Self.schemaVersion(in: manifestData)

        if schemaVersion > Self.supportedSchemaVersion {
            return .readOnly(
                ReadOnlyProjectPackage(
                    url: packageURL,
                    schemaVersion: schemaVersion,
                    rawManifest: manifestData
                )
            )
        }
        if schemaVersion < Self.supportedSchemaVersion {
            throw ProjectPackageError.unsupportedOlderSchema(
                found: schemaVersion,
                supported: Self.supportedSchemaVersion
            )
        }

        let manifest = try Self.editableManifest(from: manifestData)

        let snapshot = try loadTiles(
            from: packageURL,
            manifest: manifest
        )
        return .editable(
            ProjectPackageContents(
                manifest: manifest,
                rasterTiles: snapshot
            )
        )
    }

    public func load(at packageURL: URL) throws -> ProjectPackageContents {
        switch try open(at: packageURL) {
        case let .editable(contents):
            contents
        case let .readOnly(package):
            throw ProjectPackageError.newerSchemaIsReadOnly(
                found: package.schemaVersion,
                supported: Self.supportedSchemaVersion
            )
        }
    }

    /// Saves one immutable generation. The returned contents include the
    /// content-addressed tile references written into `manifest.json`.
    @discardableResult
    public func save(
        _ contents: ProjectPackageContents,
        to destinationURL: URL
    ) throws -> ProjectPackageContents {
        let package = try Self.prepareForWriting(contents)

        let parentURL = destinationURL.deletingLastPathComponent()
        var isParentDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: parentURL.path,
            isDirectory: &isParentDirectory
        ), isParentDirectory.boolValue else {
            throw ProjectPackageError.destinationParentDoesNotExist
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(
                atPath: destinationURL.path,
                isDirectory: &isDirectory
            ), isDirectory.boolValue else {
                throw ProjectPackageError.destinationIsNotPackageDirectory
            }
        }

        let temporaryURL = parentURL.appendingPathComponent(
            ".\(destinationURL.lastPathComponent).save-\(UUID().uuidString)",
            isDirectory: true
        )
        var shouldRemoveTemporary = true
        defer {
            if shouldRemoveTemporary {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }

        do {
            try createPackageSkeleton(at: temporaryURL)
            try writeHook?(.temporaryPackageCreated)

            for (relativePath, bytes) in package.blobs.sorted(by: {
                $0.key < $1.key
            }) {
                let url = temporaryURL.appendingPathComponent(relativePath)
                try bytes.write(to: url, options: .withoutOverwriting)
                try Self.synchronizeFile(at: url)
            }
            try Self.synchronizeDirectory(
                at: temporaryURL.appendingPathComponent(
                    "tiles",
                    isDirectory: true
                )
            )
            try writeHook?(.tileBlobsWritten)

            let manifestURL = temporaryURL.appendingPathComponent(
                Self.manifestFilename
            )
            try package.manifestData.write(
                to: manifestURL,
                options: .withoutOverwriting
            )
            try Self.synchronizeFile(at: manifestURL)
            try Self.synchronizeDirectory(at: temporaryURL)
            try writeHook?(.beforeAtomicCommit)

            if fileManager.fileExists(atPath: destinationURL.path) {
                do {
                    _ = try fileManager.replaceItemAt(
                        destinationURL,
                        withItemAt: temporaryURL,
                        backupItemName: nil,
                        options: []
                    )
                } catch {
                    throw ProjectPackageError.atomicCommitFailed
                }
            } else {
                do {
                    try fileManager.moveItem(
                        at: temporaryURL,
                        to: destinationURL
                    )
                } catch {
                    throw ProjectPackageError.atomicCommitFailed
                }
            }
            shouldRemoveTemporary = false
            try? Self.synchronizeDirectory(at: parentURL)
        } catch let error as ProjectPackageError {
            throw error
        } catch {
            throw ProjectPackageError.writeInterrupted
        }

        return ProjectPackageContents(
            manifest: package.manifest,
            rasterTiles: contents.rasterTiles
        )
    }

    private func readManifestData(at packageURL: URL) throws -> Data {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(
            atPath: packageURL.path,
            isDirectory: &isDirectory
        ) else {
            throw ProjectPackageError.packageDoesNotExist
        }
        guard isDirectory.boolValue else {
            throw ProjectPackageError.packageIsNotDirectory
        }

        let manifestURL = packageURL.appendingPathComponent(
            Self.manifestFilename
        )
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ProjectPackageError.missingManifest
        }
        do {
            return try Data(contentsOf: manifestURL, options: .mappedIfSafe)
        } catch {
            throw ProjectPackageError.missingManifest
        }
    }

    private func loadTiles(
        from packageURL: URL,
        manifest: ProjectManifestV1
    ) throws -> RasterTileSnapshot {
        try Self.loadTiles(manifest: manifest) { relativePath in
            let tileURL = try Self.safePackageURL(
                relativePath: relativePath,
                packageURL: packageURL
            )
            guard fileManager.fileExists(atPath: tileURL.path) else {
                throw ProjectPackageError.missingTileBlob(relativePath)
            }
            do {
                return try Data(
                    contentsOf: tileURL,
                    options: .mappedIfSafe
                )
            } catch {
                throw ProjectPackageError.corruptTileBlob(relativePath)
            }
        }
    }

    private static func loadTiles(
        manifest: ProjectManifestV1,
        readBlob: (String) throws -> Data
    ) throws -> RasterTileSnapshot {
        try rejectUnsupportedMaskTiles(in: manifest)
        var tiles: [RasterTileKey: RasterTile] = [:]

        for artboard in manifest.artboards {
            for layer in artboard.layers {
                guard case let .raster(content) = layer.kind else {
                    continue
                }
                guard content.tileSize == RasterTileStore.tileSize else {
                    let coordinate =
                        content.tileReferences.first?.coordinate
                        ?? TileCoordinate(x: 0, y: 0)
                    throw ProjectPackageError.invalidTileReference(
                        layerID: layer.id,
                        coordinate: coordinate
                    )
                }
                for reference in content.tileReferences {
                    let key = RasterTileKey(
                        layerID: layer.id,
                        coordinate: reference.coordinate
                    )
                    guard tiles[key] == nil else {
                        throw ProjectPackageError.duplicateTileCoordinate(
                            layerID: layer.id,
                            coordinate: reference.coordinate
                        )
                    }
                    guard (1...RasterTileStore.tileSize).contains(
                        reference.pixelWidth
                    ),
                    (1...RasterTileStore.tileSize).contains(
                        reference.pixelHeight
                    )
                    else {
                        throw ProjectPackageError.invalidTileReference(
                            layerID: layer.id,
                            coordinate: reference.coordinate
                        )
                    }

                    let data: Data
                    do {
                        data = try readBlob(reference.relativePath)
                    } catch let error as ProjectPackageError {
                        throw error
                    } catch {
                        throw ProjectPackageError.corruptTileBlob(
                            reference.relativePath
                        )
                    }
                    if let expectedByteCount = reference.byteCount,
                       expectedByteCount != data.count
                    {
                        throw ProjectPackageError.corruptTileBlob(
                            reference.relativePath
                        )
                    }
                    if let expectedChecksum = reference.checksum {
                        let normalized = expectedChecksum
                            .replacingOccurrences(of: "sha256:", with: "")
                            .lowercased()
                        guard normalized == Self.sha256(data) else {
                            throw ProjectPackageError.corruptTileBlob(
                                reference.relativePath
                            )
                        }
                    }
                    do {
                        tiles[key] = try RasterTile(bytes: data)
                    } catch {
                        throw ProjectPackageError.corruptTileBlob(
                            reference.relativePath
                        )
                    }
                }
            }
        }
        return RasterTileSnapshot(generation: 0, tiles: tiles)
    }

    private func createPackageSkeleton(at url: URL) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: false
        )
        for directory in ["tiles", "masks", "resources", "previews"] {
            try fileManager.createDirectory(
                at: url.appendingPathComponent(directory, isDirectory: true),
                withIntermediateDirectories: false
            )
        }
    }

    private static func schemaVersion(in data: Data) throws -> Int {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ProjectPackageError.invalidManifest(
                reason: "manifest.json is not valid JSON"
            )
        }
        guard let dictionary = object as? [String: Any],
              let version = dictionary["schemaVersion"] as? Int,
              version > 0
        else {
            throw ProjectPackageError.invalidManifest(
                reason: "schemaVersion is missing or invalid"
            )
        }
        return version
    }

    private struct PreparedPackage {
        var manifest: ProjectManifestV1
        var manifestData: Data
        var blobs: [String: Data]
    }

    private struct BlobPlan {
        var blobs: [String: Data]
    }

    private static func editableManifest(
        from data: Data
    ) throws -> ProjectManifestV1 {
        let version = try schemaVersion(in: data)
        guard version == supportedSchemaVersion else {
            if version > supportedSchemaVersion {
                throw ProjectPackageError.newerSchemaIsReadOnly(
                    found: version,
                    supported: supportedSchemaVersion
                )
            }
            throw ProjectPackageError.unsupportedOlderSchema(
                found: version,
                supported: supportedSchemaVersion
            )
        }

        let manifest: ProjectManifestV1
        do {
            manifest = try makeDecoder().decode(
                ProjectManifestV1.self,
                from: data
            )
            try manifest.validate()
        } catch let error as ProjectPackageError {
            throw error
        } catch {
            throw ProjectPackageError.invalidManifest(
                reason: String(describing: error)
            )
        }
        try rejectUnsupportedMaskTiles(in: manifest)
        return manifest
    }

    private static func prepareForWriting(
        _ contents: ProjectPackageContents
    ) throws -> PreparedPackage {
        var manifest = contents.manifest
        guard manifest.schemaVersion == supportedSchemaVersion else {
            if manifest.schemaVersion > supportedSchemaVersion {
                throw ProjectPackageError.newerSchemaIsReadOnly(
                    found: manifest.schemaVersion,
                    supported: supportedSchemaVersion
                )
            }
            throw ProjectPackageError.unsupportedOlderSchema(
                found: manifest.schemaVersion,
                supported: supportedSchemaVersion
            )
        }

        do {
            try manifest.validate()
        } catch {
            throw ProjectPackageError.invalidManifest(
                reason: String(describing: error)
            )
        }
        try rejectUnsupportedMaskTiles(in: manifest)

        let blobPlan = try populateTileReferences(
            in: &manifest,
            from: contents.rasterTiles
        )
        do {
            try manifest.validate()
        } catch {
            throw ProjectPackageError.invalidManifest(
                reason: String(describing: error)
            )
        }

        let manifestData: Data
        do {
            manifestData = try makeEncoder().encode(manifest)
        } catch {
            throw ProjectPackageError.invalidManifest(
                reason: String(describing: error)
            )
        }
        return PreparedPackage(
            manifest: manifest,
            manifestData: manifestData,
            blobs: blobPlan.blobs
        )
    }

    private static func rejectUnsupportedMaskTiles(
        in manifest: ProjectManifestV1
    ) throws {
        for artboard in manifest.artboards {
            for layer in artboard.layers
            where layer.mask?.tileReferences.isEmpty == false {
                throw ProjectPackageError.unsupportedMaskTiles(
                    layerID: layer.id
                )
            }
        }
    }

    private static func populateTileReferences(
        in manifest: inout ProjectManifestV1,
        from snapshot: RasterTileSnapshot
    ) throws -> BlobPlan {
        var rasterLayerIDs: Set<UUID> = []
        for artboard in manifest.artboards {
            for layer in artboard.layers {
                if case .raster = layer.kind {
                    rasterLayerIDs.insert(layer.id)
                }
            }
        }

        for key in snapshot.tiles.keys where !rasterLayerIDs.contains(key.layerID) {
            throw ProjectPackageError.orphanTile(layerID: key.layerID)
        }

        var blobs: [String: Data] = [:]
        let grouped = Dictionary(grouping: snapshot.orderedKeys, by: \.layerID)
        for artboardIndex in manifest.artboards.indices {
            for layerIndex in manifest.artboards[artboardIndex].layers.indices {
                var layer =
                    manifest.artboards[artboardIndex].layers[layerIndex]
                guard case var .raster(content) = layer.kind else {
                    continue
                }
                var references: [RasterTileReference] = []
                for key in grouped[layer.id, default: []] {
                    guard let tile = snapshot.tiles[key] else {
                        continue
                    }
                    let checksum = sha256(tile.bytes)
                    let relativePath = "tiles/\(checksum).tile"
                    blobs[relativePath] = tile.bytes
                    let artboard = manifest.artboards[artboardIndex]
                    let maximumX =
                        max(0, (artboard.pixelWidth - 1) / RasterTileStore.tileSize)
                    let maximumY =
                        max(0, (artboard.pixelHeight - 1) / RasterTileStore.tileSize)
                    guard (0...maximumX).contains(key.coordinate.x),
                          (0...maximumY).contains(key.coordinate.y)
                    else {
                        throw ProjectPackageError.invalidTileReference(
                            layerID: layer.id,
                            coordinate: key.coordinate
                        )
                    }
                    let pixelWidth = min(
                        RasterTileStore.tileSize,
                        artboard.pixelWidth
                            - key.coordinate.x * RasterTileStore.tileSize
                    )
                    let pixelHeight = min(
                        RasterTileStore.tileSize,
                        artboard.pixelHeight
                            - key.coordinate.y * RasterTileStore.tileSize
                    )
                    guard pixelWidth > 0, pixelHeight > 0 else {
                        throw ProjectPackageError.invalidTileReference(
                            layerID: layer.id,
                            coordinate: key.coordinate
                        )
                    }
                    references.append(
                        RasterTileReference(
                            coordinate: key.coordinate,
                            relativePath: relativePath,
                            pixelWidth: pixelWidth,
                            pixelHeight: pixelHeight,
                            byteCount: tile.bytes.count,
                            checksum: "sha256:\(checksum)"
                        )
                    )
                }
                content.tileSize = RasterTileStore.tileSize
                content.tileReferences = references
                layer.kind = .raster(content)
                manifest.artboards[artboardIndex].layers[layerIndex] = layer
            }
        }
        return BlobPlan(blobs: blobs)
    }

    private static func blobData(
        at relativePath: String,
        in package: FileWrapper
    ) throws -> Data {
        let components = try safeRelativePathComponents(relativePath)
        var current = package
        for component in components {
            guard
                current.isDirectory,
                let child = current.fileWrappers?[component]
            else {
                throw ProjectPackageError.missingTileBlob(relativePath)
            }
            current = child
        }
        guard current.isRegularFile,
              let data = current.regularFileContents
        else {
            throw ProjectPackageError.corruptTileBlob(relativePath)
        }
        return data
    }

    private static func safePackageURL(
        relativePath: String,
        packageURL: URL
    ) throws -> URL {
        _ = try safeRelativePathComponents(relativePath)

        let root = packageURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        let candidate = packageURL
            .appendingPathComponent(relativePath)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard candidate.path.hasPrefix(root + "/") else {
            throw ProjectPackageError.unsafeTilePath(relativePath)
        }
        return candidate
    }

    private static func safeRelativePathComponents(
        _ relativePath: String
    ) throws -> [String] {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.hasPrefix("\\"),
              !relativePath.hasPrefix("~"),
              !relativePath.contains("\\")
        else {
            throw ProjectPackageError.unsafeTilePath(relativePath)
        }
        let components = relativePath.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map(String.init)
        guard components.allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".."
        }) else {
            throw ProjectPackageError.unsafeTilePath(relativePath)
        }
        return components
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func synchronizeFile(at url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    private static func synchronizeDirectory(at url: URL) throws {
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else {
            throw ProjectPackageError.writeInterrupted
        }
        defer { Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else {
            throw ProjectPackageError.writeInterrupted
        }
    }
}

enum PackageWritePhase: Sendable {
    case temporaryPackageCreated
    case tileBlobsWritten
    case beforeAtomicCommit
}
