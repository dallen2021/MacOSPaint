import AppKit
import Foundation
import PaintEngine
import PaintIO
import PaintModel
import SwiftUI
import UniformTypeIdentifiers

enum StudioWorkspace: String, CaseIterable, Identifiable {
    case essentials = "Essentials"
    case painting = "Painting"
    case vector = "Vector"
    case photo = "Photo"

    var id: String { rawValue }
}

enum StudioInspectorMode: String, CaseIterable, Identifiable {
    case layers = "Layers"
    case objects = "Objects"

    var id: String { rawValue }
}

enum StudioPropertyMode: String, CaseIterable, Identifiable {
    case properties = "Properties"
    case color = "Color"

    var id: String { rawValue }
}

enum StudioToolID: String, CaseIterable, Identifiable, Hashable {
    case objectSelect
    case directSelect
    case marqueeRectangle
    case marqueeEllipse
    case lasso
    case polygonLasso
    case magicWand
    case crop
    case text
    case rectangle
    case ellipse
    case pen
    case pencil
    case brush
    case eraser
    case fill
    case gradient
    case eyedropper
    case cloneStamp
    case spotHeal
    case blur
    case sharpen
    case smudge
    case hand
    case zoom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .objectSelect: "Object Select"
        case .directSelect: "Direct Select"
        case .marqueeRectangle: "Rectangular Marquee"
        case .marqueeEllipse: "Elliptical Marquee"
        case .lasso: "Freehand Lasso"
        case .polygonLasso: "Polygon Lasso"
        case .magicWand: "Magic Wand"
        case .crop: "Crop"
        case .text: "Text"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .pen: "Pen"
        case .pencil: "Pencil"
        case .brush: "Brush"
        case .eraser: "Eraser"
        case .fill: "Fill"
        case .gradient: "Gradient"
        case .eyedropper: "Eyedropper"
        case .cloneStamp: "Clone Stamp"
        case .spotHeal: "Spot Heal"
        case .blur: "Blur"
        case .sharpen: "Sharpen"
        case .smudge: "Smudge"
        case .hand: "Hand"
        case .zoom: "Zoom"
        }
    }

    var symbol: String {
        switch self {
        case .objectSelect: "cursorarrow"
        case .directSelect: "cursorarrow.rays"
        case .marqueeRectangle: "rectangle.dashed"
        case .marqueeEllipse: "circle.dashed"
        case .lasso: "lasso"
        case .polygonLasso: "point.3.connected.trianglepath.dotted"
        case .magicWand: "wand.and.stars"
        case .crop: "crop"
        case .text: "textformat"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .pen: "pencil.tip"
        case .pencil: "pencil"
        case .brush: "paintbrush.pointed"
        case .eraser: "eraser"
        case .fill: "paintbrush.fill"
        case .gradient: "circle.lefthalf.filled"
        case .eyedropper: "eyedropper"
        case .cloneStamp: "person.crop.rectangle.badge.plus"
        case .spotHeal: "bandage"
        case .blur: "drop"
        case .sharpen: "triangle"
        case .smudge: "hand.draw"
        case .hand: "hand.raised"
        case .zoom: "magnifyingglass"
        }
    }

    var keyEquivalent: KeyEquivalent? {
        switch self {
        case .objectSelect: "v"
        case .text: "t"
        case .pen: "p"
        case .pencil: "n"
        case .brush: "b"
        case .eraser: "e"
        case .fill: "g"
        case .eyedropper: "i"
        case .crop: "c"
        case .hand: "h"
        case .zoom: "z"
        default: nil
        }
    }

    var acceptsBrushInput: Bool {
        self == .brush || self == .pencil
    }
}

enum PinnedActionID: String, CaseIterable, Identifiable, Codable, Hashable {
    case gouacheBrush
    case selectSubject
    case crop169
    case removeBackground
    case exportPNG
    case stabilizeBrush
    case mirrorCanvas
    case fitCanvas
    case snapToGrid
    case alignCenters
    case booleanUnion
    case exportSVG
    case invertSelection
    case beforeAfter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gouacheBrush: "Gouache"
        case .selectSubject: "Select Subject"
        case .crop169: "Crop"
        case .removeBackground: "Remove BG"
        case .exportPNG: "Export PNG"
        case .stabilizeBrush: "Stabilizer"
        case .mirrorCanvas: "Mirror Canvas"
        case .fitCanvas: "Fit Canvas"
        case .snapToGrid: "Snap to Grid"
        case .alignCenters: "Align Centers"
        case .booleanUnion: "Union"
        case .exportSVG: "Export SVG"
        case .invertSelection: "Invert Select"
        case .beforeAfter: "Before / After"
        }
    }

    var detail: String? {
        switch self {
        case .gouacheBrush: "24 px"
        case .crop169: "16:9"
        default: nil
        }
    }

    var symbol: String {
        switch self {
        case .gouacheBrush: "paintbrush.pointed.fill"
        case .selectSubject: "person.crop.circle.dashed"
        case .crop169: "crop"
        case .removeBackground: "checkerboard.rectangle"
        case .exportPNG: "doc.badge.arrow.up"
        case .stabilizeBrush: "waveform.path"
        case .mirrorCanvas: "arrow.left.and.right.righttriangle.left.righttriangle.right"
        case .fitCanvas: "arrow.up.left.and.arrow.down.right"
        case .snapToGrid: "grid"
        case .alignCenters: "align.horizontal.center"
        case .booleanUnion: "square.on.circle"
        case .exportSVG: "square.and.arrow.up"
        case .invertSelection: "circle.lefthalf.filled.inverse"
        case .beforeAfter: "square.split.2x1"
        }
    }
}

enum PinnedShelfItem: Identifiable, Hashable {
    case tool(StudioToolID)
    case action(PinnedActionID)

    var id: String {
        switch self {
        case let .tool(tool):
            "tool:\(tool.rawValue)"
        case let .action(action):
            "action:\(action.rawValue)"
        }
    }

    var title: String {
        switch self {
        case let .tool(tool):
            tool.title
        case let .action(action):
            action.title
        }
    }

    var detail: String? {
        switch self {
        case .tool:
            nil
        case let .action(action):
            action.detail
        }
    }

    var symbol: String {
        switch self {
        case let .tool(tool):
            tool.symbol
        case let .action(action):
            action.symbol
        }
    }

    var tool: StudioToolID? {
        guard case let .tool(tool) = self else { return nil }
        return tool
    }
}

struct StudioLayerItem: Identifiable {
    let id: UUID
    var name: String
    var symbol: String
    var isVisible: Bool
    var isExpandable: Bool
    var swatch: Color?
    var isPreviewVisibilityAvailable: Bool
    var isRaster: Bool

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        isVisible: Bool = true,
        isExpandable: Bool = false,
        swatch: Color? = nil,
        isPreviewVisibilityAvailable: Bool = false,
        isRaster: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.isVisible = isVisible
        self.isExpandable = isExpandable
        self.swatch = swatch
        self.isPreviewVisibilityAvailable = isPreviewVisibilityAvailable
        self.isRaster = isRaster
            ?? (!isExpandable && symbol != "textformat")
    }
}

