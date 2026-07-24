import Foundation

public enum WorkspacePreset: String, Codable, CaseIterable, Equatable, Sendable {
    case essentials
    case painting
    case vector
    case photo
    case custom
}

public enum DockZone: String, Codable, CaseIterable, Equatable, Sendable {
    case left
    case right
    case bottom
    case floating
}

public enum PanelIdentifier: String, Codable, CaseIterable, Equatable, Sendable {
    case artboards
    case layers
    case color
    case brushes
    case history
    case navigator
    case properties
    case toolOptions = "tool-options"
}

/// Stable identifiers for tools that can appear in the customizable shelf.
///
/// This is intentionally more specific than `CanvasTool`: rectangle and
/// ellipse both render through `.shape`, but remain distinct shelf choices.
public enum WorkspacePinnedToolID: String, Codable, CaseIterable, Equatable,
    Hashable, Sendable
{
    case objectSelect = "object-select"
    case directSelect = "direct-select"
    case marqueeRectangle = "marquee-rectangle"
    case marqueeEllipse = "marquee-ellipse"
    case lasso
    case polygonLasso = "polygon-lasso"
    case magicWand = "magic-wand"
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
    case cloneStamp = "clone-stamp"
    case spotHeal = "spot-heal"
    case blur
    case sharpen
    case smudge
    case hand
    case zoom

    public var canvasTool: CanvasTool {
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
}

/// Stable identifiers for shelf commands that are not ordinary canvas tools.
public enum WorkspacePinnedActionID: String, Codable, CaseIterable, Equatable,
    Hashable, Sendable
{
    case gouacheBrush = "gouache-brush"
    case selectSubject = "select-subject"
    case crop169 = "crop-16-9"
    case removeBackground = "remove-background"
    case exportPNG = "export-png"
    case stabilizeBrush = "stabilize-brush"
    case mirrorCanvas = "mirror-canvas"
    case fitCanvas = "fit-canvas"
    case snapToGrid = "snap-to-grid"
    case alignCenters = "align-centers"
    case booleanUnion = "boolean-union"
    case exportSVG = "export-svg"
    case invertSelection = "invert-selection"
    case beforeAfter = "before-after"

    public var canvasTool: CanvasTool? {
        switch self {
        case .gouacheBrush, .stabilizeBrush, .mirrorCanvas:
            .brush
        case .selectSubject, .removeBackground:
            .subjectSelection
        case .crop169:
            .crop
        case .fitCanvas:
            .zoom
        case .snapToGrid, .alignCenters, .booleanUnion:
            .objectSelection
        case .invertSelection:
            .rectangularMarquee
        case .beforeAfter:
            .hand
        case .exportPNG, .exportSVG:
            nil
        }
    }
}

/// An exact, ordered shelf entry encoded as `{ "kind", "identifier" }`.
public enum WorkspacePinnedItem: Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case tool
        case action
    }

    case tool(WorkspacePinnedToolID)
    case action(WorkspacePinnedActionID)

    public var kind: Kind {
        switch self {
        case .tool: .tool
        case .action: .action
        }
    }

    public var identifier: String {
        switch self {
        case let .tool(tool): tool.rawValue
        case let .action(action): action.rawValue
        }
    }

    public var canvasTool: CanvasTool? {
        switch self {
        case let .tool(tool): tool.canvasTool
        case let .action(action): action.canvasTool
        }
    }

    public static func compatibilityProjection(
        for items: [WorkspacePinnedItem]
    ) -> [CanvasTool] {
        var used: Set<String> = []
        return items.compactMap(\.canvasTool).filter {
            used.insert($0.rawValue).inserted
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case identifier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .tool:
            self = .tool(
                try container.decode(
                    WorkspacePinnedToolID.self,
                    forKey: .identifier
                )
            )
        case .action:
            self = .action(
                try container.decode(
                    WorkspacePinnedActionID.self,
                    forKey: .identifier
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case let .tool(tool):
            try container.encode(tool, forKey: .identifier)
        case let .action(action):
            try container.encode(action, forKey: .identifier)
        }
    }
}

public struct PanelGroup: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var panelIDs: [PanelIdentifier]
    public var selectedPanelID: PanelIdentifier

    public init(
        id: UUID = UUID(),
        title: String,
        panelIDs: [PanelIdentifier],
        selectedPanelID: PanelIdentifier
    ) {
        self.id = id
        self.title = title
        self.panelIDs = panelIDs
        self.selectedPanelID = selectedPanelID
    }
}

