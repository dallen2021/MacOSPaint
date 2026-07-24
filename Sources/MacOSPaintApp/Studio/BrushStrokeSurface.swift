import AppKit
import PaintEngine
import PaintModel
import SwiftUI

/// A pressure sample stored in artboard-relative coordinates.
///
/// Keeping the coordinates normalized lets the same stroke render faithfully
/// in the canvas, the artboard filmstrip, and a full-resolution export.
struct StudioBrushStroke: Identifiable, Equatable, Sendable {
    let id: UUID
    let artboardID: UUID
    let samples: [PointerSample]
    /// Brush diameter in points at the size where the stroke was captured.
    let diameter: Double
    /// The shortest view dimension when `diameter` was captured.
    let referenceDimension: Double
    let opacity: Double

    var normalizedDiameter: Double {
        diameter / max(referenceDimension, 1)
    }

    func copied(to artboardID: UUID) -> StudioBrushStroke {
        StudioBrushStroke(
            id: UUID(),
            artboardID: artboardID,
            samples: samples,
            diameter: diameter,
            referenceDimension: referenceDimension,
            opacity: opacity
        )
    }
}

struct BrushStrokeSurface: NSViewRepresentable {
    let artboardID: UUID
    var strokes: [StudioBrushStroke]
    var isEnabled: Bool
    var isVisible: Bool
    var isMirrored: Bool
    var brushSize: Double
    var opacity: Double
    var onStrokesChanged: @MainActor ([StudioBrushStroke]) -> Void

    func makeNSView(context: Context) -> BrushStrokeNSView {
        let view = BrushStrokeNSView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: BrushStrokeNSView, context: Context) {
        configure(nsView)
    }

    static func dismantleNSView(_ nsView: BrushStrokeNSView, coordinator: Void) {
        nsView.removeRegisteredUndoActions()
        nsView.cancelCurrentStroke()
    }

    private func configure(_ view: BrushStrokeNSView) {
        view.artboardID = artboardID
        view.strokes = strokes
        view.isBrushEnabled = isEnabled
        view.areStrokesVisible = isVisible
        view.isMirrored = isMirrored
        view.brushSize = brushSize
        view.brushOpacity = opacity
        view.onStrokesChanged = onStrokesChanged
    }
}

@MainActor
final class BrushStrokeNSView: NSView {
    var artboardID = UUID()
    var strokes: [StudioBrushStroke] = [] {
        didSet {
            guard strokes != oldValue else { return }
            needsDisplay = true
        }
    }
    var onStrokesChanged: (@MainActor ([StudioBrushStroke]) -> Void)?

    var isBrushEnabled = false {
        didSet {
            if !isBrushEnabled {
                cancelCurrentStroke()
            }
        }
    }

    var areStrokesVisible = true {
        didSet {
            if areStrokesVisible != oldValue {
                needsDisplay = true
            }
        }
    }

    var isMirrored = false {
        didSet {
            if isMirrored != oldValue {
                needsDisplay = true
            }
        }
    }

    var brushSize = 24.0
    var brushOpacity = 1.0

