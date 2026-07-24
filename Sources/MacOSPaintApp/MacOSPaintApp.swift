import AppKit
import SwiftUI

@main
struct MacOSPaintApp: App {
    @NSApplicationDelegateAdaptor(StudioAppDelegate.self) private var appDelegate
    @StateObject private var studio = StudioState()

    var body: some Scene {
        WindowGroup("MacOSPaint") {
            StudioRootView()
                .environmentObject(studio)
                .preferredColorScheme(studio.appearance.colorScheme)
        }
        .defaultSize(width: 1_488, height: 1_058)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            StudioCommands(studio: studio)
        }
    }
}

@MainActor
final class StudioAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        let iconURL = Bundle.module.url(
            forResource: "AppIcon",
            withExtension: "icns"
        ) ?? Bundle.module.url(
            forResource: "AppIcon",
            withExtension: "png"
        )
        if let iconURL,
            let icon = NSImage(contentsOf: iconURL)
        {
            NSApplication.shared.applicationIconImage = icon
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct StudioCommands: Commands {
    @ObservedObject var studio: StudioState

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save Project…") {
                studio.saveProjectWithPanel()
            }
            .keyboardShortcut("s", modifiers: .command)
        }

        CommandMenu("Tools") {
            toolCommand("Object Select", tool: .objectSelect, key: "v")
            toolCommand("Brush", tool: .brush, key: "b")
            toolCommand("Pencil", tool: .pencil, key: "n")
            toolCommand("Eraser", tool: .eraser, key: "e")
            toolCommand("Crop", tool: .crop, key: "c")
            toolCommand("Text", tool: .text, key: "t")
            toolCommand("Pen", tool: .pen, key: "p")
            toolCommand("Fill", tool: .fill, key: "g")
            toolCommand("Eyedropper", tool: .eyedropper, key: "i")
            Divider()
            toolCommand("Hand", tool: .hand, key: "h")
            toolCommand("Zoom", tool: .zoom, key: "z")
        }

        CommandMenu("Canvas") {
            Button("Zoom In") {
                studio.stepZoom(0.10)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom Out") {
                studio.stepZoom(-0.10)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Actual Size") {
                studio.setZoom(1)
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            Toggle("Synchronized Zoom", isOn: $studio.synchronizedZoom)
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        CommandMenu("Workspace") {
            ForEach(StudioWorkspace.allCases) { workspace in
                Button(workspace.rawValue) {
                    studio.workspace = workspace
                }
            }

            Divider()

            ForEach(StudioAppearance.allCases) { appearance in
                Button("\(appearance.title) Appearance") {
                    studio.setAppearance(appearance)
                }
            }
        }
    }

    private func toolCommand(
        _ title: String,
        tool: StudioToolID,
        key: KeyEquivalent
    ) -> some View {
        Button(title) {
            studio.selectTool(tool)
        }
        .keyboardShortcut(key, modifiers: [])
    }
}
