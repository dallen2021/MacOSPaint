import SwiftUI

struct ArtboardFilmstripView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var studio: StudioState

    var body: some View {
        let palette = StudioPalette(colorScheme)

        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text("Artboards")
                    .font(.system(size: 11, weight: .semibold))

                Button {
                    studio.addArtboard()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 21, height: 20)
                        .background {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(palette.secondaryPanel)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(palette.border, lineWidth: 1)
                                }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add artboard")

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(Array(studio.artboards.enumerated()), id: \.element.id) { index, artboard in
                        artboardThumbnail(artboard, number: index + 1, palette: palette)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(palette.chrome)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Artboards")
    }

    private func artboardThumbnail(
        _ artboard: StudioArtboard,
        number: Int,
        palette: StudioPalette
    ) -> some View {
        let isSelected = studio.selectedArtboardID == artboard.id
        let previewHeight: CGFloat = 96
        let previewWidth = min(160, previewHeight * artboard.aspectRatio)

        return Button {
            studio.selectArtboard(artboard.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    artboard.background.studioColor

                    if artboard.isIllustrationVisible {
                        StudioAssetImage(
                            assetName: artboard.previewAssetName,
                            fallbackColor: artboard.background.studioColor
                        )
                            .aspectRatio(artboard.aspectRatio, contentMode: .fill)
                            .clipped()
                    }

                    StudioRasterTileOverlay(
                        tiles: studio.rasterTilePresentations(
                            for: artboard.id
                        ),
                        pixelWidth: artboard.pixelWidth,
                        pixelHeight: artboard.pixelHeight
                    )

                    if artboard.areBrushStrokesVisible {
                        StudioBrushStrokeOverlay(
                            strokes: studio.brushStrokes(for: artboard.id)
                        )
                    }
                }
                    .frame(width: previewWidth, height: previewHeight)
                    .scaleEffect(x: studio.isCanvasMirrored ? -1 : 1, y: 1)
                    .clipped()
                    .background(palette.thumbnailBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(
                                isSelected ? palette.accent : palette.strongerBorder,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(number)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? palette.accent : palette.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(artboard.name)
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                        Text("\(artboard.pixelWidth) × \(artboard.pixelHeight)")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .frame(width: max(previewWidth, 110), alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Artboard \(number), \(artboard.name), \(artboard.pixelWidth) by \(artboard.pixelHeight)"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
