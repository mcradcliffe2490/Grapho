import SwiftUI
import SwiftData

/// Full-screen editor for a single note. Reached by tapping a row in
/// `NotesBrowserView`. The Scholar right pane keeps its own inline editor
/// (`NoteEditorPane`); this surface exists so the user can open a note from
/// the browser and work on it uninterrupted, without being yanked back into
/// the reader column.
///
/// Layout: top toolbar (back, delete), the same anchor chip + title +
/// body pattern from the inline editor, plus a quiet "Genesis 1 · Devotional"
/// breadcrumb so the chapter context is still legible at a glance.
///
/// Saving: SwiftUI's `@Bindable` writes propagate immediately. We bump
/// `updatedAt` on back-out so the browser list re-sorts on return — same
/// pattern as the inline pane.
struct FullScreenNoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(BibleStore.self) private var bibleStore
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue
    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }

    /// Looked up via @Query at view-load time. We hold a fetched note so
    /// SwiftData observes its mutations through `@Bindable`.
    let noteId: UUID

    @State private var note: VerseNote?
    @State private var anchorPickerOpen = false
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if let note {
                editor(for: note)
            } else {
                emptyState
            }
        }
        .background(palette.color.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: noteId) {
            await loadNote()
        }
    }

    // MARK: - Editor body

    @ViewBuilder
    private func editor(for note: VerseNote) -> some View {
        @Bindable var bindable = note
        VStack(alignment: .leading, spacing: 0) {
            toolbar(note: note)
            breadcrumb(note: note)
            anchorChip(note: bindable)
            titleField(note: bindable)
            Divider().padding(.horizontal, 32).padding(.top, 4)
            bodyField(note: bindable)
        }
        .alert("Delete this note?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                AnnotationStore(context: modelContext).deleteNote(note)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("This action can't be undone.")
        }
    }

    private func toolbar(note: VerseNote) -> some View {
        HStack {
            Button {
                AnnotationStore(context: modelContext).updateNote(note)
                try? modelContext.save()
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Notes")
                        .font(AppFont.uiBody)
                }
                .foregroundStyle(AppColor.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete note")
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private func breadcrumb(note: VerseNote) -> some View {
        HStack(spacing: 8) {
            if let book = chapterBook(for: note),
               let chapter = note.layer?.chapter {
                Text(book.displayName)
                    .font(AppFont.microCaps)
                    .tracking(AppSpacing.smallCapsTracking)
                    .foregroundStyle(AppColor.textFaint)
                Text("·")
                    .foregroundStyle(AppColor.textFaint)
                Text("\(chapter)")
                    .font(AppFont.microCaps)
                    .foregroundStyle(AppColor.textFaint)
            }
            if let layer = note.layer {
                Text("·")
                    .foregroundStyle(AppColor.textFaint)
                Text(layerLabel(forRaw: layer.kindRaw))
                    .font(AppFont.microCaps)
                    .tracking(AppSpacing.smallCapsTracking)
                    .foregroundStyle(layerAccent(forRaw: layer.kindRaw))
            }
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 8)
    }

    private func anchorChip(note: VerseNote) -> some View {
        Button {
            anchorPickerOpen.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 12))
                if let v = note.verseId,
                   let book = chapterBook(for: note),
                   let chapter = note.layer?.chapter {
                    Text("\(book.displayName) \(chapter):\(v)")
                } else {
                    Text("No anchor")
                }
            }
            .font(AppFont.uiBody)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColor.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
        .popover(isPresented: $anchorPickerOpen, arrowEdge: .top) {
            NoteAnchorPicker(
                note: note,
                verseCount: verseCount(for: note),
                onDismiss: { anchorPickerOpen = false }
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private func titleField(note: VerseNote) -> some View {
        @Bindable var bindable = note
        return TextField("Title", text: $bindable.title)
            .font(.custom("CrimsonText-Regular", size: 22, relativeTo: .title))
            .padding(.horizontal, 32)
            .padding(.vertical, 8)
    }

    private func bodyField(note: VerseNote) -> some View {
        @Bindable var bindable = note
        return TextEditor(text: $bindable.text)
            .font(AppFont.scriptureBody)
            .lineSpacing(6)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Note not found")
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textSecondary)
            Button("Back") {
                dismiss()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func loadNote() async {
        let id = noteId
        let descriptor = FetchDescriptor<VerseNote>(
            predicate: #Predicate { $0.id == id }
        )
        if let found = try? modelContext.fetch(descriptor).first {
            note = found
        } else {
            note = nil
        }
    }

    private func chapterBook(for note: VerseNote) -> Book? {
        guard let raw = note.layer?.book else { return nil }
        return Book(rawValue: raw)
    }

    private func verseCount(for note: VerseNote) -> Int {
        guard let book = chapterBook(for: note),
              let chapter = note.layer?.chapter,
              let bibleChapter = bibleStore.translation?.chapter(book: book, number: chapter)
        else { return 1 }
        return bibleChapter.verses.count
    }

    private func layerLabel(forRaw raw: String) -> String {
        (LayerKind(rawValue: raw) ?? .exegetical).displayName.uppercased()
    }

    private func layerAccent(forRaw raw: String) -> Color {
        (LayerKind(rawValue: raw) ?? .exegetical).accentColor
    }
}
