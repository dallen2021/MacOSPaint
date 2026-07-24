import Foundation

/// A platform-independent point in document space.
public struct CanvasPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = CanvasPoint(x: 0, y: 0)
}

/// A platform-independent size in document space.
public struct CanvasSize: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = CanvasSize(width: 0, height: 0)
}

/// A platform-independent rectangle in document space.
public struct CanvasRect: Codable, Equatable, Sendable {
    public var origin: CanvasPoint
    public var size: CanvasSize

    public init(origin: CanvasPoint, size: CanvasSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(
            origin: CanvasPoint(x: x, y: y),
            size: CanvasSize(width: width, height: height)
        )
    }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var midX: Double { origin.x + size.width / 2 }
    public var midY: Double { origin.y + size.height / 2 }

    public func contains(_ point: CanvasPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

/// A two-dimensional affine transform, stored without depending on CoreGraphics.
public struct CanvasTransform: Codable, Equatable, Sendable {
    public var a: Double
    public var b: Double
    public var c: Double
    public var d: Double
    public var tx: Double
    public var ty: Double

    public init(
        a: Double = 1,
        b: Double = 0,
        c: Double = 0,
        d: Double = 1,
        tx: Double = 0,
        ty: Double = 0
    ) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    public static let identity = CanvasTransform()

    public func applying(to point: CanvasPoint) -> CanvasPoint {
        CanvasPoint(
            x: a * point.x + c * point.y + tx,
            y: b * point.x + d * point.y + ty
        )
    }
}
