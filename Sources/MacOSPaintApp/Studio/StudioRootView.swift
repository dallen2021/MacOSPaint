import SwiftUI

struct StudioRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var studio: StudioState

    var body: some View {
        let palette = StudioPalette(colorScheme)

        VStack(spacing: 0) {
            TopShelfView()
                .frame(height: 76)

            Rectangle()
                .fill(palette.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                ToolRailView()
                    .frame(width: 58)

                Rectangle()
                    .fill(palette.border)
                    .frame(width: 1)

                CanvasWorkspaceView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Rectangle()
                    .fill(palette.border)
                    .frame(width: 1)

                InspectorView()
                    .frame(width: 310)
            }
        }
        .background(palette.chrome)
        .foregroundStyle(palette.primary)
        .preferredColorScheme(studio.appearance.colorScheme)
        .frame(minWidth: 1_060, minHeight: 700)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("MacOSPaint editing studio")
        .alert(item: $studio.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onOpenURL { url in
            studio.openProject(at: url)
        }
    }
}
