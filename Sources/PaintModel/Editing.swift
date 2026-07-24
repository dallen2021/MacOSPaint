import Foundation

public enum CanvasTool: String, Codable, CaseIterable, Equatable, Sendable {
    case objectSelection = "object-selection"
    case directSelection = "direct-selection"
    case rectangularMarquee = "rectangular-marquee"
    case ellipticalMarquee = "elliptical-marquee"
    case freehandLasso = "freehand-lasso"
    case polygonLasso = "polygon-lasso"
    case magicWand = "magic-wand"
    case subjectSelection = "subject-selection"
    case crop
    case transform
    case brush
    case pencil
    case eraser
    case fill
    case gradient
    case eyedropper
    case cloneStamp = "clone-stamp"
    case spotHeal = "spot-heal"
    case blur
    case sharpen
    case smudge
    case pen
    case shape
    case text
    case hand
    case zoom
}

public typealias ToolIdentifier = CanvasTool

public enum PointerPhase: String, Codable, CaseIterable, Equatable, Sendable {
    case began
    case moved
    case ended
    case cancelled
    case hover
}

public enum PointerDevice: String, Codable, CaseIterable, Equatable, Sendable {
    case mouse
    case trackpad
    case stylus
    case eraser
}

public enum PointerModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case shift
    case control
    case option
    case command
    case capsLock = "caps-lock"
}

/// One normalized input sample. Pressure uses `0...1`; tilt is expressed in radians.
public struct PointerSample: Codable, Equatable, Sendable {
    public var location: CanvasPoint
    public var timestamp: Double
    public var pressure: Double
    public var tiltX: Double
    public var tiltY: Double
    public var azimuth: Double
    public var phase: PointerPhase
    public var device: PointerDevice
    public var modifiers: Set<PointerModifier>

    public init(
        location: CanvasPoint,
        timestamp: Double,
        pressure: Double = 1,
        tiltX: Double = 0,
        tiltY: Double = 0,
        azimuth: Double = 0,
        phase: PointerPhase = .moved,
        device: PointerDevice = .mouse,
        modifiers: Set<PointerModifier> = []
    ) {
        self.location = location
        self.timestamp = timestamp
        self.pressure = pressure
        self.tiltX = tiltX
        self.tiltY = tiltY
        self.azimuth = azimuth
        self.phase = phase
        self.device = device
        self.modifiers = modifiers
    }
}

public struct BrushSettings: Codable, Equatable, Sendable {
    public var diameter: Double
    public var hardness: Double
    public var opacity: Double
    public var flow: Double
    public var spacing: Double
    public var stabilization: Double
    public var usesPressureForSize: Bool
    public var usesPressureForOpacity: Bool

    public init(
        diameter: Double = 24,
        hardness: Double = 0.8,
        opacity: Double = 1,
        flow: Double = 1,
        spacing: Double = 0.12,
        stabilization: Double = 0.25,
        usesPressureForSize: Bool = true,
        usesPressureForOpacity: Bool = false
    ) {
        self.diameter = diameter
        self.hardness = hardness
        self.opacity = opacity
        self.flow = flow
        self.spacing = spacing
        self.stabilization = stabilization
        self.usesPressureForSize = usesPressureForSize
        self.usesPressureForOpacity = usesPressureForOpacity
    }
}

public struct ToolContext: Codable, Equatable, Sendable {
    public var artboardID: UUID
    public var layerID: UUID?
    public var tool: CanvasTool
    public var zoomScale: Double
    public var primaryColor: RGBAColor
    public var secondaryColor: RGBAColor
    public var brush: BrushSettings

    public init(
        artboardID: UUID,
        layerID: UUID? = nil,
        tool: CanvasTool,
        zoomScale: Double = 1,
        primaryColor: RGBAColor = .black,
        secondaryColor: RGBAColor = .white,
        brush: BrushSettings = BrushSettings()
    ) {
        self.artboardID = artboardID
        self.layerID = layerID
        self.tool = tool
        self.zoomScale = zoomScale
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.brush = brush
    }
}

/// An in-memory tile state used by undo transactions.
public enum TileDataSnapshot: Equatable, Sendable {
    case absent
    case bytes(Data)

    public var data: Data? {
        switch self {
        case .absent: nil
        case let .bytes(data): data
        }
    }

    public var byteCount: Int {
        data?.count ?? 0
    }
}

extension TileDataSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case state
        case data
    }

    private enum State: String, Codable {
        case absent
        case bytes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(State.self, forKey: .state) {
        case .absent:
            self = .absent
        case .bytes:
            self = .bytes(try container.decode(Data.self, forKey: .data))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .absent:
            try container.encode(State.absent, forKey: .state)
        case let .bytes(data):
            try container.encode(State.bytes, forKey: .state)
            try container.encode(data, forKey: .data)
        }
    }
}

public struct TileDelta: Codable, Equatable, Sendable {
    public var id: UUID
    public var artboardID: UUID
    public var layerID: UUID
    public var coordinate: TileCoordinate
    public var before: TileDataSnapshot
    public var after: TileDataSnapshot

    public init(
        id: UUID = UUID(),
        artboardID: UUID,
        layerID: UUID,
        coordinate: TileCoordinate,
        before: TileDataSnapshot,
        after: TileDataSnapshot
    ) {
        self.id = id
        self.artboardID = artboardID
        self.layerID = layerID
        self.coordinate = coordinate
        self.before = before
        self.after = after
    }

    public init(
        id: UUID = UUID(),
        artboardID: UUID,
        layerID: UUID,
        coordinate: TileCoordinate,
        beforeData: Data?,
        afterData: Data?
    ) {
        self.init(
            id: id,
            artboardID: artboardID,
            layerID: layerID,
            coordinate: coordinate,
            before: beforeData.map(TileDataSnapshot.bytes) ?? .absent,
            after: afterData.map(TileDataSnapshot.bytes) ?? .absent
        )
    }

    public var estimatedByteCount: Int {
        before.byteCount + after.byteCount
    }
}

public enum EditOperationKind: String, Codable, CaseIterable, Equatable, Sendable {
    case stroke
    case transform
    case filter
    case structural
    case vector
    case text
    case selection
}

/// One atomic, named undo step.
public struct EditTransaction: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: EditOperationKind
    public var timestamp: Date
    public var artboardID: UUID?
    public var layerID: UUID?
    public var tileDeltas: [TileDelta]
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        name: String,
        kind: EditOperationKind,
        timestamp: Date = Date(),
        artboardID: UUID? = nil,
        layerID: UUID? = nil,
        tileDeltas: [TileDelta] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.timestamp = timestamp
        self.artboardID = artboardID
        self.layerID = layerID
        self.tileDeltas = tileDeltas
        self.metadata = metadata
    }

    public var estimatedByteCount: Int {
        tileDeltas.reduce(into: 0) { $0 += $1.estimatedByteCount }
    }
}

public enum UndoLimits {
    public static let maximumTransactionCount = 100
    public static let maximumByteCount = 512 * 1_024 * 1_024
}