struct StudioArtboard: Identifiable {
    let id: UUID
    var name: String
    var pixelWidth: Int
    var pixelHeight: Int
    var assetName: String
    var background: RGBAColor
    var layers: [StudioLayerItem]

    var aspectRatio: CGFloat {
        CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }

    var previewAssetName: String {
        assetName
    }

    var isIllustrationVisible: Bool {
        layers.first(where: { $0.name == "Illustration" })?.isVisible ?? true
    }

    var areBrushStrokesVisible: Bool {
        if let paintLayer = layers.first(where: { $0.name == "Paint Layer" }) {
            return paintLayer.isVisible
        }
        return true
    }
}

struct StudioRasterTilePresentation: Identifiable {
    let key: RasterTileKey
    let tile: RasterTile
    let opacity: Double
    let blendMode: PaintModel.BlendMode

    var id: RasterTileKey { key }
}

enum StudioRasterTileImages {
    static func cgImage(for tile: RasterTile) -> CGImage? {
        guard let provider = CGDataProvider(data: tile.bytes as CFData) else {
            return nil
        }
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )
        return CGImage(
            width: RasterTileStore.tileSize,
            height: RasterTileStore.tileSize,
            bitsPerComponent: 8,
            bitsPerPixel: RasterTile.bytesPerPixel * 8,
            bytesPerRow: RasterTileStore.tileSize * RasterTile.bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

struct StudioNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum StudioExportError: LocalizedError {
    case invalidArtboardDimensions
    case couldNotCreateBitmap
    case previewResourceUnavailable
    case couldNotEncodePNG

    var errorDescription: String? {
        switch self {
        case .invalidArtboardDimensions:
            "The selected artboard has invalid dimensions."
        case .couldNotCreateBitmap:
            "A full-resolution export canvas could not be created."
        case .previewResourceUnavailable:
            "The selected artboard preview resource could not be opened."
        case .couldNotEncodePNG:
            "The rendered artboard could not be encoded as PNG."
        }
    }
}

private enum StudioLoadError: LocalizedError {
    case projectHasNoArtboards

    var errorDescription: String? {
        switch self {
        case .projectHasNoArtboards:
            "This project does not contain an artboard that can be opened."
        }
    }
}

@MainActor
final class StudioState: ObservableObject {
    @Published var selectedTool: StudioToolID = .objectSelect
    @Published var selectedArtboardID: UUID
    @Published var selectedLayerID: UUID?
    @Published var workspace: StudioWorkspace = .essentials {
        didSet {
            syncWorkspaceToProject()
        }
    }
    @Published var inspectorMode: StudioInspectorMode = .layers
    @Published var propertyMode: StudioPropertyMode = .properties
    @Published var synchronizedZoom = true
    @Published var primaryZoom = 0.63
    @Published var secondaryZoom = 0.63
    @Published var appearance: StudioAppearance
    @Published var brushSize: Double = 24
    @Published var brushOpacity: Double = 1
    @Published var isCanvasMirrored = false
    @Published var selectedTextAlignmentSymbol = "text.aligncenter"
    @Published var notice: StudioNotice?
    @Published private(set) var artboards: [StudioArtboard]
    @Published private var brushStrokesByArtboard: [UUID: [StudioBrushStroke]] = [:]
    @Published private var pinnedByWorkspace: [StudioWorkspace: [PinnedShelfItem]]
    @Published private(set) var projectManifest: ProjectManifestV1
    @Published private(set) var persistedRasterTiles: RasterTileSnapshot

    var projectID: UUID { projectManifest.projectID }
    private(set) var rasterTileStore: RasterTileStore
    let projectPackageStore = ProjectPackageStore()
    private var rasterCompositionBase: RasterTileSnapshot
    private var isHydratingProject = false

    init() {
        let landscapeLayers = Self.makeDemoLayers(startingAt: 100)
        let squareLayers = Self.makeDemoLayers(startingAt: 200)
        let storyLayers = Self.makeDemoLayers(startingAt: 300)
        let headlineID = squareLayers[0].id

        let landscape = StudioArtboard(
            id: UUID(uuidString: "E03F0AFD-61AC-48CE-9F3B-1D9939755FB0")!,
            name: "Landscape Hero",
            pixelWidth: 1920,
            pixelHeight: 1080,
            assetName: "coastal-landscape",
            background: RGBAColor(red: 0.96, green: 0.91, blue: 0.81),
            layers: landscapeLayers
        )
        let square = StudioArtboard(
            id: UUID(uuidString: "1F85AD9E-BC76-4AE5-8E2A-B122121CC281")!,
            name: "Social Square",
            pixelWidth: 1080,
            pixelHeight: 1080,
            assetName: "coastal-square-final",
            background: RGBAColor(red: 0.96, green: 0.91, blue: 0.81),
            layers: squareLayers
        )
        let story = StudioArtboard(
            id: UUID(uuidString: "3C88A6E8-E10A-4134-8F66-B3505694E72D")!,
            name: "Story Vertical",
            pixelWidth: 1080,
            pixelHeight: 1920,
            assetName: "coastal-story",
            background: RGBAColor(red: 0.96, green: 0.91, blue: 0.81),
            layers: storyLayers
        )

        let seededArtboards = [landscape, square, story]
        artboards = seededArtboards
        selectedArtboardID = square.id
        selectedLayerID = headlineID

        pinnedByWorkspace = Self.defaultPinnedShelfItems

        let savedAppearance = UserDefaults.standard.string(forKey: "studioAppearance")
        appearance = StudioAppearance(rawValue: savedAppearance ?? "") ?? .system
        let emptyRasterSnapshot = RasterTileSnapshot(generation: 0, tiles: [:])
        persistedRasterTiles = emptyRasterSnapshot
        rasterCompositionBase = emptyRasterSnapshot
        rasterTileStore = RasterTileStore(snapshot: emptyRasterSnapshot)

        projectManifest = Self.makeProject(
            id: UUID(uuidString: "C430626F-DC02-48A1-A10C-1522F2ED2A5D")!,
            artboards: seededArtboards,
            workspace: .essentials
        )
    }

    init(contents: ProjectPackageContents) throws {
        try contents.manifest.validate()
        guard !contents.manifest.artboards.isEmpty else {
            throw StudioLoadError.projectHasNoArtboards
        }

        let hydratedArtboards = Self.makeStudioArtboards(
            from: contents.manifest
        )
        artboards = hydratedArtboards
        selectedArtboardID = hydratedArtboards[0].id
        selectedLayerID = hydratedArtboards[0].layers.first?.id

        let hydratedWorkspace = StudioWorkspace(
            preset: contents.manifest.workspace.preset
        )
        var hydratedPinnedItems = Self.defaultPinnedShelfItems
        hydratedPinnedItems[hydratedWorkspace] = Self.pinnedShelfItems(
            for: contents.manifest.workspace,
            workspace: hydratedWorkspace
        )
        pinnedByWorkspace = hydratedPinnedItems

        let savedAppearance = UserDefaults.standard.string(forKey: "studioAppearance")
        appearance = StudioAppearance(rawValue: savedAppearance ?? "") ?? .system
        projectManifest = contents.manifest
        persistedRasterTiles = contents.rasterTiles
        rasterCompositionBase = contents.rasterTiles
        rasterTileStore = RasterTileStore(snapshot: contents.rasterTiles)
        workspace = hydratedWorkspace
    }

    var selectedArtboard: StudioArtboard {
        artboards.first(where: { $0.id == selectedArtboardID }) ?? artboards[0]
    }

    var selectedLayer: StudioLayerItem? {
        selectedArtboard.layers.first(where: { $0.id == selectedLayerID })
    }

    var canPaintSelectedArtboard: Bool {
        selectedLayer?.name == "Paint Layer"
            && selectedLayer?.isPreviewVisibilityAvailable == true
            && selectedLayer?.isVisible == true
    }

    var canvasArtboards: [StudioArtboard] {
        let primary = artboards[0]
        guard artboards.count > 1 else {
            return [primary]
        }
        if selectedArtboardID == primary.id {
            return [primary, artboards[1]]
        }
        return [primary, selectedArtboard]
    }

    var pinnedShelfItems: [PinnedShelfItem] {
        pinnedByWorkspace[workspace] ?? []
    }

    var canvasTool: CanvasTool {
        selectedTool.canvasTool
    }

    var toolContext: ToolContext {
        ToolContext(
            artboardID: selectedArtboardID,
            layerID: selectedLayerID,
            tool: canvasTool,
            zoomScale: secondaryZoom,
            primaryColor: RGBAColor(red: 0.02, green: 0.30, blue: 0.36),
            secondaryColor: RGBAColor(red: 0.96, green: 0.91, blue: 0.81),
            brush: BrushSettings(
                diameter: brushSize,
                opacity: brushOpacity,
                stabilization: 0.25,
                usesPressureForSize: true
            )
        )
    }

    func selectArtboard(_ id: UUID) {
        guard let artboard = artboards.first(where: { $0.id == id }) else { return }
        selectedArtboardID = id
        selectedLayerID = artboard.layers.first?.id
        if selectedTool.acceptsBrushInput {
            ensurePaintLayerSelected()
        }
    }

    func selectTool(_ tool: StudioToolID) {
        selectedTool = tool
        if tool.acceptsBrushInput {
            ensurePaintLayerSelected()
        }
    }

    func openProject(at url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let accessedSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if accessedSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let result = try await projectPackageStore.open(at: url)
                switch result {
                case let .editable(contents):
                    try load(contents: contents)
                    showNotice(
                        title: "Project opened",
                        message: contents.manifest.title
                    )
                case let .readOnly(package):
                    throw ProjectPackageError.newerSchemaIsReadOnly(
                        found: package.schemaVersion,
                        supported: ProjectPackageStore.supportedSchemaVersion
                    )
                }
            } catch {
                showNotice(
                    title: "Open failed",
                    message: error.localizedDescription
                )
            }
        }
    }

