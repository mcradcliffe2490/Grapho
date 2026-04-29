import SwiftUI

/// Typography tokens from the Grapho design doc §07.
/// Scripture body uses New York (Apple's serif system font). UI chrome uses SF Pro Text.
enum AppFont {
    /// 18pt fixed in v1 — dynamic type deferred post-MVP so that PencilKit
    /// drawings remain anchored to a stable reading layout.
    static let scriptureBody = Font.custom("NewYork-Regular", size: 18, relativeTo: .body)
        .leading(.loose)

    static let verseNumber = Font.system(size: 11, weight: .regular, design: .default)

    /// Translation/custom section headers — small caps, letter-spacing 0.08em.
    static let sectionHeader = Font.system(size: 13, weight: .medium, design: .default)
        .smallCaps()

    /// Sticky chapter title — small caps, letter-spacing 0.12em.
    static let stickyTitle = Font.system(size: 13, weight: .medium, design: .default)
        .smallCaps()

    /// Layer indicator (Scholar mode) — all caps in the layer's accent color.
    static let layerIndicator = Font.system(size: 11, weight: .semibold, design: .default)

    /// Psalm superscription — italic small caps centered above verse 1.
    static let superscription = Font.custom("NewYork-Italic", size: 13, relativeTo: .footnote)
        .italic()
        .smallCaps()
}

/// Spacing tokens from the design doc §07.
enum AppSpacing {
    /// Reading column horizontal margins.
    static let readingMarginLeading: CGFloat = 28
    /// Wider trailing margin to give note-indicator dots room to live.
    static let readingMarginTrailing: CGFloat = 56

    /// Inter-verse spacing for prose books — continuous flow.
    static let verseSpacingProse: CGFloat = 0
    /// Looser inter-verse spacing for poetic books.
    static let verseSpacingPoetic: CGFloat = 6

    /// Line height multiplier for body text.
    static let scriptureLineSpacing: CGFloat = 8

    /// Distance the user must overscroll past the last verse before chapter advance commits.
    static let pullToAdvanceThreshold: CGFloat = 90

    /// Sticky title bar height (excludes safe-area inset).
    static let stickyTitleHeight: CGFloat = 44

    /// Top padding below the sticky title before chapter content starts.
    static let chapterTopPadding: CGFloat = 48
}

/// Two reading layouts. The text uses tighter margins in Reader (portrait,
/// full-width) and wider margins in Scholar (split with the scratchpad) so
/// the column doesn't feel cramped against the divider.
enum ReaderStyle {
    case reader
    case scholar

    var leadingMargin: CGFloat {
        switch self {
        case .reader: return AppSpacing.readingMarginLeading
        case .scholar: return 56
        }
    }

    var trailingMargin: CGFloat {
        switch self {
        case .reader: return AppSpacing.readingMarginTrailing
        case .scholar: return 72
        }
    }
}
