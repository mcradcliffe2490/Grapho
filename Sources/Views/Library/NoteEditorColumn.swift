import SwiftUI
import SwiftData

/// The right side of the notes browser split (design turn 10a): a quiet
/// writing surface. Anchor + mode whisper across the top, big serif title,
/// the anchored verse as a mode-colored blockquote, the body, and the
/// threads / linked-mentions footer.
///
/// Saving: SwiftData tracks `@Bindable` writes immediately; `updatedAt` is
/// bumped when the selection moves away so lists re-sort on real edits.
struct NoteEditorColumn: View {
    let note: VerseNote

    @Environment(BibleStore.self) private var bibleStore
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false
    @State private var formatController = MarkdownEditController()

    private var mode: LayerKind { note.layer?.kind ?? .exegetical }

    private var anchorRef: VerseRef? { note.anchorRef }

    private var anchoredVerseText: String? {
        guard let ref = anchorRef else { return nil }
        return bibleStore.translation?
            .chapter(book: ref.book, number: ref.chapter)?
            .verse(ref.verse)?.text
    }

    var body: some View {
        @Bindable var bindable = note
        VStack(alignment: .leading, spacing: 0) {
            topRail

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Title", text: $bindable.title)
                        .font(Font.custom("CrimsonText-Regular", size: 34, relativeTo: .largeTitle))
                        .foregroundStyle(AppColor.textPrimary)
                        .padding(.top, 8)

                    Text("Edited \(note.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(AppFont.listSection)
                        .foregroundStyle(AppColor.textFaint)
                        .padding(.top, 6)

                    if let verseText = anchoredVerseText, let ref = anchorRef {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verseText)
                                .font(Font.custom("CrimsonText-Italic", size: 20, relativeTo: .title3))
                                .foregroundStyle(Color(hex: "#4A443C"))
                                .lineSpacing(6)
                            Text(ref.display.uppercased())
                                .font(AppFont.listSection)
                                .foregroundStyle(AppColor.textFaint)
                        }
                        .padding(.leading, 18)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(mode.accentColor).frame(width: 2)
                        }
                        .padding(.vertical, 22)
                    }

                    MarkdownTextEditor(text: $bindable.text, controller: formatController)
                        .frame(minHeight: 220, alignment: .top)
                        .padding(.top, 4)

                    NoteThreadsSection(note: note)
                        .padding(.top, 24)
                        .padding(.bottom, 44)
                }
                .padding(.horizontal, 60)
            }
        }
        .alert("Delete this note?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                AnnotationStore(context: modelContext).deleteNote(note)
                try? modelContext.save()
            }
        } message: {
            Text("This action can't be undone.")
        }
    }

    /// The quiet rail (10a): anchor dot + `REF · MODE`, actions far right.
    private var topRail: some View {
        HStack(spacing: 8) {
            Circle().fill(mode.accentColor).frame(width: 8, height: 8)
            Text(railLabel)
                .font(AppFont.microCaps)
                .tracking(1.3)
                .foregroundStyle(mode.accentColor)
            Spacer()
            MarkdownFormatBar(controller: formatController)
            Rectangle()
                .fill(Color(hex: "#E7E2D9"))
                .frame(width: 1, height: 15)
                .padding(.horizontal, 4)
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.textFaint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete note")
        }
        .padding(.horizontal, 30)
        .padding(.top, 18)
    }

    private var railLabel: String {
        let modeName = mode.displayName.uppercased()
        if let ref = anchorRef {
            return "\(ref.display.uppercased()) · \(modeName)"
        }
        if let layer = note.layer, let book = Book(rawValue: layer.book) {
            return "\(book.displayName.uppercased()) \(layer.chapter) · \(modeName)"
        }
        return modeName
    }
}
