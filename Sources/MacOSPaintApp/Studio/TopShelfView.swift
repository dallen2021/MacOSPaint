import SwiftUI

struct TopShelfView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var studio: StudioState

    var body: some View {
        let palette = StudioPalette(colorScheme)

        HStack(spacing: 0) {
            documentIdentity
                .frame(width: 315, alignment: .leading)

            PinnedToolsShelf()
                .frame(maxWidth: .infinity)

            trailingControls
                .frame(width: 405, alignment: .trailing)
        }
        .padding(.trailing, 14)
        .background {
            if reduceTransparency {
                palette.chrome
            } else {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    palette.chrome.opacity(0.88)
                }
            }
        }
    }

    private var documentIdentity: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("Coastal Keepers Campaign")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text("Edited")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 84)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coastal Keepers Campaign, edited")
    }

    private var trailingControls: some View {
        HStack(spacing: 10) {
            zoomControl

            workspaceControl

            Menu {
                ForEach(StudioAppearance.allCases) { appearance in
                    Button {
                        studio.setAppearance(appearance)
                    } label: {
                        Label(appearance.title, systemImage: appearance.symbol)
                    }
                }
            } label: {
                Image(systemName: studio.appearance.symbol)
                    .font(.system(size: 15))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .accessibilityLabel("Appearance")
            .help("Choose system, light, or dark appearance")

            Button {
                studio.exportSelectedArtboardPNG()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 26, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share or export")
            .help("Share or export")
        }
    }

    private var workspaceControl: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Workspace")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(.leading, 3)

            Menu {
                ForEach(StudioWorkspace.allCases) { workspace in
                    Button {
                        studio.workspace = workspace
                    } label: {
                        if studio.workspace == workspace {
                            Label(workspace.rawValue, systemImage: "checkmark")
                        } else {
                            Text(workspace.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(studio.workspace.rawValue)
                        .font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .frame(width: 108, height: 23, alignment: .leading)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workspace, \(studio.workspace.rawValue)")
        .help("Choose a workspace preset")
    }

    private var zoomControl: some View {
        HStack(spacing: 5) {
            Button {
                studio.stepZoom(-0.10)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 22, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom out")

            Text("\(Int(studio.secondaryZoom * 100))%")
                .font(.system(size: 12, design: .rounded))
                .monospacedDigit()
                .frame(width: 38)

            Button {
                studio.stepZoom(0.10)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 22, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom in")
        }
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .help("Canvas zoom")
    }
}

private struct PinnedToolsShelf: View {
    @EnvironmentObject private var studio: StudioState

    var body: some View {
        GeometryReader { proxy in
            let visibleCount = fittedVisibleItemCount(
                studio.pinnedShelfItems,
                availableWidth: proxy.size.width
            )
            let visible = Array(studio.pinnedShelfItems.prefix(visibleCount))
            let overflow = Array(studio.pinnedShelfItems.dropFirst(visibleCount))

            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                    Text("Pinned")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(width: 42)
                .accessibilityHidden(true)

                ForEach(visible) { item in
                    PinnedShelfButton(item: item)
                }

                if !overflow.isEmpty {
                    Menu {
                        ForEach(overflow) { item in
                            Button {
                                studio.performPinnedShelfItem(item)
                            } label: {
                                Label(item.title, systemImage: item.symbol)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 32, height: 38)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                    .accessibilityLabel("More pinned tools")
                    .help("More pinned tools")
                }

                Menu {
                    Section("Tools") {
                        ForEach(StudioToolID.allCases) { tool in
                            let item = PinnedShelfItem.tool(tool)
                            Button {
                                studio.togglePinned(item)
                            } label: {
                                if studio.isPinned(item) {
                                    Label(tool.title, systemImage: "checkmark")
                                } else {
                                    Label(tool.title, systemImage: tool.symbol)
                                }
                            }
                        }
                    }

                    Section("Actions") {
                        ForEach(PinnedActionID.allCases) { action in
                            let item = PinnedShelfItem.action(action)
                            Button {
                                studio.togglePinned(item)
                            } label: {
                                if studio.isPinned(item) {
                                    Label(action.title, systemImage: "checkmark")
                                } else {
                                    Label(action.title, systemImage: action.symbol)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 38)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .accessibilityLabel("Customize pinned tools")
                .help("Pin or unpin tools")

                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func fittedVisibleItemCount(
        _ items: [PinnedShelfItem],
        availableWidth: CGFloat
    ) -> Int {
        guard !items.isEmpty else { return 0 }

        let fixedWidth: CGFloat = 42 + 30
        let allItemsWidth = items.reduce(fixedWidth) {
            $0 + $1.shelfCardWidth
        } + CGFloat(items.count + 1) * 8
        if allItemsWidth <= availableWidth {
            return items.count
        }

        // Pin label, overflow menu, customization menu, and their two gaps.
        var usedWidth: CGFloat = 42 + 32 + 30 + 16
        var count = 0
        for item in items {
            let addition = item.shelfCardWidth + 8
            guard usedWidth + addition <= availableWidth else { break }
            usedWidth += addition
            count += 1
        }
        return count
    }
}

private struct PinnedShelfButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var studio: StudioState
    let item: PinnedShelfItem

    var body: some View {
        let palette = StudioPalette(colorScheme)
        let isSelectedTool = item.tool == studio.selectedTool

        Button {
            studio.performPinnedShelfItem(item)
        } label: {
            Group {
                if item == .action(.gouacheBrush),
                   let swatch = StudioAssets.image(named: "gouache-swatch") {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 11, weight: .medium))
                            Text(item.title)
                                .font(.system(size: 9.5, weight: .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Text(item.detail ?? "")
                                .font(.system(size: 8.5))
                                .foregroundStyle(.secondary)
                        }

                        Image(nsImage: swatch)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.primary)
                            .frame(width: 82, height: 15, alignment: .leading)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 21)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.system(size: 10.5, weight: .medium))
                                .lineLimit(item.detail == nil ? 2 : 1)
                            if let detail = item.detail {
                                Text(detail)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(width: item.shelfCardWidth, height: 42, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        isSelectedTool
                            ? Color.accentColor.opacity(0.14)
                            : palette.secondaryPanel.opacity(0.7)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(
                                isSelectedTool
                                    ? Color.accentColor.opacity(0.65)
                                    : palette.border,
                                lineWidth: 1
                            )
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Move Left") {
                studio.movePinned(item, by: -1)
            }
            Button("Move Right") {
                studio.movePinned(item, by: 1)
            }
            Divider()
            Button("Unpin") {
                studio.togglePinned(item)
            }
        }
        .accessibilityLabel(item.detail.map { "\(item.title), \($0)" } ?? item.title)
        .accessibilityValue(isSelectedTool ? "Selected" : "")
        .help("\(item.title) — right-click to reorder or unpin")
    }
}

private extension PinnedShelfItem {
    var shelfCardWidth: CGFloat {
        self == .action(.gouacheBrush) ? 132 : 111
    }
}
