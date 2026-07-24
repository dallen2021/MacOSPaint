import SwiftUI

struct InspectorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var studio: StudioState

    var body: some View {
        let palette = StudioPalette(colorScheme)

        GeometryReader { proxy in
            VStack(spacing: 0) {
                inspectorPicker
                    .padding(12)

                Rectangle()
                    .fill(palette.border)
                    .frame(height: 1)

                layerList(palette: palette)
                    .frame(height: min(260, max(225, proxy.size.height * 0.28)))

                layerActions(palette: palette)
                    .frame(height: 48)

                Rectangle()
                    .fill(palette.border)
                    .frame(height: 1)

                propertyPicker
                    .padding(12)

                Rectangle()
                    .fill(palette.border)
                    .frame(height: 1)

                Group {
                    if studio.propertyMode == .properties {
                        PropertiesPanel()
                    } else {
                        ColorPanel()
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .background(palette.panel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inspector")
    }

    private var inspectorPicker: some View {
        Picker("Inspector", selection: $studio.inspectorMode) {
            ForEach(StudioInspectorMode.allCases) { mode in
                Text(mode.rawValue)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Inspector content")
    }

    private var propertyPicker: some View {
        Picker("Property inspector", selection: $studio.propertyMode) {
            ForEach(StudioPropertyMode.allCases) { mode in
                Text(mode.rawValue)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Properties or color")
    }

    private func layerList(palette: StudioPalette) -> some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(studio.selectedArtboard.layers) { layer in
                    layerRow(layer, palette: palette)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            studio.inspectorMode == .layers ? "Layers for active artboard" : "Objects for active artboard"
        )
    }

    private func layerRow(_ layer: StudioLayerItem, palette: StudioPalette) -> some View {
        let isSelected = studio.selectedLayerID == layer.id

        return HStack(spacing: 0) {
            Button {
                studio.selectedLayerID = layer.id
            } label: {
                HStack(spacing: 9) {
                    if layer.isExpandable {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .frame(width: 8)
                    } else {
                        Color.clear
                            .frame(width: 8)
                    }

                    if let swatch = layer.swatch {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(swatch)
                            .frame(width: 21, height: 17)
                            .overlay {
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(palette.strongerBorder, lineWidth: 1)
                            }
                    } else {
                        Image(systemName: layer.symbol)
                            .font(.system(size: 13))
                            .frame(width: 21)
                    }

                    Text(layer.name)
                        .font(.system(size: 11.5, weight: isSelected ? .medium : .regular))
                        .lineLimit(1)

                    Spacer(minLength: 4)
                }
                .frame(maxWidth: .infinity, minHeight: 37, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layer.name)
            .accessibilityValue(layer.isVisible ? "Visible" : "Hidden")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .help("Select \(layer.name)")

            Button {
                studio.toggleLayerVisibility(layer.id)
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 11))
                    .frame(width: 24, height: 28)
                    .contentShape(Rectangle())
                    .opacity(layer.isPreviewVisibilityAvailable ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                layer.isPreviewVisibilityAvailable
                    ? (layer.isVisible ? "Hide \(layer.name)" : "Show \(layer.name)")
                    : "Flattened preview for \(layer.name); visibility read-only"
            )
            .help(
                layer.isPreviewVisibilityAvailable
                    ? (layer.isVisible ? "Hide \(layer.name)" : "Show \(layer.name)")
                    : "Flattened sample layer; visibility is read-only"
            )
        }
        .foregroundStyle(layer.isVisible ? palette.primary : palette.secondary)
        .padding(.horizontal, 9)
        .frame(height: 37)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? palette.selection : Color.clear)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }

    private func layerActions(palette: StudioPalette) -> some View {
        HStack {
            Button {
                studio.addLayer()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add layer")

            Spacer()

            Button {
                studio.duplicateSelectedLayer()
            } label: {
                Image(systemName: "square.on.square")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("Duplicate selected layer")
            .help("Layer duplication is reserved for editor completion")

            Button {
                studio.deleteSelectedLayer()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(studio.selectedLayer?.isPreviewVisibilityAvailable != true)
            .accessibilityLabel("Delete selected layer")
            .help(
                studio.selectedLayer?.isPreviewVisibilityAvailable == true
                    ? "Delete selected layer"
                    : "Flattened sample layers are read-only"
            )
            .keyboardShortcut(.delete, modifiers: [.command])
        }
        .padding(.horizontal, 14)
        .foregroundStyle(palette.primary)
    }
}

private struct PropertiesPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var studio: StudioState

    var body: some View {
        let palette = StudioPalette(colorScheme)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if studio.selectedLayer?.isPreviewVisibilityAvailable != true {
                    Label("Flattened preview · read only", systemImage: "lock.fill")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if studio.selectedLayer?.symbol == "textformat" {
                    textProperties(palette: palette)
                } else {
                    layerProperties(palette: palette)
                }

                Divider()

                transformProperties(palette: palette)

                Divider()

                arrangeProperties(palette: palette)
            }
            .padding(14)
            .disabled(studio.selectedLayer?.isPreviewVisibilityAvailable != true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Properties")
    }

    private func textProperties(palette: StudioPalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Text")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)

            InspectorMenuField(title: "Playfair Display")

            HStack(spacing: 7) {
                InspectorMenuField(title: "Bold")
                InspectorValueField(value: "112 pt", width: 68)

                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 0.02, green: 0.24, blue: 0.31))
                    .frame(width: 46, height: 27)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(palette.strongerBorder, lineWidth: 1)
                    }
                    .accessibilityLabel("Text color, deep teal")
            }

            HStack(spacing: 0) {
                ForEach(
                    ["text.alignleft", "text.aligncenter", "text.alignright", "list.bullet"],
                    id: \.self
                ) { symbol in
                    Button {
                        studio.selectedTextAlignmentSymbol = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.plain)
                    .background(
                        symbol == studio.selectedTextAlignmentSymbol
                            ? palette.selection
                            : .clear
                    )
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(palette.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Text alignment")

            HStack(spacing: 7) {
                InspectorValueField(value: "AV   0")
                InspectorValueField(value: "↕   1.00")
            }
        }
    }

    private func layerProperties(palette: StudioPalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Layer")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)

            InspectorValueField(value: studio.selectedLayer?.name ?? "No selection")

            HStack(spacing: 7) {
                InspectorMenuField(title: "Normal")
                InspectorValueField(value: "100%")
            }
        }
    }

    private func transformProperties(palette: StudioPalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Transform")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 7) {
                InspectorValueField(value: "W   904 px")
                InspectorValueField(value: "X   88 px")
            }

            HStack(spacing: 7) {
                InspectorValueField(value: "H   312 px")
                InspectorValueField(value: "Y   72 px")
                InspectorMenuField(title: "0°", width: 58)
            }
        }
    }

    private func arrangeProperties(palette: StudioPalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Arrange")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(
                    [
                        "align.horizontal.left",
                        "align.horizontal.center",
                        "align.horizontal.right",
                        "align.vertical.top",
                        "align.vertical.center",
                        "align.vertical.bottom"
                    ],
                    id: \.self
                ) { symbol in
                    Button {
                        studio.showNotice(
                            title: "Align Objects",
                            message: "Object alignment is connected to the typed vector transaction seam and will become editable in the vector milestone."
                        )
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(palette.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct ColorPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var studio: StudioState
    @State private var hue = 0.52
    @State private var saturation = 0.84
    @State private var brightness = 0.33
    @State private var opacity = 1.0

    private let swatches: [Color] = [
        Color(red: 0.02, green: 0.24, blue: 0.31),
        Color(red: 0.02, green: 0.49, blue: 0.50),
        Color(red: 0.96, green: 0.91, blue: 0.81),
        Color(red: 0.98, green: 0.28, blue: 0.18),
        Color(red: 0.91, green: 0.51, blue: 0.28),
        Color(red: 0.31, green: 0.41, blue: 0.31),
        .black,
        .white
    ]

    var body: some View {
        let palette = StudioPalette(colorScheme)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        Color(
                            hue: hue,
                            saturation: saturation,
                            brightness: brightness,
                            opacity: opacity
                        )
                    )
                    .frame(height: 66)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(palette.strongerBorder, lineWidth: 1)
                    }
                    .accessibilityLabel("Current color")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(Array(swatches.enumerated()), id: \.offset) { index, swatch in
                        Button {
                            if index == 3 {
                                hue = 0.02
                                saturation = 0.82
                                brightness = 0.98
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(swatch)
                                .frame(height: 31)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(palette.strongerBorder, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color swatch \(index + 1)")
                    }
                }

                ColorSliderRow(title: "Hue", value: $hue)
                ColorSliderRow(title: "Saturation", value: $saturation)
                ColorSliderRow(title: "Brightness", value: $brightness)
                ColorSliderRow(title: "Opacity", value: $opacity)
                    .onChange(of: opacity) { _, value in
                        studio.brushOpacity = value
                    }
            }
            .padding(14)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Color controls")
    }
}

private struct ColorSliderRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value * 100))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $value, in: 0 ... 1)
                .controlSize(.small)
                .accessibilityLabel(title)
        }
    }
}

private struct InspectorValueField: View {
    @Environment(\.colorScheme) private var colorScheme
    let value: String
    var width: CGFloat? = nil

    var body: some View {
        let palette = StudioPalette(colorScheme)

        Text(value)
            .font(.system(size: 10.5))
            .lineLimit(1)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .frame(width: width, height: 28, alignment: .leading)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(palette.secondaryPanel.opacity(0.55))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(palette.border, lineWidth: 1)
                    }
            }
            .accessibilityLabel(value)
    }
}

private struct InspectorMenuField: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var width: CGFloat? = nil

    var body: some View {
        let palette = StudioPalette(colorScheme)

        HStack {
            Text(title)
                .font(.system(size: 10.5))
                .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .frame(width: width, height: 28)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(palette.secondaryPanel.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(palette.border, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}
