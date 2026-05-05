import SwiftUI

/// Typography tokens. Body type is Crimson Text (a traditional serif tuned for
/// long-form reading); UI chrome is Inter (the variable sans-serif from rsms).
/// Both are bundled in `Resources/Fonts/` and registered via `UIAppFonts`.
///
/// SwiftUI resolves Inter's variable weight axis when we apply `.fontWeight()`
/// to a `Font.custom("Inter", …)` value — the named instances ("Inter-Medium",
/// "Inter-SemiBold") are also exposed by the variable file, but using the
/// modifier path keeps the call sites uniform with the rest of SwiftUI.
enum AppFont {
    // MARK: - Scripture body (Crimson Text)

    /// Long-form scripture body. 17pt with loose leading reads comfortably on
    /// iPad without the lines getting too long; pairs with `lineSpacing(8)`
    /// from `AppSpacing.scriptureLineSpacing`.
    static let scriptureBody = Font.custom("CrimsonText-Regular", size: 17, relativeTo: .body)

    /// Same body face used for chapter titles, scaled larger.
    static let chapterTitleNumeral = Font.custom("CrimsonText-Regular", size: 56, relativeTo: .largeTitle)

    /// Italic Crimson for Psalm superscriptions.
    static let superscription = Font.custom("CrimsonText-Italic", size: 13, relativeTo: .footnote)

    // MARK: - UI chrome (Inter)

    /// Verse number — 11pt Inter, rendered as a baseline-offset superscript.
    static let verseNumber = Font.custom("Inter", size: 11, relativeTo: .caption)

    /// User-authored section headers — small caps via tracking + uppercased
    /// text rather than a font feature, since Inter's small caps coverage is
    /// uneven at small sizes.
    static let sectionHeader = Font.custom("Inter", size: 12, relativeTo: .footnote)

    /// "GRAPHO" wordmark, USFM reference label, and active-layer indicator
    /// in the top toolbar — all share the same hairline tracked-caps style.
    static let wordmark = Font.custom("Inter", size: 12, relativeTo: .footnote)

    /// "JOHN" small caps label above the chapter numeral.
    static let chapterTitleBookLabel = Font.custom("Inter", size: 13, relativeTo: .callout)

    /// Layer-tab pill ("Exegetical / Devotional / Thematic" inside the right
    /// pane).
    static let layerIndicator = Font.custom("Inter", size: 11, relativeTo: .caption)

    /// "CONTINUE READING" tiny caps label on the home card and similar.
    static let microCaps = Font.custom("Inter", size: 10, relativeTo: .caption2)

    /// Default UI body — settings rows, list items.
    static let uiBody = Font.custom("Inter", size: 14, relativeTo: .body)

    /// Section dividers like "Old Testament" / "New Testament" on Home.
    static let listSection = Font.custom("Inter", size: 11, relativeTo: .caption)

    /// Plain book name in the home columnar list — serif for warmth.
    static let bookListName = Font.custom("CrimsonText-Regular", size: 16, relativeTo: .body)

    /// Big chapter tile numeral.
    static let chapterTileNumber = Font.custom("CrimsonText-Regular", size: 18, relativeTo: .body)

    /// Sticky chapter title (kept for compatibility with views that still
    /// reference it; sized to fit the inline header strip).
    static let stickyTitle = Font.custom("Inter", size: 12, relativeTo: .footnote)
}

/// Spacing tokens.
enum AppSpacing {
    /// Reading column horizontal margins (Reader portrait).
    static let readingMarginLeading: CGFloat = 28
    static let readingMarginTrailing: CGFloat = 56

    static let verseSpacingProse: CGFloat = 12
    static let verseSpacingPoetic: CGFloat = 6

    /// Line height multiplier for body text.
    static let scriptureLineSpacing: CGFloat = 8

    static let pullToAdvanceThreshold: CGFloat = 90
    static let stickyTitleHeight: CGFloat = 44
    static let chapterTopPadding: CGFloat = 32

    /// Tracking applied to small-caps headers ("NICODEMUS VISITS JESUS",
    /// "OLD TESTAMENT", etc.).
    static let smallCapsTracking: CGFloat = 2
}

/// Reader vs Scholar layout. Scholar takes the right half of the screen for
/// the notes pane, so the reader column gets wider margins to keep the line
/// length comfortable.
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