    func load(contents: ProjectPackageContents) throws {
        try contents.manifest.validate()
        let hydratedArtboards = Self.makeStudioArtboards(
            from: contents.manifest
        )
        guard let firstArtboard = hydratedArtboards.first else {
            throw StudioLoadError.projectHasNoArtboards
        }

        let hydratedWorkspace = StudioWorkspace(
            preset: contents.manifest.workspace.preset
        )
        var hydratedPinnedItems = Self.defaultPinnedShelfItems
        hydratedPinnedItems[hydratedWorkspace] = Self.pinnedShelfItems(
            for: contents.manifest.workspace,
            workspace: hydratedWorkspace
        )

        isHydratingProject = true
        projectManifest = contents.manifest
        artboards = hydratedArtboards
        selectedArtboardID = firstArtboard.id
        selectedLayerID = firstArtboard.layers.first?.id
        brushStrokesByArtboard.removeAll(keepingCapacity: false)
        pinnedByWorkspace = hydratedPinnedItems
        workspace = hydratedWorkspace
        selectedTool = .objectSelect
        isCanvasMirrored = false
        rasterCompositionBase = contents.rasterTiles
        persistedRasterTiles = contents.rasterTiles
        rasterTileStore = RasterTileStore(snapshot: contents.rasterTiles)
        isHydratingProject = false
    }

    func setAppearance(_ newValue: StudioAppearance) {
        appearance = newValue
        UserDefaults.standard.set(newValue.rawValue, forKey: "studioAppearance")
    }

    func setZoom(_ value: Double, for artboardID: UUID? = nil) {
        let clamped = min(max(value, 0.10), 4)
        if synchronizedZoom {
            primaryZoom = clamped
            secondaryZoom = clamped
        } else if artboardID == artboards.first?.id {
            primaryZoom = clamped
        } else {
            secondaryZoom = clamped
        }
    }

    func stepZoom(_ direction: Double) {
        setZoom(secondaryZoom + direction)
    }

    func toggleLayerVisibility(_ layerID: UUID) {
        guard
            let artboardIndex = artboards.firstIndex(where: { $0.id == selectedArtboardID }),
            let layerIndex = artboards[artboardIndex].layers.firstIndex(where: { $0.id == layerID })
        else {
            return
        }
        guard artboards[artboardIndex].layers[layerIndex].isPreviewVisibilityAvailable else {
            showNotice(
                title: "Flattened sample layer",
                message: "This generated sample is read-only at that layer. New native documents keep raster, vector, and text content independently editable."
            )
            return
        }
        artboards[artboardIndex].layers[layerIndex].isVisible.toggle()
        syncArtboardToProject(artboardIndex)
    }

    func deleteSelectedLayer() {
        guard
            let selectedLayerID,
            let artboardIndex = artboards.firstIndex(where: { $0.id == selectedArtboardID }),
            let layerIndex = artboards[artboardIndex].layers.firstIndex(
                where: { $0.id == selectedLayerID }
            )
        else {
            return
        }
        let layer = artboards[artboardIndex].layers[layerIndex]
        guard layer.isPreviewVisibilityAvailable else {
            showNotice(
                title: "Flattened sample layer",
                message: "The bundled campaign preview is read-only. Add a Paint Layer to create editable content."
            )
            return
        }
        if layer.name == "Paint Layer" {
            brushStrokesByArtboard.removeValue(forKey: selectedArtboardID)
        }
        artboards[artboardIndex].layers.remove(at: layerIndex)
        self.selectedLayerID = artboards[artboardIndex].layers.first?.id
        syncArtboardToProject(artboardIndex)
    }

    func duplicateSelectedLayer() {
        showNotice(
            title: "Duplicate Layer",
            message: "Layer duplication is reserved for the editor-completion milestone."
        )
    }

    func addLayer() {
        guard let artboardIndex = artboards.firstIndex(where: { $0.id == selectedArtboardID }) else {
            return
        }
        if let existing = artboards[artboardIndex].layers.first(
            where: { $0.name == "Paint Layer" }
        ) {
            selectedLayerID = existing.id
            return
        }
        let layer = StudioLayerItem(
            name: "Paint Layer",
            symbol: "paintbrush.pointed",
            isPreviewVisibilityAvailable: true
        )
        artboards[artboardIndex].layers.insert(layer, at: 0)
        selectedLayerID = layer.id
        syncArtboardToProject(artboardIndex)
    }

    private func ensurePaintLayerSelected() {
        addLayer()
    }

