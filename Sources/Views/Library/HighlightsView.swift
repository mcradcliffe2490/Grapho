import SwiftUI

/// Phase 3 placeholder. Real implementation in Phase 5+ once highlights are
/// being captured by the reader.
struct HighlightsView: View {
    var body: some View {
        EmptyLibraryStub(
            title: "Highlights",
            message: "Highlighted passages will appear here once you start reading."
        )
    }
}

#Preview {
    NavigationStack { HighlightsView() }
}
