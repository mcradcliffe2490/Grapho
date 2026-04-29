import SwiftUI

/// Phase 3 placeholder. Real settings (palette picker, header mode toggle,
/// pencil-only-draw, translation manager) land in Phase 7.
struct SettingsView: View {
    @Environment(BibleStore.self) private var bibleStore

    var body: some View {
        List {
            Section("Translation") {
                LabeledContent("Active") {
                    Text(bibleStore.translation?.displayName ?? "—")
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            Section {
                Text("More settings coming soon — palette, headers, Pencil-only drawing, translation management.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textFaint)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
