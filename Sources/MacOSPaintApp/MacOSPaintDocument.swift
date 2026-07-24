import AppKit
import PaintEngine
import PaintIO
import PaintModel
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let macOSPaintProject = UTType(
        exportedAs: "io.github.dallen2021.macospaint.project",
        conformingTo: .package
    )
}

/// Native document lifecycle seam for `.macospaint` directory packages.
///
/// The SwiftUI demo window starts with an in-memory campaign so `swift run
/// MacOSPaint` is immediately useful. Document-based integrations can vend this
/// class through `NSDocumentController`; package loading and atomic writes are
/// delegated to `ProjectPackageStore`.
@MainActor
final class MacOSPaintDocument: NSDocument {
    private(set) var manifest: ProjectManifestV1
    private(set) var rasterTiles: RasterTileSnapshot
    private let packageStore = ProjectPackageStore()
    private var studioState: StudioState?

    override init() {
        manifest = .sampleProject(title: "Untitled")
        rasterTiles = RasterTileSnapshot(generation: 0, tiles: [:])
        super.init()
        hasUndoManager = true
    }

    init(contents: ProjectPackageContents) {
        manifest = contents.manifest
        rasterTiles = contents.rasterTiles
        super.init()
        hasUndoManager = true
    }

    override class var autosavesInPlace: Bool { true }

    override class var readableTypes: [String] {
        [UTType.macOSPaintProject.identifier]
    }

    override class var writableTypes: [String] {
        [UTType.macOSPaintProject.identifier]
    }

    override func makeWindowControllers() {
        let contents = ProjectPackageContents(
            manifest: manifest,
            rasterTiles: rasterTiles
        )
        let state: StudioState
        do {
            state = try StudioState(contents: contents)
        } catch {
            let errorView = VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                Text("This MacOSPaint project could not be displayed.")
                    .font(.headline)
                Text(error.localizedDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(minWidth: 520, minHeight: 300)
            let hostingController = NSHostingController(rootView: errorView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = manifest.title
            addWindowController(NSWindowController(window: window))
            return
        }
        studioState = state
        let rootView = StudioRootView()
            .environmentObject(state)
            .preferredColorScheme(state.appearance.colorScheme)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 1_488, height: 1_058))
        window.minSize = NSSize(width: 1_060, height: 700)
        window.title = manifest.title
        addWindowController(NSWindowController(window: window))
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        try ProjectPackageStore.fileWrapper(
            for: ProjectPackageContents(
                manifest: manifest,
                rasterTiles: rasterTiles
            )
        )
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        let contents = try ProjectPackageStore.load(from: fileWrapper)
        try MainActor.assumeIsolated {
            manifest = contents.manifest
            rasterTiles = contents.rasterTiles
            try studioState?.load(contents: contents)
        }
    }

    func openPackage(at url: URL) async throws {
        switch try await packageStore.open(at: url) {
        case let .editable(contents):
            manifest = contents.manifest
            rasterTiles = contents.rasterTiles
            try studioState?.load(contents: contents)
        case let .readOnly(package):
            throw ProjectPackageError.newerSchemaIsReadOnly(
                found: package.schemaVersion,
                supported: ProjectPackageStore.supportedSchemaVersion
            )
        }
    }

    func writePackage(to url: URL) async throws {
        let saved = try await packageStore.save(
            ProjectPackageContents(manifest: manifest, rasterTiles: rasterTiles),
            to: url
        )
        manifest = saved.manifest
    }
}
