import Foundation

public struct ProjectValidationIssue: Codable, Equatable, Sendable {
    public enum Code: String, Codable, CaseIterable, Equatable, Sendable {
        case unsupportedSchemaVersion = "unsupported-schema-version"
        case duplicateID = "duplicate-id"
        case invalidArtboardDimensions = "invalid-artboard-dimensions"
        case invalidDPI = "invalid-dpi"
        case invalidGeometry = "invalid-geometry"
        case invalidColor = "invalid-color"
        case invalidOpacity = "invalid-opacity"
        case invalidTile = "invalid-tile"
        case unsafeTilePath = "unsafe-tile-path"
        case missingReference = "missing-reference"
        case multipleOwners = "multiple-owners"
        case orphanedRecord = "orphaned-record"
        case cycleDetected = "cycle-detected"
        case invalidVector = "invalid-vector"
        case invalidText = "invalid-text"
        case invalidWorkspace = "invalid-workspace"
    }

    public var code: Code
    public var path: String
    public var message: String

    public init(code: Code, path: String, message: String) {
        self.code = code
        self.path = path
        self.message = message
    }
}

public struct ProjectValidationError: Error, Codable, Equatable, Sendable {
    public var issues: [ProjectValidationIssue]

    public init(issues: [ProjectValidationIssue]) {
        self.issues = issues
    }
}

extension ProjectValidationError: LocalizedError {
    public var errorDescription: String? {
        let noun = issues.count == 1 ? "issue" : "issues"
        return "The project manifest contains \(issues.count) validation \(noun)."
    }
}

extension ProjectManifestV1 {
    /// Throws once with all validation issues so callers can present actionable recovery UI.
    public func validate() throws {
        let issues = validationIssues()
        guard issues.isEmpty else {
            throw ProjectValidationError(issues: issues)
        }
    }

    public func validationIssues() -> [ProjectValidationIssue] {
        var issues: [ProjectValidationIssue] = []
        var identifierPaths: [UUID: String] = [:]

        func append(_ code: ProjectValidationIssue.Code, _ path: String, _ message: String) {
            issues.append(ProjectValidationIssue(code: code, path: path, message: message))
        }

        func register(_ id: UUID, at path: String) {
            if let firstPath = identifierPaths[id] {
                append(.duplicateID, path, "Identifier is already used at \(firstPath).")
            } else {
                identifierPaths[id] = path
            }
        }

        register(projectID, at: "projectID")
        register(workspace.id, at: "workspace.id")

        if schemaVersion != Self.currentSchemaVersion {
            append(
                .unsupportedSchemaVersion,
                "schemaVersion",
                "Expected schema version \(Self.currentSchemaVersion), got \(schemaVersion)."
            )
        }

        for (groupIndex, group) in workspace.panelGroups.enumerated() {
            register(group.id, at: "workspace.panelGroups[\(groupIndex)].id")
        }

        for (artboardIndex, artboard) in artboards.enumerated() {
            let artboardPath = "artboards[\(artboardIndex)]"
            register(artboard.id, at: "\(artboardPath).id")

            for (layerIndex, layer) in artboard.layers.enumerated() {
                let layerPath = "\(artboardPath).layers[\(layerIndex)]"
                register(layer.id, at: "\(layerPath).id")

                guard case let .vector(scene) = layer.kind else { continue }
                for (objectIndex, object) in scene.objects.enumerated() {
                    let objectPath = "\(layerPath).kind.content.objects[\(objectIndex)]"
                    register(object.id, at: "\(objectPath).id")

                    if case let .path(path) = object.kind {
                        for (nodeIndex, node) in path.nodes.enumerated() {
                            register(node.id, at: "\(objectPath).kind.content.nodes[\(nodeIndex)].id")
                        }
                    }

                    for (stopIndex, stop) in object.fill.gradientStops.enumerated() {
                        register(stop.id, at: "\(objectPath).fill.stops[\(stopIndex)].id")
                    }
                }
            }
        }

        validateWorkspace(workspace, append: append)

        for (artboardIndex, artboard) in artboards.enumerated() {
            let artboardPath = "artboards[\(artboardIndex)]"
            validateArtboard(artboard, path: artboardPath, append: append)
        }

        return issues
    }
}

