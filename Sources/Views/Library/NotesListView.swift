import SwiftUI

/// Phase 3 placeholder. Real implementation in Phase 6+ once typed notes are
/// being captured.
struct NotesListView: View {
    var body: some View {
        EmptyLibraryStub(
            title: "Notes",
            message: "Verse notes you write will appear here, grouped by passage."
        )
    }
}

#Preview {
    NavigationStack { NotesListView() }
}
