import SwiftUI

/// Picks the reading layout based on iPad orientation: Reader (portrait) or
/// Scholar (landscape). One container so the navigation destination stays
/// type-uniform — the picker is hidden inside.
///
/// Geometry-based detection (rather than `UIDevice.current.orientation`)
/// because it survives Slide Over / Split View cleanly: a Slide Over panel
/// in landscape can still render Reader-portrait if the *window* is narrow.
struct ReaderContainerView: View {
    let route: ChapterRoute
    let navigation: ReaderNavigation

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                ScholarReaderView(route: route, navigation: navigation)
            } else {
                ChapterReaderView(route: route, navigation: navigation)
            }
        }
    }
}