    private var currentSamples: [PointerSample] = []
    private var currentDiameter = 24.0
    private var currentOpacity = 1.0
    private var currentReferenceDimension = 1.0
    private weak var registeredUndoManager: UndoManager?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isBrushEnabled ? super.hitTest(point) : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard isBrushEnabled else { return }
        window?.makeFirstResponder(self)
        currentDiameter = brushSize
        currentOpacity = brushOpacity
        currentReferenceDimension = max(min(bounds.width, bounds.height), 1)
        currentSamples = [sample(from: event)]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isBrushEnabled, !currentSamples.isEmpty else { return }
        currentSamples.append(sample(from: event))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isBrushEnabled, !currentSamples.isEmpty else { return }
        currentSamples.append(sample(from: event))
        let stroke = StudioBrushStroke(
            id: UUID(),
            artboardID: artboardID,
            samples: currentSamples,
            diameter: currentDiameter,
            referenceDimension: currentReferenceDimension,
            opacity: currentOpacity
        )
        currentSamples.removeAll(keepingCapacity: true)
        insertStroke(stroke, registersUndo: true)
    }

    override func pressureChange(with event: NSEvent) {
        guard isBrushEnabled, !currentSamples.isEmpty else { return }
        currentSamples.append(sample(from: event))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()

        if areStrokesVisible {
            StudioBrushRendering.draw(
                strokes,
                in: context,
                size: bounds.size,
                hasTopLeftOrigin: true,
                isMirrored: isMirrored
            )
        }

        if !currentSamples.isEmpty {
            let current = StudioBrushStroke(
                id: UUID(),
                artboardID: artboardID,
                samples: currentSamples,
                diameter: currentDiameter,
                referenceDimension: currentReferenceDimension,
                opacity: currentOpacity
            )
            StudioBrushRendering.draw(
                [current],
                in: context,
                size: bounds.size,
                hasTopLeftOrigin: true,
                isMirrored: isMirrored
            )
        }
        context.restoreGState()
    }

    func cancelCurrentStroke() {
        currentSamples.removeAll(keepingCapacity: false)
        needsDisplay = true
    }

    func removeRegisteredUndoActions() {
        registeredUndoManager?.removeAllActions(withTarget: self)
        undoManager?.removeAllActions(withTarget: self)
        registeredUndoManager = nil
    }

    private func insertStroke(
        _ stroke: StudioBrushStroke,
        at index: Int? = nil,
        registersUndo: Bool
    ) {
        guard stroke.artboardID == artboardID else { return }
        let insertionIndex = min(max(index ?? strokes.endIndex, 0), strokes.endIndex)
        strokes.insert(stroke, at: insertionIndex)
        onStrokesChanged?(strokes)
        needsDisplay = true

        guard registersUndo, let manager = undoManager ?? window?.undoManager else { return }
        registeredUndoManager = manager
        manager.registerUndo(withTarget: self) { target in
            target.removeStroke(id: stroke.id, registersUndo: true)
        }
        manager.setActionName("Brush Stroke")
    }

    private func removeStroke(id: UUID, registersUndo: Bool) {
        guard let index = strokes.firstIndex(where: { $0.id == id }) else { return }
        let stroke = strokes.remove(at: index)
        onStrokesChanged?(strokes)
        needsDisplay = true

        guard registersUndo, let manager = undoManager ?? window?.undoManager else { return }
        registeredUndoManager = manager
        manager.registerUndo(withTarget: self) { target in
            target.insertStroke(stroke, at: index, registersUndo: true)
        }
        manager.setActionName("Brush Stroke")
    }

    private func sample(from event: NSEvent) -> PointerSample {
        let rawPressure = event.pressure
        let pressure = rawPressure > 0 ? max(0.08, Double(rawPressure)) : 0.62
        let point = convert(event.locationInWindow, from: nil)
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let visibleX = min(max(Double(point.x / width), 0), 1)
        let normalizedX = isMirrored ? 1 - visibleX : visibleX
        let normalizedY = min(max(Double(point.y / height), 0), 1)
        let phase: PointerPhase
        switch event.type {
        case .leftMouseDown:
            phase = .began
        case .leftMouseUp:
            phase = .ended
        default:
            phase = .moved
        }
        return PointerSample(
            location: CanvasPoint(x: normalizedX, y: normalizedY),
            timestamp: event.timestamp,
            pressure: min(pressure, 1),
            phase: phase,
            device: event.subtype == .tabletPoint ? .stylus : .mouse
        )
    }
}

/// Lightweight persisted-stroke renderer used by filmstrip previews.
struct StudioBrushStrokeOverlay: View {
    let strokes: [StudioBrushStroke]

    var body: some View {
        Canvas { context, size in
            for stroke in strokes {
                for dab in StudioBrushRendering.dabs(for: stroke, size: size) {
                    let radius = max(0.4, dab.diameter / 2)
                    context.fill(
                        Path(
                            ellipseIn: CGRect(
                                x: dab.x - radius,
                                y: dab.y - radius,
                                width: radius * 2,
                                height: radius * 2
                            )
                        ),
                        with: .color(
                            Color(nsColor: .macOSPaintCoral)
                                .opacity(dab.opacity)
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum StudioBrushRendering {
    static func dabs(
        for stroke: StudioBrushStroke,
        size: CGSize,
        isMirrored: Bool = false
    ) -> [BrushDab] {
        let width = max(Double(size.width), 1)
        let height = max(Double(size.height), 1)
        let samples = stroke.samples.map { sample in
            var mapped = sample
            let normalizedX = isMirrored
                ? 1 - sample.location.x
                : sample.location.x
            mapped.location = CanvasPoint(
                x: normalizedX * width,
                y: sample.location.y * height
            )
            return mapped
        }

        guard
            let settings = try? BrushSamplingSettings(
                diameter: max(stroke.normalizedDiameter * min(width, height), 0.8),
                spacing: 0.08,
                opacity: stroke.opacity,
                stabilization: 0.22
            )
        else {
            return []
        }
        return PressureBrushSampler.sampleStroke(samples, settings: settings)
    }

    static func draw(
        _ strokes: [StudioBrushStroke],
        in context: CGContext,
        size: CGSize,
        hasTopLeftOrigin: Bool,
        isMirrored: Bool = false
    ) {
        for stroke in strokes {
            for dab in dabs(for: stroke, size: size, isMirrored: isMirrored) {
                let radius = max(0.4, dab.diameter / 2)
                let y = hasTopLeftOrigin
                    ? dab.y
                    : Double(size.height) - dab.y
                context.setFillColor(
                    NSColor.macOSPaintCoral
                        .withAlphaComponent(dab.opacity)
                        .cgColor
                )
                context.fillEllipse(
                    in: CGRect(
                        x: dab.x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                )
            }
        }
    }
}
