import SwiftUI
import SwiftData

/// Apple Notes-style pane. Default view is the list of notes for the current
/// chapter on the active layer, sorted by `updatedAt` descending. Tap a row
/// to enter the editor. Tap the back arrow in the editor to return to the
/// list (saves on the way out — no Save button to forget).
///
/// Uses two SwiftUI states to flip between list and editor: `selectedNoteId`.
/// The note model itself lives in SwiftData — we mutate it directly inside
/// the editor, with `updatedAt` bumped through `AnnotationStore.updateNote`
/// so the list re-sorts immediately.
struct NotesPaneView: View {
    @Environment(\.modelContext) private var modelContext
    let layer: AnnotationLayer?
    let book: Book
    let chapter: Int

    @State private var selectedNoteId: UUID?

    var body: some View {
        Group {
            if let id = selectedNoteId, let note = note(byID: id) {
                NoteEditorPane(
                    note: note,
                    book: book,
                    chapter: chapter,
                    onBack: {
                        // Bump updatedAt + persist on exit so the list sorts
                        // freshly on re-entry.
                        AnnotationStore(context: modelContext).updateNote(note)
                        try? modelContext.save()
                        selectedNoteId = nil
                    },
                    onDelete: {
                        AnnotationStore(context: modelContext).deleteNote(note)
                        try? modelContext.save()
                        selectedNoteId = nil
                    }
                )
            } else {
                NotesListPane(
                    notes: chapterNotes,
                    onSelect: { selectedNoteId = $0.id },
                    onCreate: createNote
                )
            }
        }
    }

    /// Notes for the current chapter on the current layer, kind `.note`,
    /// sorted by most recently updated.
    private var chapterNotes: [VerseNote] {
        guard let layer else { return [] }
        return layer.notes
            .filter { $0.kindRaw == NoteKind.note.rawValue }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func note(byID id: UUID) -> VerseNote? {
        chapterNotes.first { $0.id == id }
    }

    private func createNote() {
        guard let layer else { return }
        let note = AnnotationStore(context: modelContext)
            .addNote(verseNumber: nil, title: "", text: "", on: layer)
        try? modelContext.save()
        selectedNoteId = note.id
    }
}

// MARK: - List

private struct NotesListPane: View {
    let notes: [VerseNote]
    let onSelect: (VerseNote) -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("NOTES")
                    .font(AppFont.microCaps)
                    .tracking(AppSpacing.smallCapsTracking)
                    .foregroundStyle(AppColor.textFaint)
                Spacer()
                Button(action: onCreate) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New note")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if notes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(notes) { note in
                            Button {
                                onSelect(note)
                            } label: {
                                NoteRow(note: note)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No notes yet")
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textSecondary)
            Text("Tap the new-note icon to start writing.")
                .font(.footnote)
                .foregroundStyle(AppColor.textFaint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

private struct NoteRow: View {
    let note: VerseNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(note.displayTitle)
                    .font(AppFont.uiBody)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                if let v = note.verseId {
                    Text("v\(v)")
                        .font(AppFont.microCaps)
                        .tracking(0.5)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColor.surface)
                        .clipShape(Capsule())
                }
            }
            HStack(spacing: 6) {
                Text(formatted(date: note.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(AppColor.textFaint)
                if !note.previewSnippet.isEmpty {
                    Text(note.previewSnippet)
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func formatted(date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Editor

private struct NoteEditorPane: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: VerseNote
    let book: Book
    let chapter: Int
    let onBack: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false
    @State private var anchorPickerOpen = false

    /// Verse anchor candidates — 1...chapterVerseCount + nil for unanchored.
    /// Computed lazily; for v1 we just allow 1...176 (longest chapter is
    /// Psalm 119 at 176). Out-of-range entries are visually ignored.
    private let verseRange = 1...176

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            anchorChip
            titleField
            Divider().padding(.horizontal, 16)
            bodyField
        }
        .alert("Delete this note?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This action can't be undone.")
        }
    }

    private var toolbar: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
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
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Chip that shows the current verse anchor (or "No anchor" if nil).
    /// Tap to open a picker that lets the user attach to a specific verse
    /// or detach.
    private var anchorChip: some View {
        Button {
            anchorPickerOpen.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 11))
                if let v = note.verseId {
                    Text("\(book.displayName) \(chapter):\(v)")
                } else {
                    Text("No anchor")
                }
            }
            .font(.caption)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppColor.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .popover(isPresented: $anchorPickerOpen, arrowEdge: .bottom) {
            anchorPicker
                .presentationCompactAdaptation(.popover)
        }
    }

    private var anchorPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                AnnotationStore(context: modelContext).clearNoteAnchor(note)
                try? modelContext.save()
                anchorPickerOpen = false
            } label: {
                HStack {
                    Text("No anchor")
                        .font(AppFont.uiBody)
                    Spacer()
                    if note.verseId == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundStyle(AppColor.textPrimary)
            }
            .buttonStyle(.plain)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(verseRange, id: \.self) { v in
                        Button {
                            note.verseId = v
                            note.updatedAt = .now
                            try? modelContext.save()
                            anchorPickerOpen = false
                        } label: {
                            HStack {
                                Text("Verse \(v)")
                                    .font(AppFont.uiBody)
                                Spacer()
                                if note.verseId == v {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .foregroundStyle(AppColor.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .frame(minWidth: 220)
    }

    private var titleField: some View {
        TextField("Title", text: $note.title)
            .font(AppFont.uiBody.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .submitLabel(.next)
    }

    private var bodyField: some View {
        TextEditor(text: $note.text)
            .font(AppFont.uiBody)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.clear)
    }
}
