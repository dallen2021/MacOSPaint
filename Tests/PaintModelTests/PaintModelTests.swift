import Foundation
import Testing
@testable import PaintModel

@Suite("PaintModel contracts")
struct PaintModelTests {
    @Test
    func testSampleProjectIsValidAndContainsVerticalSliceContent() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let project = ProjectManifestV1.sampleProject(title: "Sample", now: date)

        try project.validate()
        #expect(project.schemaVersion == 1)
        #expect(project.title == "Sample")
        #expect(project.createdAt == date)
        #expect(project.modifiedAt == date)
        #expect(project.artboards.count == 2)
        #expect(project.artboards[0].id != project.artboards[1].id)
        #expect(project.artboards[1].frame.minX > project.artboards[0].frame.maxX)
        #expect(project.workspace.pinnedTools.contains(.brush))
        #expect(project.workspace.placements.contains { $0.zone == .bottom })

        let firstKinds = project.artboards[0].layers.map(\.kind.type)
        #expect(firstKinds.contains(.raster))
        #expect(firstKinds.contains(.vector))

        let vectorLayer = try #require(
            project.artboards[0].layers.first { $0.kind.type == .vector }
        )
        guard case let .vector(scene) = vectorLayer.kind else {
            Issue.record("Expected vector layer")
            return
        }
        #expect(scene.objects.count == 1)
        guard case let .path(path) = scene.objects[0].kind else {
            Issue.record("Expected editable path")
            return
        }
        #expect(path.nodes.count == 3)
    }

    @Test
    func testManifestJSONRoundTripPreservesStableDiscriminators() throws {
        let project = ProjectManifestV1.sampleProject(
            now: Date(timeIntervalSince1970: 123)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(project)

        let json = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(json["schemaVersion"] as? Int == 1)
        let artboards = try #require(json["artboards"] as? [[String: Any]])
        let layers = try #require(artboards[0]["layers"] as? [[String: Any]])
        let layerKind = try #require(layers[0]["kind"] as? [String: Any])
        #expect(layerKind["type"] as? String == "vector")
        #expect(layerKind["content"] != nil)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(ProjectManifestV1.self, from: data)
        #expect(decoded == project)
        try decoded.validate()
    }

    @Test
    func testAllLayerKindsRoundTrip() throws {
        let raster = LayerKind.raster(RasterLayerContent())
        let vector = LayerKind.vector(VectorScene())
        let text = LayerKind.text(
            TextLayerContent(
                text: "Hello",
                bounds: CanvasRect(x: 1, y: 2, width: 300, height: 50)
            )
        )
        let group = LayerKind.group(GroupLayerContent())

        for kind in [raster, vector, text, group] {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(LayerKind.self, from: data)
            #expect(decoded == kind)
            #expect(decoded.type == kind.type)
        }
    }

    @Test
    func testMaximumArtboardDimensionIsInclusive() throws {
        var project = ProjectManifestV1.sampleProject()
        project.artboards[0].pixelWidth = ProjectManifestV1.maximumArtboardDimension
        project.artboards[0].pixelHeight = ProjectManifestV1.maximumArtboardDimension
        #expect(
            project.validationIssues().contains { $0.code == .invalidArtboardDimensions }
            == false
        )

        project.artboards[0].pixelWidth += 1
        let issues = project.validationIssues()
        #expect(issues.contains { $0.code == .invalidArtboardDimensions })
        do {
            try project.validate()
            Issue.record("Expected validation to fail")
        } catch {
            #expect(error is ProjectValidationError)
        }
    }

    @Test
    func testDuplicateIdentifiersAreRejectedAcrossTheWholeProject() {
        var project = ProjectManifestV1.sampleProject()
        project.artboards[1].layers[0].id = project.artboards[0].layers[0].id
        project.artboards[1].rootLayerIDs[0] = project.artboards[1].layers[0].id

        let duplicateIssues = project.validationIssues().filter { $0.code == .duplicateID }
        #expect(duplicateIssues.count == 1)
        #expect(duplicateIssues[0].path.contains("artboards[1]"))
    }

    @Test
    func testValidNestedLayerTreeHasExactlyOneOwner() throws {
        let child = LayerRecord(name: "Child", kind: .raster(RasterLayerContent()))
        let group = LayerRecord(
            name: "Group",
            kind: .group(GroupLayerContent(childLayerIDs: [child.id]))
        )
        let artboard = ArtboardRecord(
            name: "Nested",
            frame: CanvasRect(x: 0, y: 0, width: 100, height: 100),
            pixelWidth: 100,
            pixelHeight: 100,
            rootLayerIDs: [group.id],
            layers: [group, child]
        )
        let project = ProjectManifestV1(title: "Nested", artboards: [artboard])

        try project.validate()
    }

    @Test
    func testLayerCycleAndMultipleOwnershipAreBothReported() {
        let firstID = UUID()
        let secondID = UUID()
        let first = LayerRecord(
            id: firstID,
            name: "First",
            kind: .group(GroupLayerContent(childLayerIDs: [secondID]))
        )
        let second = LayerRecord(
            id: secondID,
            name: "Second",
            kind: .group(GroupLayerContent(childLayerIDs: [firstID]))
        )
        let artboard = ArtboardRecord(
            name: "Cycle",
            frame: CanvasRect(x: 0, y: 0, width: 100, height: 100),
            pixelWidth: 100,
            pixelHeight: 100,
            rootLayerIDs: [firstID],
            layers: [first, second]
        )
        let issues = ProjectManifestV1(title: "Cycle", artboards: [artboard])
            .validationIssues()

        #expect(issues.contains { $0.code == .cycleDetected })
        #expect(issues.contains { $0.code == .multipleOwners })
    }

    @Test
    func testMissingAndOrphanedLayerReferencesAreReported() {
        let orphan = LayerRecord(name: "Orphan", kind: .raster(RasterLayerContent()))
        let artboard = ArtboardRecord(
            name: "Broken",
            frame: CanvasRect(x: 0, y: 0, width: 100, height: 100),
            pixelWidth: 100,
            pixelHeight: 100,
            rootLayerIDs: [UUID()],
            layers: [orphan]
        )
        let issues = ProjectManifestV1(title: "Broken", artboards: [artboard])
            .validationIssues()

        #expect(issues.contains { $0.code == .missingReference })
        #expect(issues.contains { $0.code == .orphanedRecord })
    }

    @Test
    func testVectorSceneRequiresAcyclicSingleOwnership() {
        let objectID = UUID()
        let group = VectorObject(
            id: objectID,
            name: "Recursive",
            kind: .group(VectorGroup(childObjectIDs: [objectID]))
        )
        let vectorLayer = LayerRecord(
            name: "Vectors",
            kind: .vector(
                VectorScene(rootObjectIDs: [objectID], objects: [group])
            )
        )
        let artboard = ArtboardRecord(
            name: "Vector Cycle",
            frame: CanvasRect(x: 0, y: 0, width: 100, height: 100),
            pixelWidth: 100,
            pixelHeight: 100,
            rootLayerIDs: [vectorLayer.id],
            layers: [vectorLayer]
        )
        let issues = ProjectManifestV1(title: "Vector Cycle", artboards: [artboard])
            .validationIssues()

        #expect(issues.contains { $0.code == .cycleDetected })
        #expect(issues.contains { $0.code == .multipleOwners })
    }

    @Test
    func testRasterAndMaskTileReferencesValidateBoundsUniquenessAndPaths() {
        let coordinate = TileCoordinate(x: 0, y: 0)
        let safeTile = RasterTileReference(
            coordinate: coordinate,
            relativePath: "tiles/layer/0-0.png"
        )
        let duplicateUnsafeTile = RasterTileReference(
            coordinate: coordinate,
            relativePath: "../outside.png"
        )
        let layer = LayerRecord(
            name: "Raster",
            mask: LayerMaskRecord(
                tileReferences: [
                    RasterTileReference(
                        coordinate: TileCoordinate(x: 99, y: 99),
                        relativePath: "/absolute.png"
                    ),
                ]
            ),
            kind: .raster(
                RasterLayerContent(tileReferences: [safeTile, duplicateUnsafeTile])
            )
        )
        let artboard = ArtboardRecord(
            name: "Tiles",
            frame: CanvasRect(x: 0, y: 0, width: 256, height: 256),
            pixelWidth: 256,
            pixelHeight: 256,
            rootLayerIDs: [layer.id],
            layers: [layer]
        )
        let issues = ProjectManifestV1(title: "Tiles", artboards: [artboard])
            .validationIssues()

        #expect(issues.filter { $0.code == .invalidTile }.count >= 2)
        #expect(issues.filter { $0.code == .unsafeTilePath }.count == 2)
    }

    @Test
    func testInvalidVisualValuesAreReported() {
        var project = ProjectManifestV1.sampleProject()
        project.artboards[0].background.alpha = 2
        project.artboards[0].layers[0].opacity = .nan
        project.artboards[0].frame.size.width = -.infinity
        project.artboards[0].dpi = 0

        let codes = Set(project.validationIssues().map(\.code))
        #expect(codes.contains(.invalidColor))
        #expect(codes.contains(.invalidOpacity))
        #expect(codes.contains(.invalidGeometry))
        #expect(codes.contains(.invalidDPI))
    }

    @Test
    func testWorkspacePersistsPinnedToolsAndBottomArtboards() throws {
        let workspace = WorkspaceDescriptor.essentials()
        #expect(
            workspace.pinnedTools
                == [.objectSelection, .brush, .eraser, .shape, .text, .crop]
        )
        let bottomPlacement = try #require(
            workspace.placements.first { $0.zone == .bottom }
        )
        let bottomGroup = try #require(
            workspace.panelGroups.first { $0.id == bottomPlacement.groupID }
        )
        #expect(bottomGroup.panelIDs.contains(.artboards))

        let decoded = try JSONDecoder().decode(
            WorkspaceDescriptor.self,
            from: JSONEncoder().encode(workspace)
        )
        #expect(decoded == workspace)
    }

    @Test
    func testWorkspacePersistsExactPinnedShelfItemsInOrder() throws {
        let items: [WorkspacePinnedItem] = [
            .tool(.rectangle),
            .tool(.ellipse),
            .action(.gouacheBrush),
            .tool(.brush),
            .action(.exportPNG),
            .action(.exportSVG),
        ]
        var workspace = WorkspaceDescriptor.essentials()
        workspace.pinnedItems = items
        workspace.pinnedTools = WorkspacePinnedItem.compatibilityProjection(
            for: items
        )

        #expect(workspace.pinnedTools == [.shape, .brush])

        let data = try JSONEncoder().encode(workspace)
        let json = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let encodedItems = try #require(
            json["pinnedItems"] as? [[String: String]]
        )
        #expect(encodedItems.map { $0["kind"] } == [
            "tool", "tool", "action", "tool", "action", "action",
        ])
        #expect(encodedItems.map { $0["identifier"] } == [
            "rectangle",
            "ellipse",
            "gouache-brush",
            "brush",
            "export-png",
            "export-svg",
        ])

        let decoded = try JSONDecoder().decode(
            WorkspaceDescriptor.self,
            from: data
        )
        #expect(decoded.pinnedItems == items)
        #expect(decoded.pinnedTools == [.shape, .brush])
    }

    @Test
    func testManifestWithoutExactPinnedItemsStillDecodes() throws {
        var project = ProjectManifestV1.sampleProject()
        project.workspace.pinnedItems = [
            .tool(.ellipse),
            .action(.exportPNG),
        ]
        project.workspace.pinnedTools = [.shape]

        let encoded = try JSONEncoder().encode(project)
        var legacyJSON = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var legacyWorkspace = try #require(
            legacyJSON["workspace"] as? [String: Any]
        )
        legacyWorkspace.removeValue(forKey: "pinnedItems")
        legacyJSON["workspace"] = legacyWorkspace
        let legacyData = try JSONSerialization.data(withJSONObject: legacyJSON)

        let decoded = try JSONDecoder().decode(
            ProjectManifestV1.self,
            from: legacyData
        )
        #expect(decoded.workspace.pinnedItems == nil)
        #expect(decoded.workspace.pinnedTools == [.shape])
    }

    @Test
    func testExactPinnedItemsRejectDuplicatesAndProjectionMismatch() {
        var project = ProjectManifestV1.sampleProject()
        project.workspace.pinnedItems = [
            .tool(.rectangle),
            .tool(.rectangle),
        ]
        project.workspace.pinnedTools = [.shape]
        #expect(
            project.validationIssues().contains {
                $0.code == .invalidWorkspace
                    && $0.path == "workspace.pinnedItems"
            }
        )

        project.workspace.pinnedItems = [
            .tool(.ellipse),
            .action(.exportPNG),
        ]
        project.workspace.pinnedTools = [.brush]
        #expect(
            project.validationIssues().contains {
                $0.code == .invalidWorkspace
                    && $0.path == "workspace.pinnedTools"
            }
        )
    }

    @Test
    func testInvalidWorkspaceReferencesAndDuplicatePinnedToolsAreReported() {
        var project = ProjectManifestV1.sampleProject()
        project.workspace.pinnedTools.append(project.workspace.pinnedTools[0])
        project.workspace.placements[0].groupID = UUID()

        let issues = project.validationIssues()
        #expect(issues.contains { $0.code == .invalidWorkspace })
        #expect(issues.contains { $0.code == .missingReference })
        #expect(issues.contains { $0.code == .orphanedRecord })
    }

    @Test
    func testPointerSamplesAndTileDeltasRoundTrip() throws {
        let sample = PointerSample(
            location: CanvasPoint(x: 10, y: 20),
            timestamp: 4.5,
            pressure: 0.72,
            tiltX: 0.1,
            tiltY: -0.2,
            azimuth: 1.4,
            phase: .began,
            device: .stylus,
            modifiers: [.shift, .option]
        )
        #expect(
            try JSONDecoder().decode(
                PointerSample.self,
                from: JSONEncoder().encode(sample)
            ) == sample
        )

        let before = Data([0, 1, 2])
        let after = Data([3, 4, 5, 6])
        let delta = TileDelta(
            artboardID: UUID(),
            layerID: UUID(),
            coordinate: TileCoordinate(x: 2, y: 3),
            beforeData: before,
            afterData: after
        )
        #expect(delta.before.data == before)
        #expect(delta.after.data == after)
        #expect(delta.estimatedByteCount == 7)

        let transaction = EditTransaction(
            name: "Brush Stroke",
            kind: .stroke,
            artboardID: delta.artboardID,
            layerID: delta.layerID,
            tileDeltas: [delta]
        )
        #expect(transaction.estimatedByteCount == 7)
        #expect(
            try JSONDecoder().decode(
                EditTransaction.self,
                from: JSONEncoder().encode(transaction)
            ) == transaction
        )
    }

    @Test
    func testGeometryIsPlatformIndependentAndPredictable() {
        let rect = CanvasRect(x: 10, y: 20, width: 100, height: 50)
        #expect(rect.contains(CanvasPoint(x: 10, y: 20)))
        #expect(rect.contains(CanvasPoint(x: 110, y: 70)))
        #expect(!rect.contains(CanvasPoint(x: 111, y: 70)))

        let transform = CanvasTransform(a: 2, d: 3, tx: 5, ty: 7)
        #expect(
            transform.applying(to: CanvasPoint(x: 4, y: 6))
                == CanvasPoint(x: 13, y: 25)
        )
    }

    @Test
    func testCoreContractsAreSendable() {
        func requireSendable<T: Sendable>(_: T) {}

        let project = ProjectManifestV1.sampleProject()
        requireSendable(project)
        requireSendable(project.artboards[0])
        requireSendable(project.artboards[0].layers[0])
        requireSendable(project.workspace)
        requireSendable(
            PointerSample(location: .zero, timestamp: 0)
        )
    }
}
