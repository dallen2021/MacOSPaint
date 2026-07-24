import Foundation
import PaintModel

public struct BrushInputPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let timestamp: TimeInterval
    public let pressure: Double
    public let tiltX: Double
    public let tiltY: Double
    public let rotation: Double

    public init(
        x: Double,
        y: Double,
        timestamp: TimeInterval,
        pressure: Double,
        tiltX: Double = 0,
        tiltY: Double = 0,
        rotation: Double = 0
    ) {
        self.x = x
        self.y = y
        self.timestamp = timestamp
        self.pressure = pressure
        self.tiltX = tiltX
        self.tiltY = tiltY
        self.rotation = rotation
    }

    public init(pointerSample: PointerSample) {
        self.init(
            x: pointerSample.location.x,
            y: pointerSample.location.y,
            timestamp: pointerSample.timestamp,
            pressure: pointerSample.pressure,
            tiltX: pointerSample.tiltX,
            tiltY: pointerSample.tiltY,
            rotation: pointerSample.azimuth
        )
    }
}

public struct BrushSamplingSettings: Equatable, Sendable {
    public let diameter: Double
    /// Dab distance as a fraction of the pressure-adjusted diameter.
    public let spacing: Double
    public let opacity: Double
    public let minimumDiameterRatio: Double
    public let minimumOpacityRatio: Double
    public let pressureExponent: Double
    /// A deterministic low-pass amount in the closed range `0...1`.
    public let stabilization: Double

    public init(
        diameter: Double,
        spacing: Double = 0.12,
        opacity: Double = 1,
        minimumDiameterRatio: Double = 0.1,
        minimumOpacityRatio: Double = 0.2,
        pressureExponent: Double = 1,
        stabilization: Double = 0
    ) throws {
        guard diameter.isFinite, diameter > 0 else {
            throw BrushSamplerError.invalidDiameter(diameter)
        }
        guard spacing.isFinite, spacing > 0 else {
            throw BrushSamplerError.invalidSpacing(spacing)
        }
        guard opacity.isFinite,
              minimumDiameterRatio.isFinite,
              minimumOpacityRatio.isFinite,
              pressureExponent.isFinite,
              stabilization.isFinite,
              (0...1).contains(opacity),
              (0...1).contains(minimumDiameterRatio),
              (0...1).contains(minimumOpacityRatio),
              (0...1).contains(stabilization),
              pressureExponent > 0
        else {
            throw BrushSamplerError.invalidPressureMapping
        }
        self.diameter = diameter
        self.spacing = spacing
        self.opacity = opacity
        self.minimumDiameterRatio = minimumDiameterRatio
        self.minimumOpacityRatio = minimumOpacityRatio
        self.pressureExponent = pressureExponent
        self.stabilization = stabilization
    }

    public init(toolSettings: PaintModel.BrushSettings) throws {
        try self.init(
            diameter: toolSettings.diameter,
            spacing: toolSettings.spacing,
            opacity: toolSettings.opacity * toolSettings.flow,
            minimumDiameterRatio: toolSettings.usesPressureForSize ? 0.1 : 1,
            minimumOpacityRatio: toolSettings.usesPressureForOpacity ? 0.2 : 1,
            pressureExponent: 1,
            stabilization: toolSettings.stabilization
        )
    }
}

public struct BrushDab: Equatable, Sendable {
    public let sequence: Int
    public let x: Double
    public let y: Double
    public let timestamp: TimeInterval
    public let pressure: Double
    public let diameter: Double
    public let opacity: Double
    public let tiltX: Double
    public let tiltY: Double
    public let rotation: Double
}

public enum BrushSamplerError: Error, Equatable, Sendable {
    case invalidDiameter(Double)
    case invalidSpacing(Double)
    case invalidPressureMapping
}

/// Converts raw coalesced pointer samples into evenly spaced, pressure-shaped
/// dabs. The sampler deliberately contains no random source; equal inputs yield
/// byte-for-byte equal dab sequences across repeated runs.
public enum PressureBrushSampler {
    public static func sampleStroke(
        _ samples: [PointerSample],
        settings: BrushSamplingSettings
    ) -> [BrushDab] {
        sampleStroke(
            samples.map(BrushInputPoint.init(pointerSample:)),
            settings: settings
        )
    }