    func addArtboard() {
        let source = selectedArtboard
        let copiedLayers = source.layers.map {
            StudioLayerItem(
                name: $0.name,
                symbol: $0.symbol,
                isVisible: $0.isVisible,
                isExpandable: $0.isExpandable,
                swatch: $0.swatch,
                isPreviewVisibilityAvailable: $0.isPreviewVisibilityAvailable,
                isRaster: $0.isRaster
            )
        }
        let copyNumber = artboards.count + 1
        let copy = StudioArtboard(
            id: UUID(),
            name: "\(source.name) \(copyNumber)",
            pixelWidth: source.pixelWidth,
            pixelHeight: source.pixelHeight,
            assetName: source.assetName,
            background: source.background,
            layers: copiedLayers
        )
        artboards.append(copy)
        brushStrokesByArtboard[copy.id] = brushStrokes(for: source.id).map {
            $0.copied(to: copy.id)
        }
        selectedArtboardID = copy.id
        selectedLayerID = copy.layers.first?.id

        let modelLayers = copiedLayers.map(Self.makeLayer)
        projectManifest.artboards.append(
            ArtboardRecord(
                id: copy.id,
                name: copy.name,
                frame: CanvasRect(
                    x: Double(2_080 + artboards.count * 80),
                    y: 160,
                    width: Double(copy.pixelWidth),
                    height: Double(copy.pixelHeight)
                ),
                pixelWidth: copy.pixelWidth,
                pixelHeight: copy.pixelHeight,
                dpi: 72,
                background: copy.background,
                rootLayerIDs: modelLayers.map(\.id),
                layers: modelLayers
            )
        )
        projectManifest.modifiedAt = Date()
    }

    func showNotice(title: String, message: String) {
        notice = StudioNotice(title: title, message: message)
    }

    func brushStrokes(for artboardID: UUID) -> [StudioBrushStroke] {
        brushStrokesByArtboard[artboardID] ?? []
    }

    func setBrushStrokes(
        _ strokes: [StudioBrushStroke],
        for artboardID: UUID
    ) {
        guard artboards.contains(where: { $0.id == artboardID }) else { return }
        let ownedStrokes = strokes.filter { $0.artboardID == artboardID }
        if ownedStrokes.isEmpty {
            brushStrokesByArtboard.removeValue(forKey: artboardID)
        } else {
            brushStrokesByArtboard[artboardID] = ownedStrokes
        }
        projectManifest.modifiedAt = Date()
    }

    func rasterTilePresentations(
        for artboardID: UUID
    ) -> [StudioRasterTilePresentation] {
        guard
            let artboard = projectManifest.artboard(id: artboardID)
        else {
            return []
        }

        let modelLayers = Dictionary(
            uniqueKeysWithValues: artboard.layers.map { ($0.id, $0) }
        )
        var visibleLayerIDs: Set<UUID> = []
        func collectVisibleRasterLayers(
            _ layerID: UUID,
            parentIsVisible: Bool
        ) {
            guard let layer = modelLayers[layerID] else { return }
            let isVisible = parentIsVisible && layer.isVisible
            switch layer.kind {
            case .raster:
                if isVisible {
                    visibleLayerIDs.insert(layer.id)
                }
            case let .group(group):
                for childLayerID in group.childLayerIDs {
                    collectVisibleRasterLayers(
                        childLayerID,
                        parentIsVisible: isVisible
                    )
                }
            case .vector, .text:
                break
            }
        }
        for rootLayerID in artboard.rootLayerIDs {
            collectVisibleRasterLayers(
                rootLayerID,
                parentIsVisible: true
            )
        }
        guard !visibleLayerIDs.isEmpty else { return [] }

        let layerOrder = Dictionary(
            uniqueKeysWithValues: artboard.layers.enumerated().map {
                ($0.element.id, $0.offset)
            }
        )

        return persistedRasterTiles.orderedKeys.compactMap {
            key -> StudioRasterTilePresentation? in
            guard
                visibleLayerIDs.contains(key.layerID),
                let tile = persistedRasterTiles[key],
                let layer = modelLayers[key.layerID]
            else {
                return nil
            }
            return StudioRasterTilePresentation(
                key: key,
                tile: tile,
                opacity: layer.opacity,
                blendMode: layer.blendMode
            )
        }
        .sorted { lhs, rhs in
            let lhsLayer = layerOrder[lhs.key.layerID] ?? 0
            let rhsLayer = layerOrder[rhs.key.layerID] ?? 0
            if lhsLayer != rhsLayer {
                // Layer records are stored front-to-back, so paint the back
                // layers first and the front layers last.
                return lhsLayer > rhsLayer
            }
            return lhs.key < rhs.key
        }
    }

    func exportSelectedArtboardPNG() {
        let artboard = selectedArtboard
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue =
            "\(artboard.name.replacingOccurrences(of: " ", with: "-")).png"
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        do {
            let data = try renderedPNGData(for: artboard)
            try data.write(to: destinationURL, options: .atomic)
            showNotice(
                title: "PNG exported",
                message: destinationURL.lastPathComponent
            )
        } catch {
            showNotice(
                title: "Export failed",
                message: error.localizedDescription
            )
        }
    }

