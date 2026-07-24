import Foundation

public struct ArtboardRecord: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// Position and display extent on the freeform pasteboard.
    public var frame: CanvasRect
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var dpi: Double
    public var background: RGBAColor
    public var rootLayerIDs: [UUID]
    public var layers: [LayerRecord]

    public init(
        id: UUID = UUID(),
        name: String,
        frame: CanvasRect,
        pixelWidth: Int,
        pixelHeight: Int,
        dpi: Double = 72,
        background: RGBAColor = .white,
        rootLayerIDs: [UUID] = [],
        layers: [LayerRecord] = []
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.dpi = dpi
        self.background = background
        self.rootLayerIDs = rootLayerIDs
        self.layers = layers
    }

    public func layer(id: UUID) -> LayerRecord? {
        layers.first { $0.id == id }
    }
}

public struct ProjectManifestV1: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let maximumArtboardDimension = 32_768

    public var projectID: UUID
    public var schemaVersion: Int
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var colorSpace: ColorSpaceID
    public var artboards: [ArtboardRecord]
    public var workspace: WorkspaceDescriptor

    public init(
        projectID: UUID = UUID(),
        schemaVersion: Int = ProjectManifestV1.currentSchemaVersion,
        title: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        colorSpace: ColorSpaceID = .sRGB,
        artboards: [ArtboardRecord] = [],
        workspace: WorkspaceDescriptor = .essentials()
    ) {
        self.projectID = projectID
        self.schemaVersion = schemaVersion
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.colorSpace = colorSpace
        self.artboards = artboards
        self.workspace = workspace
    }

    public func artboard(id: UUID) -> ArtboardRecord? {
        artboards.first { $0.id == id }
    }
}
