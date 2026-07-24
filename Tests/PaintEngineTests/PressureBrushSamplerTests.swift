import Testing
@testable import PaintEngine

struct PressureBrushSamplerTests {
    @Test
    func samplingIsDeterministicAndIncludesFirstPoint() throws {
        let settings = try BrushSamplingSettings(
            diameter: 20,
            spacing: 0.25,
            minimumDiameterRatio: 0.2,
            minimumOpacityRatio: 0.1
        )
        let points = [
            BrushInputPoint(x: 1, y: 2, timestamp: 0, pressure: 0.25),
            BrushInputPoint(x: 31, y: 2, timestamp: 1, pressure: 0.75)
        ]

        let first = PressureBrushSampler.sampleStroke(points, settings: settings)
        let second = PressureBrushSampler.sampleStroke(points, settings: settings)

        #expect(first == second)
        #expect(first.first?.x == 1)
        #expect(first.first?.y == 2)
        #expect(first.map(\.sequence) == Array(first.indices))
    }

    @Test
    func pressureControlsDiameterAndOpacity() throws {
        let settings = try BrushSamplingSettings(
            diameter: 100,
            spacing: 1,
            opacity: 0.8,
            minimumDiameterRatio: 0.2,
            minimumOpacityRatio: 0.25
        )

        let low = PressureBrushSampler.sampleStroke(
            [BrushInputPoint(x: 0, y: 0, timestamp: 0, pressure: 0)],
            settings: settings
        )[0]
        let high = PressureBrushSampler.sampleStroke(
            [BrushInputPoint(x: 0, y: 0, timestamp: 0, pressure: 1)],
            settings: settings
        )[0]

        #expect(abs(low.diameter - 20) < 0.000_001)
        #expect(abs(high.diameter - 100) < 0.000_001)
        #expect(abs(low.opacity - 0.2) < 0.000_001)
        #expect(abs(high.opacity - 0.8) < 0.000_001)
    }

    @Test
    func pressureAndCoordinatesAreClampedAndStabilized() throws {
        let settings = try BrushSamplingSettings(
            diameter: 10,
            spacing: 0.5,
            stabilization: 1
        )
        let dabs = PressureBrushSampler.sampleStroke(
            [
                BrushInputPoint(x: 0, y: 0, timestamp: 0, pressure: -10),
                BrushInputPoint(x: 100, y: 0, timestamp: 1, pressure: 10)
            ],
            settings: settings
        )

        #expect(dabs.first?.pressure == 0)
        #expect(dabs.allSatisfy { (0...1).contains($0.pressure) })
        #expect((dabs.last?.x ?? 100) < 100)
    }

    @Test
    func invalidSettingsAreRejected() {
        #expect(throws: BrushSamplerError.invalidDiameter(0)) {
            try BrushSamplingSettings(diameter: 0)
        }
        #expect(throws: BrushSamplerError.invalidSpacing(0)) {
            try BrushSamplingSettings(diameter: 10, spacing: 0)
        }
        #expect(throws: BrushSamplerError.invalidPressureMapping) {
            try BrushSamplingSettings(diameter: 10, minimumOpacityRatio: 2)
        }
    }
}
