import Foundation
import PaintModel

public struct PixelRect: Hashable, Codable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isEmpty: Bool {
        width <= 0 || height <= 0
    }
}

/// Everything needed to render one immutable project generation.
public struct RenderSnapshot: Sendable {
    public let manifest: ProjectManifestV1
    public let rasterTiles: RasterTileSnapshot

    public init(
        manifest: ProjectManifestV1,
        rasterTiles: RasterTileSnapshot
    ) {
        self.manifest = manifest
        self.rasterTiles = rasterTiles
    }

    public var generation: UInt64 {
        rasterTiles.generation
    }
}

public struct RenderRequest: Hashable, Sendable {
    public let artboardID: UUID
    public let pixelRegion: PixelRect
    public let outputWidth: Int
    public let outputHeight: Int
    public let expectedGeneration: UInt64?

    public init(
        artboardID: UUID,
        pixelRegion: PixelRect,
        outputWidth: Int,
        outputHeight: Int,
        expectedGeneration: UInt64? = nil
    ) {
        self.artboardID = artboardID
        self.pixelRegion = pixelRegion
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
        self.expectedGeneration = expectedGeneration
    }
}

public enum RenderPixelFormat: String, Codable, Sendable {
    /// Premultiplied, display-referred 8-bit RGBA.
    case rgba8Premultiplied
    /// Premultiplied, linear-light IEEE 754 half-float RGBA.
    case rgba16FloatPremultiplied

    public var bytesPerPixel: Int {
        switch self {
        case .rgba8Premultiplied:
            4
        case .rgba16FloatPremultiplied:
            8
        }
    }
}

public enum RenderContractError: Error, Equatable, Sendable {
    case invalidOutputDimensions(width: Int, height: Int)
    case invalidPixelBufferLength(expected: Int, actual: Int)
    case staleSnapshot(expected: UInt64, actual: UInt64)
    case missingArtboard(UUID)
}

public struct RenderedFrame: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let pixelFormat: RenderPixelFormat
    public let pixels: Data
    public let generation: UInt64

    public init(
        width: Int,
        height: Int,
        bytesPerRow: Int? = nil,
        pixelFormat: RenderPixelFormat,
        pixels: Data,
        generation: UInt64
    ) throws {
        guard width > 0, height > 0 else {
            throw RenderContractError.invalidOutputDimensions(
                width: width,
                height: height
            )
        }
        let (minimumBytesPerRow, rowOverflow) = width.multipliedReportingOverflow(
            by: pixelFormat.bytesPerPixel
        )
        guard !rowOverflow else {
            throw RenderContractError.invalidOutputDimensions(
                width: width,
                height: height
            )
        }
        let resolvedBytesPerRow = bytesPerRow ?? minimumBytesPerRow
        let (expectedCount, countOverflow) =
            resolvedBytesPerRow.multipliedReportingOverflow(by: height)
        guard !countOverflow else {
            throw RenderContractError.invalidOutputDimensions(
                width: width,
                height: height
            )
        }
        guard resolvedBytesPerRow >= minimumBytesPerRow,
              pixels.count == expectedCount
        else {
            throw RenderContractError.invalidPixelBufferLength(
                expected: expectedCount,
                actual: pixels.count
            )
        }
        self.width = width
        self.height = height
        self.bytesPerRow = resolvedBytesPerRow
        self.pixelFormat = pixelFormat
        self.pixels = pixels
        self.generation = generation
    }
}

/// Metal and CPU renderers share this seam. Implementations must consume only
/// the supplied immutable snapshot and must not reach back into live stores.
public protocol RenderBackend: Sendable {
    func render(
        request: RenderRequest,
        snapshot: RenderSnapshot
    ) async throws -> RenderedFrame
}

public extension RenderBackend {
    func validate(
        request: RenderRequest,
        snapshot: RenderSnapshot
    ) throws {
        guard request.outputWidth > 0, request.outputHeight > 0 else {
            throw RenderContractError.invalidOutputDimensions(
                width: request.outputWidth,
                height: request.outputHeight
            )
        }
        if let expected = request.expectedGeneration,
           expected != snapshot.generation
        {
            throw RenderContractError.staleSnapshot(
                expected: expected,
                actual: snapshot.generation
            )
        }
        guard snapshot.manifest.artboards.contains(where: {
            $0.id == request.artboardID
        }) else {
            throw RenderContractError.missingArtboard(request.artboardID)
        }
    }
}