    func saveProjectWithPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [
            UTType(
                exportedAs: "io.github.dallen2021.macospaint.project",
                conformingTo: .package
            )
        ]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue =
            "\(projectManifest.title.replacingOccurrences(of: " ", with: "-")).macospaint"
        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await saveProject(to: destinationURL)
                showNotice(
                    title: "Project saved",
                    message: destinationURL.lastPathComponent
                )
            } catch {
                showNotice(
                    title: "Save failed",
                    message: error.localizedDescription
                )
            }
        }
    }

    func isPinned(_ item: PinnedShelfItem) -> Bool {
        pinnedShelfItems.contains(item)
    }

    func togglePinned(_ item: PinnedShelfItem) {
        var items = pinnedShelfItems
        if let index = items.firstIndex(of: item) {
            items.remove(at: index)
        } else {
            items.append(item)
        }
        pinnedByWorkspace[workspace] = items
        syncPinnedToolsToProject(items)
    }

    func movePinned(_ item: PinnedShelfItem, by offset: Int) {
        var items = pinnedShelfItems
        guard let source = items.firstIndex(of: item) else { return }
        let destination = min(max(source + offset, 0), items.count - 1)
        guard source != destination else { return }
        items.remove(at: source)
        items.insert(item, at: destination)
        pinnedByWorkspace[workspace] = items
        syncPinnedToolsToProject(items)
    }

    func performPinnedShelfItem(_ item: PinnedShelfItem) {
        switch item {
        case let .tool(tool):
            selectTool(tool)
        case let .action(action):
            performPinnedAction(action)
        }
    }

    func performPinnedAction(_ action: PinnedActionID) {
        switch action {
        case .gouacheBrush:
            selectTool(.brush)
            brushSize = 24
        case .crop169:
            selectedTool = .crop
        case .fitCanvas:
            setZoom(0.63)
        case .exportPNG:
            exportSelectedArtboardPNG()
        case .mirrorCanvas:
            isCanvasMirrored.toggle()
        case .selectSubject:
            selectedTool = .objectSelect
            showNotice(
                title: "Select Subject",
                message: "The on-device Vision adapter is scaffolded and scheduled for the editor-completion milestone."
            )
        case .removeBackground:
            showNotice(
                title: "Remove Background",
                message: "Background removal will run locally through Apple Vision in the editor-completion milestone; no upload fallback is used."
            )
        case .invertSelection:
            selectedTool = .objectSelect
            showNotice(
                title: "Invert Selection",
                message: "Selection transactions are part of the next editor-completion milestone."
            )
        case .stabilizeBrush:
            selectTool(.brush)
            showNotice(
                title: "Brush stabilizer enabled",
                message: "The pressure sampler uses deterministic stabilization in this vertical slice."
            )
        case .snapToGrid, .alignCenters, .booleanUnion, .exportSVG, .beforeAfter:
            showNotice(
                title: action.title,
                message: "This command has a typed engine seam and is scheduled for editor completion."
            )
        }
    }

    func packageContents() async throws -> ProjectPackageContents {
        try await commitBrushStrokesToRasterStore()
        return ProjectPackageContents(
            manifest: projectManifest,
            rasterTiles: await rasterTileStore.snapshot()
        )
    }

    func saveProject(to url: URL) async throws {
        let saved = try await projectPackageStore.save(
            try await packageContents(),
            to: url
        )
        projectManifest = saved.manifest
    }

    private func commitBrushStrokesToRasterStore() async throws {
        let before = await rasterTileStore.snapshot()
        let currentRasterLayerIDs = Set(
            projectManifest.artboards.flatMap(\.layers).compactMap { layer in
                if case .raster = layer.kind {
                    return layer.id
                }
                return nil
            }
        )

        let orphanMutations = before.orderedKeys
            .filter { !currentRasterLayerIDs.contains($0.layerID) }
            .map { RasterTileMutation(key: $0, replacement: nil) }
        if !orphanMutations.isEmpty, let artboardID = projectManifest.artboards.first?.id {
            _ = try await rasterTileStore.apply(
                orphanMutations,
                artboardID: artboardID
            )
        }

        for artboard in artboards {
            guard let paintLayer = artboard.layers.first(
                where: { $0.name == "Paint Layer" }
            ) else {
                continue
            }
            let desired = try Self.rasterizedBrushTiles(
                brushStrokes(for: artboard.id),
                artboard: artboard,
                layerID: paintLayer.id
            )
            let existingKeys = before.orderedKeys.filter {
                $0.layerID == paintLayer.id
            }
            let baseKeys = rasterCompositionBase.orderedKeys.filter {
                $0.layerID == paintLayer.id
            }
            let allKeys = Set(existingKeys)
                .union(baseKeys)
                .union(desired.keys)
            let mutations = try allKeys.sorted().map { key in
                let replacement = try Self.composite(
                    base: rasterCompositionBase[key],
                    overlay: desired[key]
                )
                return RasterTileMutation(
                    key: key,
                    replacement: replacement
                )
            }
            if !mutations.isEmpty {
                _ = try await rasterTileStore.apply(
                    mutations,
                    artboardID: artboard.id
                )
            }
        }
    }

    private static func composite(
        base: RasterTile?,
        overlay: RasterTile?
    ) throws -> RasterTile? {
        guard let overlay else { return base }
        guard let base else { return overlay }

        var composed = base.bytes
        composed.withUnsafeMutableBytes { destinationRawBytes in
            overlay.bytes.withUnsafeBytes { sourceRawBytes in
                guard
                    let destination = destinationRawBytes.bindMemory(
                        to: UInt8.self
                    ).baseAddress,
                    let source = sourceRawBytes.bindMemory(
                        to: UInt8.self
                    ).baseAddress
                else {
                    return
                }

                var offset = 0
                while offset < RasterTile.byteCount {
                    let sourceAlpha = Int(source[offset + 3])
                    if sourceAlpha == 255 {
                        destination[offset] = source[offset]
                        destination[offset + 1] = source[offset + 1]
                        destination[offset + 2] = source[offset + 2]
                        destination[offset + 3] = 255
                    } else if sourceAlpha > 0 {
                        let inverseAlpha = 255 - sourceAlpha
                        destination[offset] = UInt8(
                            min(
                                255,
                                Int(source[offset])
                                    + (Int(destination[offset]) * inverseAlpha + 127) / 255
                            )
                        )
                        destination[offset + 1] = UInt8(
                            min(
                                255,
                                Int(source[offset + 1])
                                    + (Int(destination[offset + 1]) * inverseAlpha + 127) / 255
                            )
                        )
                        destination[offset + 2] = UInt8(
                            min(
                                255,
                                Int(source[offset + 2])
                                    + (Int(destination[offset + 2]) * inverseAlpha + 127) / 255
                            )
                        )
                        destination[offset + 3] = UInt8(
                            min(
                                255,
                                sourceAlpha
                                    + (Int(destination[offset + 3]) * inverseAlpha + 127) / 255
                            )
                        )
                    }
                    offset += RasterTile.bytesPerPixel
                }
            }
        }
        let tile = try RasterTile(bytes: composed)
        return tile.isFullyTransparent ? nil : tile
    }

    private static func rasterizedBrushTiles(
        _ strokes: [StudioBrushStroke],
        artboard: StudioArtboard,
        layerID: UUID
    ) throws -> [RasterTileKey: RasterTile] {
        guard artboard.pixelWidth > 0, artboard.pixelHeight > 0 else {
            throw StudioExportError.invalidArtboardDimensions
        }

        let size = CGSize(
            width: artboard.pixelWidth,
            height: artboard.pixelHeight
        )
        let maximumTileX = (artboard.pixelWidth - 1) / RasterTileStore.tileSize
        let maximumTileY = (artboard.pixelHeight - 1) / RasterTileStore.tileSize
        var dabsByCoordinate: [TileCoordinate: [BrushDab]] = [:]

        for stroke in strokes {
            for dab in StudioBrushRendering.dabs(for: stroke, size: size) {
                let radius = max(0.4, dab.diameter / 2)
                let minimumX = max(0, Int(floor(dab.x - radius)))
                let maximumX = min(
                    artboard.pixelWidth - 1,
                    Int(ceil(dab.x + radius))
                )
                let minimumY = max(0, Int(floor(dab.y - radius)))
                let maximumY = min(
                    artboard.pixelHeight - 1,
                    Int(ceil(dab.y + radius))
                )
                guard minimumX <= maximumX, minimumY <= maximumY else {
                    continue
                }
                let minimumTileX = min(
                    maximumTileX,
                    minimumX / RasterTileStore.tileSize
                )
                let endingTileX = min(
                    maximumTileX,
                    maximumX / RasterTileStore.tileSize
                )
                let minimumTileY = min(
                    maximumTileY,
                    minimumY / RasterTileStore.tileSize
                )
                let endingTileY = min(
                    maximumTileY,
                    maximumY / RasterTileStore.tileSize
                )
                for tileY in minimumTileY...endingTileY {
                    for tileX in minimumTileX...endingTileX {
                        dabsByCoordinate[
                            TileCoordinate(x: tileX, y: tileY),
                            default: []
                        ].append(dab)
                    }
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        )
        var result: [RasterTileKey: RasterTile] = [:]

        for (coordinate, dabs) in dabsByCoordinate {
            var bytes = Data(repeating: 0, count: RasterTile.byteCount)
            let contextWasCreated = bytes.withUnsafeMutableBytes { rawBytes -> Bool in
                guard let baseAddress = rawBytes.baseAddress,
                      let context = CGContext(
                          data: baseAddress,
                          width: RasterTileStore.tileSize,
                          height: RasterTileStore.tileSize,
                          bitsPerComponent: 8,
                          bytesPerRow: RasterTileStore.tileSize
                              * RasterTile.bytesPerPixel,
                          space: colorSpace,
                          bitmapInfo: bitmapInfo.rawValue
                      )
                else {
                    return false
                }

                context.clear(
                    CGRect(
                        x: 0,
                        y: 0,
                        width: RasterTileStore.tileSize,
                        height: RasterTileStore.tileSize
                    )
                )
                let tileOriginX =
                    Double(coordinate.x * RasterTileStore.tileSize)
                let tileOriginY =
                    Double(coordinate.y * RasterTileStore.tileSize)
                for dab in dabs {
                    let radius = max(0.4, dab.diameter / 2)
                    let localX = dab.x - tileOriginX
                    let localY = Double(RasterTileStore.tileSize)
                        - (dab.y - tileOriginY)
                    context.setFillColor(
                        NSColor.macOSPaintCoral
                            .withAlphaComponent(dab.opacity)
                            .cgColor
                    )
                    context.fillEllipse(
                        in: CGRect(
                            x: localX - radius,
                            y: localY - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                    )
                }
                context.flush()
                return true
            }
            guard contextWasCreated else {
                throw StudioExportError.couldNotCreateBitmap
            }
            let tile = try RasterTile(bytes: bytes)
            guard !tile.isFullyTransparent else { continue }
            result[
                RasterTileKey(
                    layerID: layerID,
                    coordinate: coordinate
                )
            ] = tile
        }
        return result
    }

    private func renderedPNGData(for artboard: StudioArtboard) throws -> Data {
        guard artboard.pixelWidth > 0, artboard.pixelHeight > 0 else {
            throw StudioExportError.invalidArtboardDimensions
        }
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: artboard.pixelWidth,
                pixelsHigh: artboard.pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            throw StudioExportError.couldNotCreateBitmap
        }

        let size = CGSize(
            width: artboard.pixelWidth,
            height: artboard.pixelHeight
        )
        let bounds = CGRect(origin: .zero, size: size)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high

        artboard.background.nsColor.setFill()
        bounds.fill()

        let context = graphicsContext.cgContext
        context.saveGState()
        if isCanvasMirrored {
            context.translateBy(x: size.width, y: 0)
            context.scaleBy(x: -1, y: 1)
        }

        if artboard.isIllustrationVisible, !artboard.assetName.isEmpty {
            guard let image = StudioAssets.image(named: artboard.previewAssetName) else {
                context.restoreGState()
                throw StudioExportError.previewResourceUnavailable
            }
            image.draw(
                in: bounds,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }

        try drawPersistedRasterTiles(
            for: artboard,
            in: context,
            canvasSize: size
        )

        if artboard.areBrushStrokesVisible {
            StudioBrushRendering.draw(
                brushStrokes(for: artboard.id),
                in: context,
                size: size,
                hasTopLeftOrigin: false
            )
        }
        context.restoreGState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw StudioExportError.couldNotEncodePNG
        }
        return data
    }

    private func drawPersistedRasterTiles(
        for artboard: StudioArtboard,
        in context: CGContext,
        canvasSize: CGSize
    ) throws {
        let tileSize = CGFloat(RasterTileStore.tileSize)
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(
            to: CGRect(origin: .zero, size: canvasSize)
        )

        for presentation in rasterTilePresentations(for: artboard.id) {
            guard let image = StudioRasterTileImages.cgImage(
                for: presentation.tile
            ) else {
                throw StudioExportError.couldNotCreateBitmap
            }
            let coordinate = presentation.key.coordinate
            let destination = CGRect(
                x: CGFloat(coordinate.x) * tileSize,
                y: canvasSize.height
                    - CGFloat(coordinate.y + 1) * tileSize,
                width: tileSize,
                height: tileSize
            )
            context.saveGState()
            context.setAlpha(presentation.opacity)
            context.setBlendMode(presentation.blendMode.cgBlendMode)
            context.draw(image, in: destination)
            context.restoreGState()
        }
    }

    private func syncWorkspaceToProject() {
        guard !isHydratingProject, !projectManifest.artboards.isEmpty else {
            return
        }
        projectManifest.workspace = workspace.modelDescriptor
        Self.persistPinnedShelfItems(
            pinnedShelfItems,
            in: &projectManifest.workspace
        )
        projectManifest.modifiedAt = Date()
    }

    private func syncPinnedToolsToProject(_ items: [PinnedShelfItem]) {
        Self.persistPinnedShelfItems(items, in: &projectManifest.workspace)
        projectManifest.modifiedAt = Date()
    }

    private func syncArtboardToProject(_ artboardIndex: Int) {
        guard projectManifest.artboards.indices.contains(artboardIndex) else { return }
        let studioArtboard = artboards[artboardIndex]
        let existingLayers = Dictionary(
            uniqueKeysWithValues: projectManifest.artboards[artboardIndex]
                .layers
                .map { ($0.id, $0) }
        )
        var modelLayers = studioArtboard.layers.map { studioLayer in
            guard var existing = existingLayers[studioLayer.id] else {
                return Self.makeLayer(studioLayer)
            }
            existing.name = studioLayer.name
            existing.isVisible = studioLayer.isVisible
            return existing
        }
        let modelLayerIDs = Set(modelLayers.map(\.id))
        modelLayers = modelLayers.map { layer in
            guard case var .group(group) = layer.kind else {
                return layer
            }
            var sanitized = layer
            group.childLayerIDs.removeAll { !modelLayerIDs.contains($0) }
            sanitized.kind = .group(group)
            return sanitized
        }
        let childLayerIDs = Set(
            modelLayers.flatMap { layer -> [UUID] in
                if case let .group(group) = layer.kind {
                    return group.childLayerIDs
                }
                return []
            }
        )
        let rootLayerIDs = modelLayers.map(\.id).filter {
            !childLayerIDs.contains($0)
        }
        projectManifest.artboards[artboardIndex].layers = modelLayers
        projectManifest.artboards[artboardIndex].rootLayerIDs = rootLayerIDs
        projectManifest.modifiedAt = Date()
    }

    private static let defaultPinnedShelfItems: [StudioWorkspace: [PinnedShelfItem]] = [
        .essentials: [
            .action(.gouacheBrush),
            .action(.selectSubject),
            .action(.crop169),
            .action(.removeBackground),
            .action(.exportPNG),
        ],
        .painting: [
            .action(.gouacheBrush),
            .action(.stabilizeBrush),
            .action(.mirrorCanvas),
            .action(.fitCanvas),
        ],
        .vector: [
            .action(.snapToGrid),
            .action(.alignCenters),
            .action(.booleanUnion),
            .action(.exportSVG),
        ],
        .photo: [
            .action(.selectSubject),
            .action(.crop169),
            .action(.removeBackground),
            .action(.beforeAfter),
            .action(.exportPNG),
        ],
    ]

    private static let demoProjectID =
        UUID(uuidString: "C430626F-DC02-48A1-A10C-1522F2ED2A5D")!

    private static func makeStudioArtboards(
        from manifest: ProjectManifestV1
    ) -> [StudioArtboard] {
        manifest.artboards.map { artboard in
            StudioArtboard(
                id: artboard.id,
                name: artboard.name,
                pixelWidth: artboard.pixelWidth,
                pixelHeight: artboard.pixelHeight,
                assetName: previewAssetName(
                    projectID: manifest.projectID,
                    artboard: artboard
                ),
                background: artboard.background,
                layers: artboard.layers.map {
                    makeStudioLayer(
                        $0,
                        isFlattenedDemoFixture:
                            manifest.projectID == demoProjectID
                                && $0.name != "Paint Layer"
                    )
                }
            )
        }
    }

    private static func makeStudioLayer(
        _ layer: LayerRecord,
        isFlattenedDemoFixture: Bool
    ) -> StudioLayerItem {
        let symbol: String
        let isExpandable: Bool
        let isRaster: Bool
        switch layer.kind {
        case .raster:
            symbol = layer.name == "Paint Layer"
                ? "paintbrush.pointed"
                : "rectangle.fill"
            isExpandable = false
            isRaster = true
        case .vector:
            symbol = "point.3.connected.trianglepath.dotted"
            isExpandable = false
            isRaster = false
        case .text:
            symbol = "textformat"
            isExpandable = false
            isRaster = false
        case .group:
            symbol = "folder"
            isExpandable = true
            isRaster = false
        }

        return StudioLayerItem(
            id: layer.id,
            name: layer.name,
            symbol: symbol,
            isVisible: layer.isVisible,
            isExpandable: isExpandable,
            isPreviewVisibilityAvailable:
                isRaster && !isFlattenedDemoFixture,
            isRaster: isRaster
        )
    }

    private static func previewAssetName(
        projectID: UUID,
        artboard: ArtboardRecord
    ) -> String {
        guard projectID == demoProjectID else { return "" }
        switch artboard.id {
        case UUID(uuidString: "E03F0AFD-61AC-48CE-9F3B-1D9939755FB0")!:
            return artboard.name == "Landscape Hero"
                ? "coastal-landscape"
                : ""
        case UUID(uuidString: "1F85AD9E-BC76-4AE5-8E2A-B122121CC281")!:
            return artboard.name == "Social Square"
                ? "coastal-square-final"
                : ""
        case UUID(uuidString: "3C88A6E8-E10A-4134-8F66-B3505694E72D")!:
            return artboard.name == "Story Vertical"
                ? "coastal-story"
                : ""
        default:
            return ""
        }
    }

    private static func pinnedShelfItems(
        for descriptor: WorkspaceDescriptor,
        workspace: StudioWorkspace
    ) -> [PinnedShelfItem] {
        if let exactItems = descriptor.pinnedItems {
            return exactItems.map(PinnedShelfItem.init)
        }

        let tools = descriptor.pinnedTools
        let defaults = defaultPinnedShelfItems[workspace] ?? []
        if tools == uniqueCanvasTools(for: defaults) {
            return defaults
        }

        return tools.map { tool in
            if let studioTool = StudioToolID(canvasTool: tool) {
                return .tool(studioTool)
            }

            switch tool {
            case .subjectSelection:
                return .action(.selectSubject)
            case .transform:
                return .action(.alignCenters)
            default:
                preconditionFailure("Every CanvasTool must map to a pinned shelf item.")
            }
        }
    }

    private static func makeProject(
        id: UUID,
        artboards: [StudioArtboard],
        workspace: StudioWorkspace
    ) -> ProjectManifestV1 {
        var workspaceDescriptor = workspace.modelDescriptor
        persistPinnedShelfItems(
            defaultPinnedShelfItems[workspace] ?? [],
            in: &workspaceDescriptor
        )

        return ProjectManifestV1(
            projectID: id,
            title: "Coastal Keepers Campaign",
            colorSpace: .displayP3,
            artboards: artboards.enumerated().map { index, artboard in
                let layers = artboard.layers.map(makeLayer)
                return ArtboardRecord(
                    id: artboard.id,
                    name: artboard.name,
                    frame: CanvasRect(
                        x: index == 0 ? 0 : Double(2_080 + index * 80),
                        y: index == 2 ? 160 : 0,
                        width: Double(artboard.pixelWidth),
                        height: Double(artboard.pixelHeight)
                    ),
                    pixelWidth: artboard.pixelWidth,
                    pixelHeight: artboard.pixelHeight,
                    dpi: 72,
                    background: RGBAColor(red: 0.96, green: 0.91, blue: 0.81),
                    rootLayerIDs: layers.map(\.id),
                    layers: layers
                )
            },
            workspace: workspaceDescriptor
        )
    }

    private static func makeDemoLayers(startingAt index: Int) -> [StudioLayerItem] {
        [
            StudioLayerItem(
                id: demoUUID(index),
                name: "COASTAL KEEPERS",
                symbol: "textformat"
            ),
            StudioLayerItem(
                id: demoUUID(index + 1),
                name: "Tagline",
                symbol: "folder",
                isExpandable: true
            ),
            StudioLayerItem(
                id: demoUUID(index + 2),
                name: "Brush Stroke",
                symbol: "folder",
                isExpandable: true
            ),
            StudioLayerItem(
                id: demoUUID(index + 3),
                name: "Badge",
                symbol: "folder",
                isExpandable: true
            ),
            StudioLayerItem(
                id: demoUUID(index + 4),
                name: "Illustration",
                symbol: "folder",
                isExpandable: true
            ),
            StudioLayerItem(
                id: demoUUID(index + 5),
                name: "Bottom Bar",
                symbol: "rectangle.fill",
                swatch: Color(red: 0.02, green: 0.24, blue: 0.31)
            )
        ]
    }

    private static func demoUUID(_ index: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "A0000000-0000-4000-8000-%012llX",
                Int64(index)
            )
        )!
    }

    private static func uniqueCanvasTools(
        for items: [PinnedShelfItem]
    ) -> [CanvasTool] {
        WorkspacePinnedItem.compatibilityProjection(
            for: items.map(\.workspacePinnedItem)
        )
    }

    private static func persistPinnedShelfItems(
        _ items: [PinnedShelfItem],
        in descriptor: inout WorkspaceDescriptor
    ) {
        let exactItems = items.map(\.workspacePinnedItem)
        descriptor.pinnedItems = exactItems
        descriptor.pinnedTools = WorkspacePinnedItem.compatibilityProjection(
            for: exactItems
        )
    }

    private static func makeLayer(_ layer: StudioLayerItem) -> LayerRecord {
        let kind: LayerKind
        if layer.symbol == "textformat" {
            kind = .text(
                TextLayerContent(
                    text: layer.name,
                    fontPostScriptName: "PlayfairDisplay-Bold",
                    fontSize: 112,
                    color: RGBAColor(red: 0.02, green: 0.24, blue: 0.31),
                    bounds: CanvasRect(x: 88, y: 72, width: 904, height: 312),
                    horizontalAlignment: .center
                )
            )
        } else if layer.isExpandable {
            kind = .group(GroupLayerContent())
        } else if layer.isRaster {
            kind = .raster(RasterLayerContent())
        } else {
            kind = .vector(VectorScene())
        }

        return LayerRecord(
            id: layer.id,
            name: layer.name,
            isVisible: layer.isVisible,
            kind: kind
        )
    }
}

