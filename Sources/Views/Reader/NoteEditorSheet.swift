import SwiftUI

/// Modal text editor for verse notes and custom section headers. The same
/// component handles both kinds — the parent decides what to do with the
/// resulting text via `onSave`.
struct NoteEditorSheet: View {
    let title: String
    let placeholder: String
    @State private var text: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    init(
        title: String,
        placeholder: String,
        initialText: String = "",
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = State(initialValue: initialText)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(AppColor.textFaint)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                }
                TextEditor(text: $text)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .scrollContentBackground(.hidden)
                    .background(AppColor.background)
            }
            .background(AppColor.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