    public static func sampleStroke(
        _ points: [BrushInputPoint],
        settings: BrushSamplingSettings
    ) -> [BrushDab] {
        guard !points.isEmpty else {
            return []
        }

        let stabilized = stabilize(points, amount: settings.stabilization)
        var dabs: [BrushDab] = [makeDab(first: stabilized[0], sequence: 0, settings: settings)]
        var previousInput = stabilized[0]
        var distanceUntilNext = spacing(after: stabilized[0], settings: settings)

        for nextInput in stabilized.dropFirst() {
            var segmentStart = previousInput
            var segmentDistance = distance(segmentStart, nextInput)

            while segmentDistance > 0, segmentDistance >= distanceUntilNext {
                let fraction = distanceUntilNext / segmentDistance
                let nextDabPoint = interpolate(
                    from: segmentStart,
                    to: nextInput,
                    fraction: fraction
                )
                dabs.append(
                    makeDab(
                        first: nextDabPoint,
                        sequence: dabs.count,
                        settings: settings
                    )
                )
                segmentStart = nextDabPoint
                segmentDistance = distance(segmentStart, nextInput)
                distanceUntilNext = spacing(
                    after: nextDabPoint,
                    settings: settings
                )
            }

            distanceUntilNext -= segmentDistance
            // Protect the progress invariant from accumulated floating-point
            // cancellation on extremely long strokes.
            distanceUntilNext = max(distanceUntilNext, Double.ulpOfOne)
            previousInput = nextInput
        }
        return dabs
    }

    private static func stabilize(
        _ points: [BrushInputPoint],
        amount: Double
    ) -> [BrushInputPoint] {
        guard amount > 0, var previous = points.first else {
            return points
        }

        let response = 1 - amount * 0.85
        var result = [previous]
        result.reserveCapacity(points.count)
        for point in points.dropFirst() {
            let filtered = BrushInputPoint(
                x: previous.x + (point.x - previous.x) * response,
                y: previous.y + (point.y - previous.y) * response,
                timestamp: point.timestamp,
                pressure: previous.pressure
                    + (point.pressure - previous.pressure) * response,
                tiltX: previous.tiltX + (point.tiltX - previous.tiltX) * response,
                tiltY: previous.tiltY + (point.tiltY - previous.tiltY) * response,
                rotation: previous.rotation
                    + (point.rotation - previous.rotation) * response
            )
            result.append(filtered)
            previous = filtered
        }
        return result
    }

    private static func makeDab(
        first point: BrushInputPoint,
        sequence: Int,
        settings: BrushSamplingSettings
    ) -> BrushDab {
        let pressure = point.pressure.isFinite
            ? min(max(point.pressure, 0), 1)
            : 0
        let response = pow(pressure, settings.pressureExponent)
        let diameterRatio = settings.minimumDiameterRatio
            + (1 - settings.minimumDiameterRatio) * response
        let opacityRatio = settings.minimumOpacityRatio
            + (1 - settings.minimumOpacityRatio) * response

        return BrushDab(
            sequence: sequence,
            x: point.x,
            y: point.y,
            timestamp: point.timestamp,
            pressure: pressure,
            diameter: settings.diameter * diameterRatio,
            opacity: settings.opacity * opacityRatio,
            tiltX: point.tiltX,
            tiltY: point.tiltY,
            rotation: point.rotation
        )
    }

    private static func spacing(
        after point: BrushInputPoint,
        settings: BrushSamplingSettings
    ) -> Double {
        let dab = makeDab(first: point, sequence: 0, settings: settings)
        return max(0.25, dab.diameter * settings.spacing)
    }

    private static func distance(
        _ first: BrushInputPoint,
        _ second: BrushInputPoint
    ) -> Double {
        hypot(second.x - first.x, second.y - first.y)
    }

    private static func interpolate(
        from first: BrushInputPoint,
        to second: BrushInputPoint,
        fraction: Double
    ) -> BrushInputPoint {
        BrushInputPoint(
            x: lerp(first.x, second.x, fraction),
            y: lerp(first.y, second.y, fraction),
            timestamp: lerp(first.timestamp, second.timestamp, fraction),
            pressure: lerp(first.pressure, second.pressure, fraction),
            tiltX: lerp(first.tiltX, second.tiltX, fraction),
            tiltY: lerp(first.tiltY, second.tiltY, fraction),
            rotation: lerp(first.rotation, second.rotation, fraction)
        )
    }

    private static func lerp(
        _ first: Double,
        _ second: Double,
        _ fraction: Double
    ) -> Double {
        first + (second - first) * fraction
    }
}