private extension StudioToolID {
    init?(canvasTool: CanvasTool) {
        switch canvasTool {
        case .objectSelection:
            self = .objectSelect
        case .directSelection:
            self = .directSelect
        case .rectangularMarquee:
            self = .marqueeRectangle
        case .ellipticalMarquee:
            self = .marqueeEllipse
        case .freehandLasso:
            self = .lasso
        case .polygonLasso:
            self = .polygonLasso
        case .magicWand:
            self = .magicWand
        case .crop:
            self = .crop
        case .brush:
            self = .brush
        case .pencil:
            self = .pencil
        case .eraser:
            self = .eraser
        case .fill:
            self = .fill
        case .gradient:
            self = .gradient
        case .eyedropper:
            self = .eyedropper
        case .cloneStamp:
            self = .cloneStamp
        case .spotHeal:
            self = .spotHeal
        case .blur:
            self = .blur
        case .sharpen:
            self = .sharpen
        case .smudge:
            self = .smudge
        case .pen:
            self = .pen
        case .shape:
            self = .rectangle
        case .text:
            self = .text
        case .hand:
            self = .hand
        case .zoom:
            self = .zoom
        case .subjectSelection, .transform:
            return nil
        }
    }

    var canvasTool: CanvasTool {
        switch self {
        case .objectSelect: .objectSelection
        case .directSelect: .directSelection
        case .marqueeRectangle: .rectangularMarquee
        case .marqueeEllipse: .ellipticalMarquee
        case .lasso: .freehandLasso
        case .polygonLasso: .polygonLasso
        case .magicWand: .magicWand
        case .crop: .crop
        case .text: .text
        case .rectangle, .ellipse: .shape
        case .pen: .pen
        case .pencil: .pencil
        case .brush: .brush
        case .eraser: .eraser
        case .fill: .fill
        case .gradient: .gradient
        case .eyedropper: .eyedropper
        case .cloneStamp: .cloneStamp
        case .spotHeal: .spotHeal
        case .blur: .blur
        case .sharpen: .sharpen
        case .smudge: .smudge
        case .hand: .hand
        case .zoom: .zoom
        }
    }