private extension FillStyle {
    var gradientStops: [GradientStop] {
        switch self {
        case .none, .solid:
            []
        case let .linearGradient(gradient):
            gradient.stops
        case let .radialGradient(gradient):
            gradient.stops
        }
    }
}

private func validateWorkspace(
    _ workspace: WorkspaceDescriptor,
    append: (ProjectValidationIssue.Code, String, String) -> Void
) {
    if workspace.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        append(.invalidWorkspace, "workspace.name", "Workspace name must not be empty.")
    }

    if Set(workspace.pinnedTools.map(\.rawValue)).count != workspace.pinnedTools.count {
        append(.invalidWorkspace, "workspace.pinnedTools", "Pinned tools must not contain duplicates.")
    }

    if let pinnedItems = workspace.pinnedItems {
        let itemKeys = pinnedItems.map {
            "\($0.kind.rawValue):\($0.identifier)"
        }
        if Set(itemKeys).count != itemKeys.count {
            append(
                .invalidWorkspace,
                "workspace.pinnedItems",
                "Pinned shelf items must not contain duplicates."
            )
        }

        if WorkspacePinnedItem.compatibilityProjection(for: pinnedItems)
            != workspace.pinnedTools
        {
            append(
                .invalidWorkspace,
                "workspace.pinnedTools",
                "Pinned tools must match the compatibility projection of pinned items."
            )
        }
    }

    let groupIDs = Set(workspace.panelGroups.map(\.id))
    var placementCounts: [UUID: Int] = [:]
    var occupiedDockOrders: Set<String> = []

    for (index, group) in workspace.panelGroups.enumerated() {
        let path = "workspace.panelGroups[\(index)]"
        if group.panelIDs.isEmpty {
            append(.invalidWorkspace, "\(path).panelIDs", "A panel group must contain at least one panel.")
        }
        if Set(group.panelIDs.map(\.rawValue)).count != group.panelIDs.count {
            append(.invalidWorkspace, "\(path).panelIDs", "A panel group must not repeat panels.")
        }
        if !group.panelIDs.contains(group.selectedPanelID) {
            append(
                .invalidWorkspace,
                "\(path).selectedPanelID",
                "The selected panel must belong to its panel group."
            )
        }
    }

    for (index, placement) in workspace.placements.enumerated() {
        let path = "workspace.placements[\(index)]"
        guard groupIDs.contains(placement.groupID) else {
            append(.missingReference, "\(path).groupID", "Placement references a missing panel group.")
            continue
        }

        placementCounts[placement.groupID, default: 0] += 1
        if placement.order < 0 {
            append(.invalidWorkspace, "\(path).order", "Dock order must be zero or greater.")
        }

        let orderKey = "\(placement.zone.rawValue):\(placement.order)"
        if placement.zone != .floating, !occupiedDockOrders.insert(orderKey).inserted {
            append(
                .invalidWorkspace,
                path,
                "Two panel groups occupy the same order in the same dock zone."
            )
        }

        if placement.zone == .floating {
            guard let frame = placement.floatingFrame, frame.isFiniteAndPositive else {
                append(
                    .invalidWorkspace,
                    "\(path).floatingFrame",
                    "A floating panel group requires a finite, positive frame."
                )
                continue
            }
        } else if placement.floatingFrame != nil {
            append(
                .invalidWorkspace,
                "\(path).floatingFrame",
                "Only floating panel groups may have a floating frame."
            )
        }
    }

    for (index, group) in workspace.panelGroups.enumerated() {
        switch placementCounts[group.id, default: 0] {
        case 0:
            append(
                .orphanedRecord,
                "workspace.panelGroups[\(index)]",
                "Panel group has no placement."
            )
        case 1:
            break
        default:
            append(
                .multipleOwners,
                "workspace.panelGroups[\(index)]",
                "Panel group has more than one placement."
            )
        }
    }
}

