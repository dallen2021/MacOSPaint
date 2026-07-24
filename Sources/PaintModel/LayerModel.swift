import Foundation

public struct TileCoordinate: Codable, Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// A package-relative reference to one losslessly encoded raster tile.
public struct RasterTileReference: Codable, Equatable, Sendable {
    public var coordinate: TileCoordinate
    public var relativePath: String
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var byteCount: Int?
    public var checksum: String?

    public init(
        coordinate: TileCoordinate,
        relativePath: String,
        pixelWidth: Int = 256,
        pixelHeight: Int = 256,
        byteCount: Int? = nil,
        checksum: String? = nil
    ) {
        self.coordinate = coordinate
        self.relativePath = relativePath
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteCount = byteCount
        self.checksum = checksum
    }
}

public typealias TileReference = RasterTileReference

public struct RasterLayerContent: Codable, Equatable, Sendable {
    public var tileSize: Int
    public var tileReferences: [RasterTileReference]

    public init(tileSize: Int = 256, tileReferences: [RasterTileReference] = []) {
        self.tileSize = tileSize
        self.tileReferences = tileReferences
    }
}

public struct LayerMaskRecord: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var isInverted: Bool
    public var tileSize: Int
    public var tileReferences: [RasterTileReference]

    public init(
        isEnabled: Bool = true,
        isInverted: Bool = false,
        tileSize: Int = 256,
        tileReferences: [RasterTileReference] = []
    ) {
        self.isEnabled = isEnabled
        self.isInverted = isInverted
        self.tileSize = tileSize
        self.tileReferences = tileReferences
    }
}

public struct TextLayerContent: Codable, Equatable, Sendable {
    public var text: String
    public var fontPostScriptName: String
    public var fontSize: Double
    public var color: RGBAColor
    public var bounds: CanvasRect
    public var horizontalAlignment: TextHorizontalAlignment

    public init(
        text: String,
        fontPostScriptName: String = "Helvetica",
        fontSize: Double = 24,
        color: RGBAColor = .black,
        bounds: CanvasRect,
        horizontalAlignment: TextHorizontalAlignment = .leading
    ) {
        self.text = text
        self.fontPostScriptName = fontPostScriptName
        self.fontSize = fontSize
        self.color = color
        self.bounds = bounds
        self.horizontalAlignment = horizontalAlignment
    }
}

public enum TextHorizontalAlignment: String, Codable, CaseIterable, Equatable, Sendable {
    case leading
    case center
    case trailing
    case justified
}

public struct GroupLayerContent: Codable, Equatable, Sendable {
    public var childLayerIDs: [UUID]

    public init(childLayerIDs: [UUID] = []) {
        self.childLayerIDs = childLayerIDs
    }
}

public enum LayerType: String, Codable, CaseIterable, Equatable, Sendable {
    case raster
    case vector
    case text
    case group
}

/// Layer payload, encoded as `{ "type": ..., "content": ... }`.
public enum LayerKind: Equatable, Sendable {
    case raster(RasterLayerContent)
    case vector(VectorScene)
    case text(TextLayerContent)
    case group(GroupLayerContent)

    public var type: LayerType {
        switch self {
        case .raster: .raster
        case .vector: .vector
        case .text: .text
        case .group: .group
        }
    }
}

extension LayerKind: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case content
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(LayerType.self, forKey: .type) {
        case .raster:
            self = .raster(try container.decode(RasterLayerContent.self, forKey: .content))
        case .vector:
            self = .vector(try container.decode(VectorScene.self, forKey: .content))
        case .text:
            self = .text(try container.decode(TextLayerContent.self, forKey: .content))
        case .group:
            self = .group(try container.decode(GroupLayerContent.self, forKey: .content))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch self {
        case let .raster(content):
            try container.encode(content, forKey: .content)
        case let .vector(content):
            try container.encode(content, forKey: .content)
        case let .text(content):
            try container.encode(content, forKey: .content)
        case let .group(content):
            try container.encode(content, forKey: .content)
        }
    }
}

public struct LayerRecord: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var isVisible: Bool
    public var isLocked: Bool
    public var opacity: Double
    public var blendMode: BlendMode
    public var transform: CanvasTransform
    public var mask: LayerMaskRecord?
    public var kind: LayerKind

    public init(
        id: UUID = UUID(),
        name: String,
        isVisible: Bool = true,
        isLocked: Bool = false,
        opacity: Double = 1,
        blendMode: BlendMode = .normal,
        transform: CanvasTransform = .identity,
        mask: LayerMaskRecord? = nil,
        kind: LayerKind
    ) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.opacity = opacity
        self.blendMode = blendMode
        self.transform = transform
        self.mask = mask
        self.kind = kind
    }
}