    var workspacePinnedToolID: WorkspacePinnedToolID {
        switch self {
        case .objectSelect: .objectSelect
        case .directSelect: .directSelect
        case .marqueeRectangle: .marqueeRectangle
        case .marqueeEllipse: .marqueeEllipse
        case .lasso: .lasso
        case .polygonLasso: .polygonLasso
        case .magicWand: .magicWand
        case .crop: .crop
        case .text: .text
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        case .pen: .pen
        case .pencil: .pencil
        case .brush: .brush
        case .eraser: .eraser
        case .fill: .fill
        case .gradient: .gradient
        case .eyedropper: .eyedropper
        case .cloneStamp: .cloneStamp
        case .spotHeal: .spotHeal
        case .blur: .blur
        case .sharpen: .sharpen
        case .smudge: .smudge
        case .hand: .hand
        case .zoom: .zoom
        }
    }
}

private extension WorkspacePinnedToolID {
    var studioToolID: StudioToolID {
        switch self {
        case .objectSelect: .objectSelect
        case .directSelect: .directSelect
        case .marqueeRectangle: .marqueeRectangle
        case .marqueeEllipse: .marqueeEllipse
        case .lasso: .lasso
        case .polygonLasso: .polygonLasso
        case .magicWand: .magicWand
        case .crop: .crop
        case .text: .text
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        case .pen: .pen
        case .pencil: .pencil
        case .brush: .brush
        case .eraser: .eraser
        case .fill: .fill
        case .gradient: .gradient
        case .eyedropper: .eyedropper
        case .cloneStamp: .cloneStamp
        case .spotHeal: .spotHeal
        case .blur: .blur
        case .sharpen: .sharpen
        case .smudge: .smudge
        case .hand: .hand
        case .zoom: .zoom
        }
    }
}