private func validateArtboard(
    _ artboard: ArtboardRecord,
    path: String,
    append: (ProjectValidationIssue.Code, String, String) -> Void
) {
    let validDimensions = (1 ... ProjectManifestV1.maximumArtboardDimension).contains(artboard.pixelWidth)
        && (1 ... ProjectManifestV1.maximumArtboardDimension).contains(artboard.pixelHeight)
    if !validDimensions {
        append(
            .invalidArtboardDimensions,
            path,
            "Artboard dimensions must be between 1 and \(ProjectManifestV1.maximumArtboardDimension) pixels."
        )
    }

    if !artboard.dpi.isFinite || artboard.dpi <= 0 {
        append(.invalidDPI, "\(path).dpi", "DPI must be finite and greater than zero.")
    }
    if !artboard.frame.isFiniteAndPositive {
        append(.invalidGeometry, "\(path).frame", "Artboard frame must be finite and positive.")
    }
    if !artboard.background.hasValidComponents {
        append(.invalidColor, "\(path).background", "Background components must be in 0...1.")
    }

    var layersByID: [UUID: LayerRecord] = [:]
    var layerPaths: [UUID: String] = [:]
    for (index, layer) in artboard.layers.enumerated() {
        let layerPath = "\(path).layers[\(index)]"
        if layersByID[layer.id] == nil {
            layersByID[layer.id] = layer
            layerPaths[layer.id] = layerPath
        }

        if !layer.opacity.isFinite || !(0 ... 1).contains(layer.opacity) {
            append(.invalidOpacity, "\(layerPath).opacity", "Layer opacity must be in 0...1.")
        }
        if !layer.transform.isFinite {
            append(.invalidGeometry, "\(layerPath).transform", "Layer transform must be finite.")
        }

        if let mask = layer.mask {
            validateTiles(
                mask.tileReferences,
                tileSize: mask.tileSize,
                artboard: artboard,
                path: "\(layerPath).mask",
                append: append
            )
        }

        switch layer.kind {
        case let .raster(content):
            validateTiles(
                content.tileReferences,
                tileSize: content.tileSize,
                artboard: artboard,
                path: "\(layerPath).kind.content",
                append: append
            )
        case let .vector(scene):
            validateVectorScene(scene, path: "\(layerPath).kind.content", append: append)
        case let .text(text):
            if !text.fontSize.isFinite || text.fontSize <= 0 {
                append(.invalidText, "\(layerPath).kind.content.fontSize", "Font size must be positive.")
            }
            if !text.bounds.isFiniteAndPositive {
                append(.invalidGeometry, "\(layerPath).kind.content.bounds", "Text bounds must be finite and positive.")
            }
            if !text.color.hasValidComponents {
                append(.invalidColor, "\(layerPath).kind.content.color", "Text color components must be in 0...1.")
            }
        case .group:
            break
        }
    }

    let children: [UUID: [UUID]] = Dictionary(
        uniqueKeysWithValues: layersByID.map { id, layer in
            if case let .group(group) = layer.kind {
                return (id, group.childLayerIDs)
            }
            return (id, [])
        }
    )

    validateTree(
        rootIDs: artboard.rootLayerIDs,
        allIDs: Set(layersByID.keys),
        childIDs: children,
        paths: layerPaths,
        rootPath: "\(path).rootLayerIDs",
        append: append
    )
}

private func validateTiles(
    _ tileReferences: [RasterTileReference],
    tileSize: Int,
    artboard: ArtboardRecord,
    path: String,
    append: (ProjectValidationIssue.Code, String, String) -> Void
) {
    guard tileSize == 256 else {
        append(.invalidTile, "\(path).tileSize", "V1 raster tiles must be 256×256 pixels.")
        return
    }

    let maximumX = max(0, (artboard.pixelWidth - 1) / tileSize)
    let maximumY = max(0, (artboard.pixelHeight - 1) / tileSize)
    var coordinates: Set<TileCoordinate> = []

    for (index, tile) in tileReferences.enumerated() {
        let tilePath = "\(path).tileReferences[\(index)]"
        if !coordinates.insert(tile.coordinate).inserted {
            append(.invalidTile, "\(tilePath).coordinate", "Tile coordinate is duplicated.")
        }
        if tile.coordinate.x < 0 || tile.coordinate.y < 0
            || tile.coordinate.x > maximumX || tile.coordinate.y > maximumY
        {
            append(.invalidTile, "\(tilePath).coordinate", "Tile coordinate lies outside the artboard.")
        }
        if !(1 ... tileSize).contains(tile.pixelWidth) || !(1 ... tileSize).contains(tile.pixelHeight) {
            append(.invalidTile, tilePath, "Tile dimensions must be between 1 and the tile size.")
        }
        if let byteCount = tile.byteCount, byteCount < 0 {
            append(.invalidTile, "\(tilePath).byteCount", "Tile byte count must not be negative.")
        }
        if !tile.relativePath.isSafePackageRelativePath {
            append(.unsafeTilePath, "\(tilePath).relativePath", "Tile path must be a safe package-relative path.")
        }
    }
}

