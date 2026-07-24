import SwiftUI

struct ToolRailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var studio: StudioState

    private let tools: [StudioToolID] = [
        .objectSelect,
        .directSelect,
        .marqueeRectangle,
        .marqueeEllipse,
        .lasso,
        .polygonLasso,
        .magicWand,
        .crop,
        .text,
        .rectangle,
        .ellipse,
        .pen,
        .pencil,
        .brush,
        .eraser,
        .fill,
        .gradient,
        .eyedropper,
        .cloneStamp,
        .spotHeal,
        .blur,
        .sharpen,
        .smudge,
        .hand,
        .zoom
    ]

    var body: some View {
        let palette = StudioPalette(colorScheme)

        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 3) {
                    ForEach(tools) { tool in
                        toolButton(tool, palette: palette)

                        if tool == .directSelect || tool == .crop || tool == .ellipse ||
                            tool == .eyedropper || tool == .smudge {
                            Rectangle()
                                .fill(palette.border)
                                .frame(width: 24, height: 1)
                                .padding(.vertical, 3)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }

            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.02, green: 0.30, blue: 0.36))
                        .frame(width: 25, height: 25)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.white.opacity(0.6), lineWidth: 1)
                        }

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.96, green: 0.91, blue: 0.81))
                        .frame(width: 18, height: 18)
                        .offset(x: 7, y: 7)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                }
                .frame(width: 36, height: 34)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Foreground teal, background cream")

                Button {
                    studio.selectedTool = .objectSelect
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More tools")
                .help("More tools")
            }
            .padding(.bottom, 12)
        }
        .background(palette.chrome)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tools")
    }

    @ViewBuilder
    private func toolButton(_ tool: StudioToolID, palette: StudioPalette) -> some View {
        let isSelected = studio.selectedTool == tool

        Button {
            studio.selectTool(tool)
        } label: {
            Image(systemName: tool.symbol)
                .font(.system(size: 16, weight: .regular))
                .symbolVariant(isSelected ? .fill : .none)
                .frame(width: 38, height: 34)
                .foregroundStyle(isSelected ? palette.accent : palette.primary.opacity(0.88))
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? palette.selection : Color.clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(tool.keyEquivalent.map { "\(tool.title) (\($0.character.uppercased()))" } ?? tool.title)
    }
}
