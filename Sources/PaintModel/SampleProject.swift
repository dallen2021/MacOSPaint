import Foundation

extension ProjectManifestV1 {
    /// Creates the vertical-slice starter document used by the app and previews.
    public static func sampleProject(
        title: String = "Untitled",
        now: Date = Date()
    ) -> ProjectManifestV1 {
        let backgroundLayer = LayerRecord(
            name: "Paint Layer",
            kind: .raster(RasterLayerContent())
        )

        let pathObject = VectorObject(
            name: "Editable Path",
            fill: .none,
            stroke: StrokeStyle(
                color: RGBAColor(red: 0.12, green: 0.45, blue: 0.95),
                width: 8
            ),
            kind: .path(
                VectorPath(
                    nodes: [
                        PathNode(anchor: CanvasPoint(x: 180, y: 460)),
                        PathNode(
                            anchor: CanvasPoint(x: 560, y: 210),
                            incomingControl: CanvasPoint(x: 430, y: 210),
                            outgoingControl: CanvasPoint(x: 700, y: 210),
                            kind: .smooth
                        ),
                        PathNode(anchor: CanvasPoint(x: 980, y: 470)),
                    ]
                )
            )
        )
        let vectorLayer = LayerRecord(
            name: "Editable Path",
            kind: .vector(
                VectorScene(rootObjectIDs: [pathObject.id], objects: [pathObject])
            )
        )
        let primaryArtboard = ArtboardRecord(
            name: "Artboard 1",
            frame: CanvasRect(x: 0, y: 0, width: 1_200, height: 800),
            pixelWidth: 1_200,
            pixelHeight: 800,
            background: .white,
            rootLayerIDs: [vectorLayer.id, backgroundLayer.id],
            layers: [vectorLayer, backgroundLayer]
        )

        let secondPaintLayer = LayerRecord(
            name: "Paint Layer",
            kind: .raster(RasterLayerContent())
        )
        let secondaryArtboard = ArtboardRecord(
            name: "Artboard 2",
            frame: CanvasRect(x: 1_320, y: 160, width: 800, height: 800),
            pixelWidth: 800,
            pixelHeight: 800,
            background: RGBAColor(red: 0.94, green: 0.95, blue: 0.97),
            rootLayerIDs: [secondPaintLayer.id],
            layers: [secondPaintLayer]
        )

        return ProjectManifestV1(
            title: title,
            createdAt: now,
            modifiedAt: now,
            colorSpace: .sRGB,
            artboards: [primaryArtboard, secondaryArtboard],
            workspace: .essentials()
        )
    }
}