private func validateVectorScene(
    _ scene: VectorScene,
    path: String,
    append: (ProjectValidationIssue.Code, String, String) -> Void
) {
    var objectsByID: [UUID: VectorObject] = [:]
    var objectPaths: [UUID: String] = [:]

    for (index, object) in scene.objects.enumerated() {
        let objectPath = "\(path).objects[\(index)]"
        if objectsByID[object.id] == nil {
            objectsByID[object.id] = object
            objectPaths[object.id] = objectPath
        }

        if !object.opacity.isFinite || !(0 ... 1).contains(object.opacity) {
            append(.invalidOpacity, "\(objectPath).opacity", "Vector opacity must be in 0...1.")
        }
        if !object.transform.isFinite {
            append(.invalidGeometry, "\(objectPath).transform", "Vector transform must be finite.")
        }
        validateFill(object.fill, path: "\(objectPath).fill", append: append)
        if let stroke = object.stroke {
            validateStroke(stroke, path: "\(objectPath).stroke", append: append)
        }

        switch object.kind {
        case let .path(vectorPath):
            for (nodeIndex, node) in vectorPath.nodes.enumerated() {
                let nodePath = "\(objectPath).kind.content.nodes[\(nodeIndex)]"
                if !node.anchor.isFinite
                    || node.incomingControl.map({ !$0.isFinite }) == true
                    || node.outgoingControl.map({ !$0.isFinite }) == true
                {
                    append(.invalidGeometry, nodePath, "Path node coordinates must be finite.")
                }
            }
        case let .rectangle(shape):
            if !shape.bounds.isFiniteAndPositive || !shape.cornerRadius.isFinite || shape.cornerRadius < 0 {
                append(.invalidGeometry, "\(objectPath).kind.content", "Rectangle geometry is invalid.")
            }
        case let .ellipse(shape):
            if !shape.bounds.isFiniteAndPositive {
                append(.invalidGeometry, "\(objectPath).kind.content.bounds", "Ellipse bounds must be finite and positive.")
            }
        case let .line(shape):
            if !shape.start.isFinite || !shape.end.isFinite {
                append(.invalidGeometry, "\(objectPath).kind.content", "Line coordinates must be finite.")
            }
        case .group:
            break
        }
    }

    let children: [UUID: [UUID]] = Dictionary(
        uniqueKeysWithValues: objectsByID.map { id, object in
            if case let .group(group) = object.kind {
                return (id, group.childObjectIDs)
            }
            return (id, [])
        }
    )

    validateTree(
        rootIDs: scene.rootObjectIDs,
        allIDs: Set(objectsByID.keys),
        childIDs: children,
        paths: objectPaths,
        rootPath: "\(path).rootObjectIDs",
        append: append
    )
}

private func validateFill(
    _ fill: FillStyle,
    path: String,
    append: (ProjectValidationIssue.Code, String, String) -> Void
) {
    switch fill {
    case .none:
        break
    case let .solid(color):
        if !color.hasValidComponents {
            append(.invalidColor, path, "Fill color components must be in 0...1.")
        }
    case let .linearGradient(gradient):
        if !gradient.start.isFinite || !gradient.end.isFinite {
            append(.invalidGeometry, path, "Linear gradient coordinates must be finite.")
        }
        validateGradientStops(gradient.stops, path: "\(path).stops", append: append)
    case let .radialGradient(gradient):
        if !gradient.center.isFinite || !gradient.radius.isFinite || gradient.radius <= 0 {
            append(.invalidGeometry, path, "Radial gradient geometry is invalid.")
        }
        validateGradientStops(gradient.stops, path: "\(path).stops", append: append)
    }
}