private extension StudioWorkspace {
    init(preset: WorkspacePreset) {
        switch preset {
        case .essentials, .custom:
            self = .essentials
        case .painting:
            self = .painting
        case .vector:
            self = .vector
        case .photo:
            self = .photo
        }
    }

    var modelDescriptor: WorkspaceDescriptor {
        switch self {
        case .essentials: .essentials()
        case .painting: .painting()
        case .vector: .vector()
        case .photo: .photo()
        }
    }
}

extension RGBAColor {
    var studioColor: Color {
        Color(
            red: red,
            green: green,
            blue: blue,
            opacity: alpha
        )
    }

    var nsColor: NSColor {
        NSColor(
            calibratedRed: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
}

private extension PaintModel.BlendMode {
    var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .darken: .darken
        case .lighten: .lighten
        case .colorDodge: .colorDodge
        case .colorBurn: .colorBurn
        case .hardLight: .hardLight
        case .softLight: .softLight
        case .difference: .difference
        case .exclusion: .exclusion
        case .hue: .hue
        case .saturation: .saturation
        case .color: .color
        case .luminosity: .luminosity
        }
    }
}

private extension PinnedActionID {
    var workspacePinnedActionID: WorkspacePinnedActionID {
        switch self {
        case .gouacheBrush: .gouacheBrush
        case .selectSubject: .selectSubject
        case .crop169: .crop169
        case .removeBackground: .removeBackground
        case .exportPNG: .exportPNG
        case .stabilizeBrush: .stabilizeBrush
        case .mirrorCanvas: .mirrorCanvas
        case .fitCanvas: .fitCanvas
        case .snapToGrid: .snapToGrid
        case .alignCenters: .alignCenters
        case .booleanUnion: .booleanUnion
        case .exportSVG: .exportSVG
        case .invertSelection: .invertSelection
        case .beforeAfter: .beforeAfter
        }
    }
}

private extension WorkspacePinnedActionID {
    var pinnedActionID: PinnedActionID {
        switch self {
        case .gouacheBrush: .gouacheBrush
        case .selectSubject: .selectSubject
        case .crop169: .crop169
        case .removeBackground: .removeBackground
        case .exportPNG: .exportPNG
        case .stabilizeBrush: .stabilizeBrush
        case .mirrorCanvas: .mirrorCanvas
        case .fitCanvas: .fitCanvas
        case .snapToGrid: .snapToGrid
        case .alignCenters: .alignCenters
        case .booleanUnion: .booleanUnion
        case .exportSVG: .exportSVG
        case .invertSelection: .invertSelection
        case .beforeAfter: .beforeAfter
        }
    }
}

private extension PinnedShelfItem {
    init(_ item: WorkspacePinnedItem) {
        switch item {
        case let .tool(tool):
            self = .tool(tool.studioToolID)
        case let .action(action):
            self = .action(action.pinnedActionID)
        }
    }

    var workspacePinnedItem: WorkspacePinnedItem {
        switch self {
        case let .tool(tool):
            .tool(tool.workspacePinnedToolID)
        case let .action(action):
            .action(action.workspacePinnedActionID)
        }
    }
}
