import SwiftUI

/// Picks the reading surface for a chapter. Two axes:
/// - Reading practice (design turn 4): Read & Study, or Paper — an app-wide
///   preference chosen at first run and changeable in Settings.
/// - Geometry (Read & Study only): Reader (portrait) or Scholar (landscape
///   reflow split). Geometry-based rather than `UIDevice.orientation` so it
///   survives Slide Over / Split View cleanly.
struct ReaderContainerView: View {
    @AppStorage(PreferenceKey.readingMode) private var readingModeRaw: String = ReadingMode.default.rawValue

    let route: ChapterRoute
    let navigation: ReaderNavigation

    var body: some View {
        switch ReadingMode.current(rawValue: readingModeRaw) {
        case .paper:
            PaperChapterView(route: route, navigation: navigation)
        case .readStudy:
            GeometryReader { geo in
                if geo.size.width > geo.size.height {
                    ScholarReaderView(route: route, navigation: navigation)
                } else {
                    ChapterReaderView(route: route, navigation: navigation)
                }
            }
        }
    }
}
