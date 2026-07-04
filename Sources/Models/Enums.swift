import Foundation
import SwiftUI

/// Three fixed annotation layers per chapter (design doc §04).
/// Exactly one is active in Scholar mode; switching layers replaces what's visible.
enum LayerKind: String, Codable, CaseIterable, Identifiable {
    case exegetical
    case devotional
    case thematic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exegetical: return "Exegetical"
        case .devotional: return "Devotional"
        case .thematic:   return "Thematic"
        }
    }

    var shortLabel: String {
        switch self {
        case .exegetical: return "E"
        case .devotional: return "D"
        case .thematic:   return "T"
        }
    }

    var accentColor: Color {
        switch self {
        case .exegetical: return AppColor.layerExegetical
        case .devotional: return AppColor.layerDevotional
        case .thematic:   return AppColor.layerThematic
        }
    }

    /// One-line description under the mode name in its study "room"
    /// (design turn 7a).
    var tagline: String {
        switch self {
        case .exegetical: return "the words themselves — grammar, sense, sources"
        case .devotional: return "the text and your heart — prayer, response"
        case .thematic:   return "threads across the whole — motifs, echoes"
        }
    }
}

/// The app-wide reading practice (design turn 4): structured study with
/// modes and verse-tied annotations, or a freeform page per chapter. A
/// chosen season, not a toggle — set at first run, changeable in Settings.
enum ReadingMode: String, Codable, CaseIterable, Identifiable {
    case readStudy
    case paper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .readStudy: return "Read & Study"
        case .paper:     return "Paper"
        }
    }

    var blurb: String {
        switch self {
        case .readStudy:
            return "Structured study across three modes. Highlights and notes tied to each verse, indexed and searchable."
        case .paper:
            return "A blank page for each chapter. Draw, annotate, and write freely — kept exactly as you left it."
        }
    }

    static let `default`: ReadingMode = .readStudy

    static func current(rawValue: String) -> ReadingMode {
        ReadingMode(rawValue: rawValue) ?? .default
    }
}

/// Distinguishes a free-form typed note from a section-header note. Both live
/// on the same `VerseNote` model since they share the same anchor (verse) and
/// lifecycle, but render and behave differently in the UI.
enum NoteKind: String, Codable {
    case note
    case sectionHeader
}

/// Highlight palette — four colors per design doc §05.
enum HighlightColor: String, Codable, CaseIterable, Identifiable {
    case yellow, blue, green, pink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: return AppColor.highlightYellow
        case .blue:   return AppColor.highlightBlue
        case .green:  return AppColor.highlightGreen
        case .pink:   return AppColor.highlightPink
        }
    }
}

/// Section-header rendering mode. Two modes only: the bundled WEB and most
/// public-domain Bible JSON sources do not carry section headers, so the
/// "translation headers" mode from the original spec is dropped.
enum HeaderMode: String, Codable, CaseIterable, Identifiable {
    case none
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:   return "None"
        case .custom: return "Custom"
        }
    }
}
