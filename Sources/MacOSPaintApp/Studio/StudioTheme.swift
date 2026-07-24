import AppKit
import SwiftUI

enum StudioAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct StudioPalette {
    let isDark: Bool

    init(_ colorScheme: ColorScheme) {
        isDark = colorScheme == .dark
    }

    var chrome: Color {
        isDark ? Color(red: 0.102, green: 0.137, blue: 0.161) : Color(red: 0.975, green: 0.975, blue: 0.97)
    }

    var panel: Color {
        isDark ? Color(red: 0.114, green: 0.153, blue: 0.176) : Color(red: 0.985, green: 0.985, blue: 0.98)
    }

    var secondaryPanel: Color {
        isDark ? Color(red: 0.153, green: 0.196, blue: 0.224) : Color(red: 0.955, green: 0.955, blue: 0.95)
    }

    var canvas: Color {
        isDark ? Color(red: 0.153, green: 0.192, blue: 0.216) : Color(red: 0.925, green: 0.925, blue: 0.915)
    }

    var canvasGradientBottom: Color {
        isDark ? Color(red: 0.18, green: 0.224, blue: 0.247) : Color(red: 0.955, green: 0.955, blue: 0.95)
    }

    var border: Color {
        isDark ? .white.opacity(0.11) : .black.opacity(0.11)
    }

    var strongerBorder: Color {
        isDark ? .white.opacity(0.19) : .black.opacity(0.18)
    }

    var primary: Color {
        isDark ? Color(white: 0.94) : Color(white: 0.12)
    }

    var secondary: Color {
        isDark ? Color(white: 0.69) : Color(white: 0.42)
    }

    var accent: Color {
        Color(red: 0.16, green: 0.49, blue: 0.96)
    }

    var selection: Color {
        isDark ? Color(red: 0.10, green: 0.28, blue: 0.43) : Color(red: 0.86, green: 0.91, blue: 1.0)
    }

    var brushColor: Color {
        Color(red: 0.98, green: 0.28, blue: 0.18)
    }

    var thumbnailBackground: Color {
        isDark ? Color(red: 0.13, green: 0.17, blue: 0.19) : .white.opacity(0.72)
    }
}

struct StudioDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(StudioPalette(colorScheme).border)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct PanelMaterialBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency {
                StudioPalette(colorScheme).panel
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}

extension View {
    func studioPanelBackground() -> some View {
        modifier(PanelMaterialBackground())
    }
}

extension NSColor {
    static let macOSPaintCoral = NSColor(
        calibratedRed: 0.98,
        green: 0.28,
        blue: 0.18,
        alpha: 0.92
    )
}
