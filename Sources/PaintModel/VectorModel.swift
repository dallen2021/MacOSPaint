import Foundation

public enum PathNodeKind: String, Codable, CaseIterable, Equatable, Sendable {
    case corner
    case smooth
    case symmetric
}

/// An editable Bézier node. Control points are absolute document coordinates.
public struct PathNode: Codable, Equatable, Sendable {
    public var id: UUID
    public var anchor: CanvasPoint
    public var incomingControl: CanvasPoint?
    public var outgoingControl: CanvasPoint?
    public var kind: PathNodeKind

    public init(
        id: UUID = UUID(),
        anchor: CanvasPoint,
        incomingControl: CanvasPoint? = nil,
        outgoingControl: CanvasPoint? = nil,
        kind: PathNodeKind = .corner
    ) {
        self.id = id
        self.anchor = anchor
        self.incomingControl = incomingControl
        self.outgoingControl = outgoingControl
        self.kind = kind
    }
}

public enum FillRule: String, Codable, CaseIterable, Equatable, Sendable {
    case nonZero = "non-zero"
    case evenOdd = "even-odd"
}

public struct VectorPath: Codable, Equatable, Sendable {
    public var nodes: [PathNode]
    public var isClosed: Bool
    public var fillRule: FillRule

    public init(
        nodes: [PathNode],
        isClosed: Bool = false,
        fillRule: FillRule = .nonZero
    ) {
        self.nodes = nodes
        self.isClosed = isClosed
        self.fillRule = fillRule
    }
}

public struct RectangleShape: Codable, Equatable, Sendable {
    public var bounds: CanvasRect
    public var cornerRadius: Double

    public init(bounds: CanvasRect, cornerRadius: Double = 0) {
        self.bounds = bounds
        self.cornerRadius = cornerRadius
    }
}

public struct EllipseShape: Codable, Equatable, Sendable {
    public var bounds: CanvasRect

    public init(bounds: CanvasRect) {
        self.bounds = bounds
    }
}

public struct LineShape: Codable, Equatable, Sendable {
    public var start: CanvasPoint
    public var end: CanvasPoint
    public var hasArrowAtStart: Bool
    public var hasArrowAtEnd: Bool

    public init(
        start: CanvasPoint,
        end: CanvasPoint,
        hasArrowAtStart: Bool = false,
        hasArrowAtEnd: Bool = false
    ) {
        self.start = start
        self.end = end
        self.hasArrowAtStart = hasArrowAtStart
        self.hasArrowAtEnd = hasArrowAtEnd
    }
}

public struct VectorGroup: Codable, Equatable, Sendable {
    public var childObjectIDs: [UUID]

    public init(childObjectIDs: [UUID] = []) {
        self.childObjectIDs = childObjectIDs
    }
}

public enum VectorObjectType: String, Codable, CaseIterable, Equatable, Sendable {
    case path
    case rectangle
    case ellipse
    case line
    case group
}

/// Payload for a retained vector object, encoded with an explicit stable discriminator.
public enum VectorObjectKind: Equatable, Sendable {
    case path(VectorPath)
    case rectangle(RectangleShape)
    case ellipse(EllipseShape)
    case line(LineShape)
    case group(VectorGroup)

    public var type: VectorObjectType {
        switch self {
        case .path: .path
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        case .line: .line
        case .group: .group
        }
    }
}

extension VectorObjectKind: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case content
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(VectorObjectType.self, forKey: .type) {
        case .path:
            self = .path(try container.decode(VectorPath.self, forKey: .content))
        case .rectangle:
            self = .rectangle(try container.decode(RectangleShape.self, forKey: .content))
        case .ellipse:
            self = .ellipse(try container.decode(EllipseShape.self, forKey: .content))
        case .line:
            self = .line(try container.decode(LineShape.self, forKey: .content))
        case .group:
            self = .group(try container.decode(VectorGroup.self, forKey: .content))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch self {
        case let .path(content):
            try container.encode(content, forKey: .content)
        case let .rectangle(content):
            try container.encode(content, forKey: .content)
        case let .ellipse(content):
            try container.encode(content, forKey: .content)
        case let .line(content):
            try container.encode(content, forKey: .content)
        case let .group(content):
            try container.encode(content, forKey: .content)
        }
    }
}

public struct VectorObject: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var isVisible: Bool
    public var opacity: Double
    public var blendMode: BlendMode
    public var transform: CanvasTransform
    public var fill: FillStyle
    public var stroke: StrokeStyle?
    public var kind: VectorObjectKind

    public init(
        id: UUID = UUID(),
        name: String,
        isVisible: Bool = true,
        opacity: Double = 1,
        blendMode: BlendMode = .normal,
        transform: CanvasTransform = .identity,
        fill: FillStyle = .none,
        stroke: StrokeStyle? = nil,
        kind: VectorObjectKind
    ) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.opacity = opacity
        self.blendMode = blendMode
        self.transform = transform
        self.fill = fill
        self.stroke = stroke
        self.kind = kind
    }
}

/// A retained vector scene uses the same flat-record/explicit-tree pattern as layers.
public struct VectorScene: Codable, Equatable, Sendable {
    public var rootObjectIDs: [UUID]
    public var objects: [VectorObject]

    public init(rootObjectIDs: [UUID] = [], objects: [VectorObject] = []) {
        self.rootObjectIDs = rootObjectIDs
        self.objects = objects
    }
}
