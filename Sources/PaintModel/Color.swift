import Foundation

public enum ColorSpaceID: String, Codable, CaseIterable, Equatable, Sendable {
    case sRGB = "srgb"
    case displayP3 = "display-p3"
}

/// Unpremultiplied color components in the document's working color space.
public struct RGBAColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let black = RGBAColor(red: 0, green: 0, blue: 0)
    public static let white = RGBAColor(red: 1, green: 1, blue: 1)

    public var hasValidComponents: Bool {
        [red, green, blue, alpha].allSatisfy { $0.isFinite && (0 ... 1).contains($0) }
    }
}

public enum BlendMode: String, Codable, CaseIterable, Equatable, Sendable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case colorDodge = "color-dodge"
    case colorBurn = "color-burn"
    case hardLight = "hard-light"
    case softLight = "soft-light"
    case difference
    case exclusion
    case hue
    case saturation
    case color
    case luminosity
}

public struct GradientStop: Codable, Equatable, Sendable {
    public var id: UUID
    public var location: Double
    public var color: RGBAColor

    public init(id: UUID = UUID(), location: Double, color: RGBAColor) {
        self.id = id
        self.location = location
        self.color = color
    }
}

public struct LinearGradient: Codable, Equatable, Sendable {
    public var start: CanvasPoint
    public var end: CanvasPoint
    public var stops: [GradientStop]

    public init(start: CanvasPoint, end: CanvasPoint, stops: [GradientStop]) {
        self.start = start
        self.end = end
        self.stops = stops
    }
}

public struct RadialGradient: Codable, Equatable, Sendable {
    public var center: CanvasPoint
    public var radius: Double
    public var stops: [GradientStop]

    public init(center: CanvasPoint, radius: Double, stops: [GradientStop]) {
        self.center = center
        self.radius = radius
        self.stops = stops
    }
}

public enum FillStyle: Codable, Equatable, Sendable {
    case none
    case solid(RGBAColor)
    case linearGradient(LinearGradient)
    case radialGradient(RadialGradient)
}

public enum LineCap: String, Codable, CaseIterable, Equatable, Sendable {
    case butt
    case round
    case square
}

public enum LineJoin: String, Codable, CaseIterable, Equatable, Sendable {
    case miter
    case round
    case bevel
}

public struct StrokeStyle: Codable, Equatable, Sendable {
    public var color: RGBAColor
    public var width: Double
    public var lineCap: LineCap
    public var lineJoin: LineJoin
    public var dashPattern: [Double]

    public init(
        color: RGBAColor = .black,
        width: Double = 1,
        lineCap: LineCap = .round,
        lineJoin: LineJoin = .round,
        dashPattern: [Double] = []
    ) {
        self.color = color
        self.width = width
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.dashPattern = dashPattern
    }
}
