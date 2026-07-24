import AppKit
import PaintEngine
import PaintModel
import SwiftUI

struct CanvasWorkspaceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var studio: StudioState

    var body: some View {
        let palette = StudioPalette(colorScheme)

        VStack(spacing: 0) {
            canvasHeader(palette: palette)
                .frame(height: 64)

            Rectangle()
                .fill(palette.border)
                .frame(height: 1)

            artboardPasteboard(palette: palette)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(palette.border)
                .frame(height: 1)

            ArtboardFilmstripView()
                .frame(height: 178)
        }
        .background(palette.canvas)
    }

    private func canvasHeader(palette: StudioPalette) -> some View {
        let visibleArtboards = studio.canvasArtboards

        return HStack(spacing: 16) {
            if let first = visibleArtboards.first {
                artboardBreadcrumb(first, number: 1)
            }

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                Text("Synchronized Zoom")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(palette.secondary)

                Toggle("", isOn: $studio.synchronizedZoom)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .accessibilityLabel("Synchronized zoom")
            }

            if visibleArtboards.count > 1 {
                Rectangle()
                    .fill(palette.border)
                    .frame(width: 1, height: 28)
                    .padding(.horizontal, 2)

                artboardBreadcrumb(visibleArtboards[1], number: 2)
            }

            Spacer(minLength: 4)

            Button {
                studio.exportSelectedArtboardPNG()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 26, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export active artboard")

            Button {
                studio.saveProjectWithPanel()
            } label: {
                Image(systemName: "shippingbox.and.arrow.backward")
                    .frame(width: 26, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save project package")
        }
        .padding(.horizontal, 16)
        .background(palette.chrome)
    }

    private func artboardBreadcrumb(_ artboard: StudioArtboard, number: Int) -> some View {
        Button {
            studio.selectArtboard(artboard.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("Artboard \(number)")
                            .font(.system(size: 11.5, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(artboard.name)
                            .font(.system(size: 11.5, weight: .medium))
                            .lineLimit(1)
                    }

                    Text("\(artboard.pixelWidth) × \(artboard.pixelHeight)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Artboard \(number), \(artboard.name), \(artboard.pixelWidth) by \(artboard.pixelHeight)"
        )
    }

    private func artboardPasteboard(palette: StudioPalette) -> some View {
        GeometryReader { proxy in
            let canvasHeight = max(proxy.size.height, 360)
            let referenceHeight = min(500, canvasHeight * 0.73)
            let visibleArtboards = studio.canvasArtboards
            let proposedSizes = visibleArtboards.enumerated().map { index, artboard in
                let height = index == 0 || artboard.aspectRatio < 0.8
                    ? referenceHeight
                    : referenceHeight * 0.90
                return CGSize(
                    width: height * artboard.aspectRatio,
                    height: height
                )
            }
            let referenceWidth = proposedSizes.reduce(0) { $0 + $1.width }
                + CGFloat(max(visibleArtboards.count - 1, 0)) * 28
            let fit = min(1, max(0.52, (proxy.size.width - 42) / referenceWidth))

            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .center, spacing: 28) {
                    ForEach(Array(visibleArtboards.enumerated()), id: \.element.id) {
                        index,
                        artboard in
                        let proposedSize = proposedSizes[index]
                        let zoom = artboard.id == studio.artboards.first?.id
                            ? studio.primaryZoom
                            : studio.secondaryZoom
                        let zoomScale = zoom / 0.63

                        ArtboardSurfaceView(
                            artboard: artboard,
                            isSelected: studio.selectedArtboardID == artboard.id
                        )
                        .frame(
                            width: proposedSize.width * fit * zoomScale,
                            height: proposedSize.height * fit * zoomScale
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
                .frame(
                    minWidth: proxy.size.width,
                    minHeight: proxy.size.height,
                    alignment: .center
                )
            }
            .scrollIndicators(.hidden)
            .background {
                LinearGradient(
                    colors: [palette.canvas, palette.canvasGradientBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Freeform artboard pasteboard")
    }
}

private struct ArtboardSurfaceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var studio: StudioState
    @FocusState private var hasKeyboardFocus: Bool
    let artboard: StudioArtboard
    let isSelected: Bool

    var body: some View {
        let palette = StudioPalette(colorScheme)

        ZStack {
            StudioAssetImage(
                assetName: artboard.previewAssetName,
                fallbackColor: artboard.background.studioColor
            )
                .aspectRatio(artboard.aspectRatio, contentMode: .fill)
                .clipped()
                .opacity(artboard.isIllustrationVisible ? 1 : 0)
                .scaleEffect(x: studio.isCanvasMirrored ? -1 : 1, y: 1)

            StudioRasterTileOverlay(
                tiles: studio.rasterTilePresentations(for: artboard.id),
                pixelWidth: artboard.pixelWidth,
                pixelHeight: artboard.pixelHeight
            )
            .scaleEffect(x: studio.isCanvasMirrored ? -1 : 1, y: 1)

            if isSelected && studio.selectedTool == .objectSelect &&
                studio.selectedLayer?.name == "COASTAL KEEPERS" &&
                studio.selectedLayer?.isVisible == true {
                SelectionBoundsOverlay()
                    .padding(.horizontal, artboard.aspectRatio > 1.3 ? 44 : 50)
                    .padding(.top, artboard.aspectRatio > 1.3 ? 35 : 30)
                    .padding(.bottom, artboard.aspectRatio > 1.3 ? 205 : 225)
                    .allowsHitTesting(false)
            }

            BrushStrokeSurface(
                artboardID: artboard.id,
                strokes: studio.brushStrokes(for: artboard.id),
                isEnabled: isSelected
                    && studio.selectedTool.acceptsBrushInput
                    && studio.canPaintSelectedArtboard,
                isVisible: artboard.areBrushStrokesVisible,
                isMirrored: studio.isCanvasMirrored,
                brushSize: studio.brushSize,
                opacity: studio.brushOpacity,
                onStrokesChanged: { strokes in
                    studio.setBrushStrokes(strokes, for: artboard.id)
                }
            )
            .id(artboard.id)
        }
        .background(artboard.background.studioColor)
        .overlay {
            Rectangle()
                .stroke(
                    isSelected || hasKeyboardFocus ? palette.accent : palette.strongerBorder,
                    lineWidth: isSelected || hasKeyboardFocus ? 1.5 : 1
                )
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.14), radius: 10, y: 5)
        .contentShape(Rectangle())
        .onTapGesture {
            studio.selectArtboard(artboard.id)
        }
        .focusable()
        .focused($hasKeyboardFocus)
        .onKeyPress(.return) {
            studio.selectArtboard(artboard.id)
            return .handled
        }
        .onKeyPress(.space) {
            studio.selectArtboard(artboard.id)
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(artboard.name) artboard, \(artboard.pixelWidth) by \(artboard.pixelHeight)"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction {
            studio.selectArtboard(artboard.id)
        }
    }
}

struct StudioRasterTileOverlay: View {
    let tiles: [StudioRasterTilePresentation]
    let pixelWidth: Int
    let pixelHeight: Int

    var body: some View {
        GeometryReader { proxy in
            if pixelWidth > 0, pixelHeight > 0 {
                let scaleX = proxy.size.width / CGFloat(pixelWidth)
                let scaleY = proxy.size.height / CGFloat(pixelHeight)
                let tileSize = CGFloat(RasterTileStore.tileSize)

                ZStack(alignment: .topLeading) {
                    ForEach(tiles) { presentation in
                        if let image = StudioRasterTileImages.cgImage(
                            for: presentation.tile
                        ) {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .interpolation(.high)
                                .frame(
                                    width: tileSize * scaleX,
                                    height: tileSize * scaleY
                                )
                                .opacity(presentation.opacity)
                                .blendMode(
                                    presentation.blendMode.swiftUIBlendMode
                                )
                                .offset(
                                    x: CGFloat(
                                        presentation.key.coordinate.x
                                    ) * tileSize * scaleX,
                                    y: CGFloat(
                                        presentation.key.coordinate.y
                                    ) * tileSize * scaleY
                                )
                        }
                    }
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .topLeading
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension PaintModel.BlendMode {
    var swiftUIBlendMode: SwiftUI.BlendMode {
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

private struct SelectionBoundsOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 1.5)

                ForEach(SelectionHandle.allCases) { handle in
                    Circle()
                        .fill(.white)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 9, height: 9)
                        .position(handle.position(in: size))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private enum SelectionHandle: CaseIterable, Identifiable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var id: Self { self }

    func position(in size: CGSize) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: 0, y: 0)
        case .top: CGPoint(x: size.width / 2, y: 0)
        case .topRight: CGPoint(x: size.width, y: 0)
        case .right: CGPoint(x: size.width, y: size.height / 2)
        case .bottomRight: CGPoint(x: size.width, y: size.height)
        case .bottom: CGPoint(x: size.width / 2, y: size.height)
        case .bottomLeft: CGPoint(x: 0, y: size.height)
        case .left: CGPoint(x: 0, y: size.height / 2)
        }
    }
}

struct StudioAssetImage: View {
    let assetName: String
    var fallbackColor: Color? = nil

    var body: some View {
        if let image = StudioAssets.image(named: assetName) {
            Image(nsImage: image)
                .resizable()
        } else {
            ZStack {
                fallbackColor
                    ?? Color(red: 0.94, green: 0.90, blue: 0.80)
                Image(systemName: "photo")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Preview unavailable")
        }
    }
}

enum StudioAssets {
    static func url(named name: String) -> URL? {
        let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
        return url
    }

    static func image(named name: String) -> NSImage? {
        guard let url = url(named: name) else { return nil }
        return NSImage(contentsOf: url)
    }
}
