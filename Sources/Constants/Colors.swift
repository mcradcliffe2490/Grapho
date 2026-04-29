import SwiftUI

/// Design tokens from the Grapho design doc §07.
/// Values are sRGB hex; `Color(hex:)` parses 6-digit and 8-digit (RGBA) hex.
extension Color {
    init(hex: String, alpha: Double = 1.0) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        let r, g, b, a: Double
        switch trimmed.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = alpha
        case 8:
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = alpha
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum AppColor {
    // Reading surface — overridden by the user's selected background palette
    static let background = Color(hex: "#FAF8F5")
    static let surface = Color(hex: "#F2F0EC")
    static let border = Color(hex: "#E8E4DC")

    // Type
    static let textPrimary = Color(hex: "#1C1917")
    static let textSecondary = Color(hex: "#6B7280")
    static let textFaint = Color(hex: "#C4BFB8")
    static let sectionHeader = Color(hex: "#44403C")

    // Highlight overlays — alpha baked in
    static let highlightYellow = Color(hex: "#FDE047", alpha: 0.4)
    static let highlightBlue = Color(hex: "#93C5FD", alpha: 0.4)
    static let highlightGreen = Color(hex: "#86EFAC", alpha: 0.4)
    static let highlightPink = Color(hex: "#F9A8D4", alpha: 0.4)

    // Layer accent colors
    static let layerExegetical = Color(hex: "#4A6FA5")
    static let layerDevotional = Color(hex: "#5A8A6A")
    static let layerThematic = Color(hex: "#8A6A9A")
}

/// The six curated reading-surface options. Default is Off-White (#FAF8F5).
enum BackgroundPalette: String, CaseIterable, Codable, Identifiable {
    case offWhite, warmCream, blush, sageMist, lavenderWash, pureWhite

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .offWhite:      return Color(hex: "#FAF8F5")
        case .warmCream:     return Color(hex: "#FDF6E3")
        case .blush:         return Color(hex: "#FDF0EE")
        case .sageMist:      return Color(hex: "#F0F4F0")
        case .lavenderWash:  return Color(hex: "#F3F0F8")
        case .pureWhite:     return Color(hex: "#FFFFFF")
        }
    }

    var displayName: String {
        switch self {
        case .offWhite:      return "Off-White"
        case .warmCream:     return "Warm Cream"
        case .blush:         return "Blush"
        case .sageMist:      return "Sage Mist"
        case .lavenderWash:  return "Lavender Wash"
        case .pureWhite:     return "Pure White"
        }
    }

    static let `default`: BackgroundPalette = .offWhite
}