private func validateGradientStops(
    _ stops: [GradientStop],
    path: String,
    append: (ProjectValidationIssue.Code, String, String) -> Void
) {
    if stops.count < 2 {
        append(.invalidVector, path, "A gradient requires at least two stops.")
    }
    for (index, stop) in stops.enumerated() {
        if !stop.location.isFinite || !(0 ... 1).contains(stop.location) {
            append(.invalidVector, "\(path)[\(index)].location", "Gradient stop location must be in 0...1.")
        }
        if !stop.color.hasValidComponents {
            append(.invalidColor, "\(path)[\(index)].color", "Gradient color components must be in 0...1.")
        }
    }
}

private func validateStroke(
    _ stroke: StrokeStyle,
    path: String,
    append: (ProjectValidationIssue.Code, String, String) -> Void
) {
    if !stroke.color.hasValidComponents {
        append(.invalidColor, "\(path).color", "Stroke color components must be in 0...1.")
    }
    if !stroke.width.isFinite || stroke.width < 0 {
        append(.invalidVector, "\(path).width", "Stroke width must be finite and nonnegative.")
    }
    if stroke.dashPattern.contains(where: { !$0.isFinite || $0 < 0 }) {
        append(.invalidVector, "\(path).dashPattern", "Dash lengths must be finite and nonnegative.")
    }
}

private func validateTree(
    rootIDs: [UUID],
    allIDs: Set<UUID>,
    childIDs: [UUID: [UUID]],
    paths: [UUID: String],
    rootPath: String,
    append: (ProjectValidationIssue.Code, String, String) -> Void
) {
    var ownerCounts: [UUID: Int] = [:]

    for (index, id) in rootIDs.enumerated() {
        guard allIDs.contains(id) else {
            append(.missingReference, "\(rootPath)[\(index)]", "Root references a missing record.")
            continue
        }
        ownerCounts[id, default: 0] += 1
    }

    for (parentID, children) in childIDs {
        for (index, childID) in children.enumerated() {
            guard allIDs.contains(childID) else {
                let parentPath = paths[parentID] ?? rootPath
                append(
                    .missingReference,
                    "\(parentPath).children[\(index)]",
                    "Group references a missing child record."
                )
                continue
            }
            ownerCounts[childID, default: 0] += 1
        }
    }

    for id in allIDs {
        let path = paths[id] ?? rootPath
        switch ownerCounts[id, default: 0] {
        case 0:
            append(.orphanedRecord, path, "Record must have exactly one owner.")
        case 1:
            break
        default:
            append(.multipleOwners, path, "Record has more than one owner.")
        }
    }

    enum VisitState {
        case visiting
        case visited
    }
    var states: [UUID: VisitState] = [:]
    var cycleIDs: Set<UUID> = []

    func visit(_ id: UUID) {
        if states[id] == .visiting {
            if cycleIDs.insert(id).inserted {
                append(.cycleDetected, paths[id] ?? rootPath, "Tree contains a cycle.")
            }
            return
        }
        if states[id] == .visited {
            return
        }

        states[id] = .visiting
        for childID in childIDs[id, default: []] where allIDs.contains(childID) {
            visit(childID)
        }
        states[id] = .visited
    }

    for id in allIDs {
        visit(id)
    }
}

private extension CanvasPoint {
    var isFinite: Bool {
        x.isFinite && y.isFinite
    }
}

private extension CanvasRect {
    var isFiniteAndPositive: Bool {
        origin.isFinite && size.width.isFinite && size.height.isFinite
            && size.width > 0 && size.height > 0
    }
}

private extension CanvasTransform {
    var isFinite: Bool {
        [a, b, c, d, tx, ty].allSatisfy(\.isFinite)
    }
}

private extension String {
    var isSafePackageRelativePath: Bool {
        guard !isEmpty, !hasPrefix("/"), !hasPrefix("\\") else { return false }
        let components = split(whereSeparator: { $0 == "/" || $0 == "\\" })
        return !components.isEmpty && !components.contains("..") && !components.contains(".")
    }
}