public struct PanelPlacement: Codable, Equatable, Sendable {
    public var groupID: UUID
    public var zone: DockZone
    public var order: Int
    public var isCollapsed: Bool
    public var floatingFrame: CanvasRect?

    public init(
        groupID: UUID,
        zone: DockZone,
        order: Int,
        isCollapsed: Bool = false,
        floatingFrame: CanvasRect? = nil
    ) {
        self.groupID = groupID
        self.zone = zone
        self.order = order
        self.isCollapsed = isCollapsed
        self.floatingFrame = floatingFrame
    }
}

/// Persisted studio layout. `pinnedItems` is the exact shelf representation;
/// `pinnedTools` remains its compatibility projection and legacy fallback.
public struct WorkspaceDescriptor: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var preset: WorkspacePreset
    public var pinnedTools: [CanvasTool]
    public var pinnedItems: [WorkspacePinnedItem]?
    public var panelGroups: [PanelGroup]
    public var placements: [PanelPlacement]

    public init(
        id: UUID = UUID(),
        name: String,
        preset: WorkspacePreset = .custom,
        pinnedTools: [CanvasTool],
        pinnedItems: [WorkspacePinnedItem]? = nil,
        panelGroups: [PanelGroup],
        placements: [PanelPlacement]
    ) {
        self.id = id
        self.name = name
        self.preset = preset
        self.pinnedTools = pinnedTools
        self.pinnedItems = pinnedItems
        self.panelGroups = panelGroups
        self.placements = placements
    }

    public static func essentials() -> WorkspaceDescriptor {
        makePreset(
            name: "Essentials",
            preset: .essentials,
            pinnedTools: [.objectSelection, .brush, .eraser, .shape, .text, .crop]
        )
    }

    public static func painting() -> WorkspaceDescriptor {
        makePreset(
            name: "Painting",
            preset: .painting,
            pinnedTools: [.brush, .pencil, .eraser, .smudge, .eyedropper, .fill]
        )
    }

    public static func vector() -> WorkspaceDescriptor {
        makePreset(
            name: "Vector",
            preset: .vector,
            pinnedTools: [.objectSelection, .directSelection, .pen, .shape, .text, .gradient]
        )
    }

    public static func photo() -> WorkspaceDescriptor {
        makePreset(
            name: "Photo",
            preset: .photo,
            pinnedTools: [.crop, .subjectSelection, .spotHeal, .cloneStamp, .brush, .transform]
        )
    }

    private static func makePreset(
        name: String,
        preset: WorkspacePreset,
        pinnedTools: [CanvasTool]
    ) -> WorkspaceDescriptor {
        let toolGroup = PanelGroup(
            title: "Tools",
            panelIDs: [.toolOptions, .brushes, .color],
            selectedPanelID: .toolOptions
        )
        let documentGroup = PanelGroup(
            title: "Document",
            panelIDs: [.layers, .properties, .history],
            selectedPanelID: .layers
        )
        let artboardGroup = PanelGroup(
            title: "Artboards",
            panelIDs: [.artboards, .navigator],
            selectedPanelID: .artboards
        )

        return WorkspaceDescriptor(
            name: name,
            preset: preset,
            pinnedTools: pinnedTools,
            panelGroups: [toolGroup, documentGroup, artboardGroup],
            placements: [
                PanelPlacement(groupID: toolGroup.id, zone: .left, order: 0),
                PanelPlacement(groupID: documentGroup.id, zone: .right, order: 0),
                PanelPlacement(groupID: artboardGroup.id, zone: .bottom, order: 0),
            ]
        )
    }
}
