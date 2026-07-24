import Foundation
import PaintEngine
import PaintModel

public enum ImageFileFormat: String, Codable, CaseIterable, Sendable {
    case png
    case jpeg
    case tiff
    case heic
    case webP = "webp"
    case svg
    case pdf
}

public struct ImportedRasterPage: Equatable, Sendable {
    public let name: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let dpi: Double
    public let colorSpace: ColorSpaceID
    public let rgba8Premultiplied: Data

    public init(
        name: String,
        pixelWidth: Int,
        pixelHeight: Int,
        dpi: Double,
        colorSpace: ColorSpaceID,
        rgba8Premultiplied: Data
    ) throws {
        let expected = try Self.expectedRGBAByteCount(
            width: pixelWidth,
            height: pixelHeight
        )
        guard
              rgba8Premultiplied.count == expected
        else {
            throw MediaAdapterError.invalidPixelBuffer(
                expected: expected,
                actual: rgba8Premultiplied.count
            )
        }
        self.name = name
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.dpi = dpi
        self.colorSpace = colorSpace
        self.rgba8Premultiplied = rgba8Premultiplied
    }

    private static func expectedRGBAByteCount(
        width: Int,
        height: Int
    ) throws -> Int {
        guard width > 0, height > 0 else {
            throw MediaAdapterError.invalidPixelBuffer(
                expected: 0,
                actual: 0
            )
        }
        let (pixelCount, pixelOverflow) =
            width.multipliedReportingOverflow(by: height)
        let (byteCount, byteOverflow) =
            pixelCount.multipliedReportingOverflow(by: 4)
        guard !pixelOverflow, !byteOverflow else {
            throw MediaAdapterError.invalidPixelBuffer(
                expected: Int.max,
                actual: 0
            )
        }
        return byteCount
    }
}

public struct ImageImportRequest: Equatable, Sendable {
    public let sourceURL: URL
    public let pdfPageIndices: [Int]?
    public let pdfDPI: Double
    public let preferredColorSpace: ColorSpaceID?

    public init(
        sourceURL: URL,
        pdfPageIndices: [Int]? = nil,
        pdfDPI: Double = 144,
        preferredColorSpace: ColorSpaceID? = nil
    ) {
        self.sourceURL = sourceURL
        self.pdfPageIndices = pdfPageIndices
        self.pdfDPI = pdfDPI
        self.preferredColorSpace = preferredColorSpace
    }
}

public struct ImageImportResult: Equatable, Sendable {
    public let pages: [ImportedRasterPage]
    public let warnings: [String]

    public init(pages: [ImportedRasterPage], warnings: [String] = []) {
        self.pages = pages
        self.warnings = warnings
    }
}

public protocol ImageImporter: Sendable {
    func importImage(
        _ request: ImageImportRequest
    ) async throws -> ImageImportResult
}

public struct ImageExportItem: Equatable, Sendable {
    public let artboardID: UUID
    public let name: String
    public let frame: RenderedFrame

    public init(artboardID: UUID, name: String, frame: RenderedFrame) {
        self.artboardID = artboardID
        self.name = name
        self.frame = frame
    }
}

public struct ImageExportRequest: Equatable, Sendable {
    public let destinationURL: URL
    public let format: ImageFileFormat
    public let items: [ImageExportItem]
    public let quality: Double
    public let embedsColorProfile: Bool

    public init(
        destinationURL: URL,
        format: ImageFileFormat,
        items: [ImageExportItem],
        quality: Double = 0.9,
        embedsColorProfile: Bool = true
    ) {
        self.destinationURL = destinationURL
        self.format = format
        self.items = items
        self.quality = quality
        self.embedsColorProfile = embedsColorProfile
    }
}

public struct ImageExportResult: Equatable, Sendable {
    public let writtenURLs: [URL]
    public let warnings: [String]

    public init(writtenURLs: [URL], warnings: [String] = []) {
        self.writtenURLs = writtenURLs
        self.warnings = warnings
    }
}

public protocol ImageExporter: Sendable {
    func export(
        _ request: ImageExportRequest
    ) async throws -> ImageExportResult
}

public struct SubjectSelectionRequest: Equatable, Sendable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let rgba8Premultiplied: Data
    public let quality: SubjectSelectionQuality

    public init(
        pixelWidth: Int,
        pixelHeight: Int,
        rgba8Premultiplied: Data,
        quality: SubjectSelectionQuality = .accurate
    ) throws {
        let expected = try Self.expectedRGBAByteCount(
            width: pixelWidth,
            height: pixelHeight
        )
        guard
              rgba8Premultiplied.count == expected
        else {
            throw MediaAdapterError.invalidPixelBuffer(
                expected: expected,
                actual: rgba8Premultiplied.count
            )
        }
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.rgba8Premultiplied = rgba8Premultiplied
        self.quality = quality
    }

    private static func expectedRGBAByteCount(
        width: Int,
        height: Int
    ) throws -> Int {
        guard width > 0, height > 0 else {
            throw MediaAdapterError.invalidPixelBuffer(
                expected: 0,
                actual: 0
            )
        }
        let (pixelCount, pixelOverflow) =
            width.multipliedReportingOverflow(by: height)
        let (byteCount, byteOverflow) =
            pixelCount.multipliedReportingOverflow(by: 4)
        guard !pixelOverflow, !byteOverflow else {
            throw MediaAdapterError.invalidPixelBuffer(
                expected: Int.max,
                actual: 0
            )
        }
        return byteCount
    }
}

public enum SubjectSelectionQuality: String, Codable, Sendable {
    case fast
    case accurate
}

public struct SubjectSelectionResult: Equatable, Sendable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    /// One 8-bit grayscale coverage byte per input pixel.
    public let mask: Data

    public init(pixelWidth: Int, pixelHeight: Int, mask: Data) throws {
        guard pixelWidth > 0, pixelHeight > 0 else {
            throw MediaAdapterError.invalidMaskBuffer(
                expected: 0,
                actual: mask.count
            )
        }
        let (expected, overflow) =
            pixelWidth.multipliedReportingOverflow(by: pixelHeight)
        guard !overflow, mask.count == expected else {
            throw MediaAdapterError.invalidMaskBuffer(
                expected: expected,
                actual: mask.count
            )
        }
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.mask = mask
    }
}

public protocol SubjectSelecting: Sendable {
    func selectSubject(
        in request: SubjectSelectionRequest
    ) async throws -> SubjectSelectionResult
}

public enum MediaAdapterError: Error, Equatable, Sendable {
    case unsupportedFormat(ImageFileFormat)
    case invalidPixelBuffer(expected: Int, actual: Int)
    case invalidMaskBuffer(expected: Int, actual: Int)
    case adapterUnavailable
}

/// Useful as an explicit dependency until the platform Image I/O adapter lands.
public struct UnavailableImageImporter: ImageImporter {
    public init() {}

    public func importImage(
        _ request: ImageImportRequest
    ) async throws -> ImageImportResult {
        throw MediaAdapterError.adapterUnavailable
    }
}

public struct UnavailableImageExporter: ImageExporter {
    public init() {}

    public func export(
        _ request: ImageExportRequest
    ) async throws -> ImageExportResult {
        throw MediaAdapterError.adapterUnavailable
    }
}

public struct UnavailableSubjectSelector: SubjectSelecting {
    public init() {}

    public func selectSubject(
        in request: SubjectSelectionRequest
    ) async throws -> SubjectSelectionResult {
        throw MediaAdapterError.adapterUnavailable
    }
}
