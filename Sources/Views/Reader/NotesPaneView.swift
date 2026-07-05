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
    @Environment(BibleStore.self) private var bibleStore
    let layer: AnnotationLayer?
    let book: Book
    let chapter: Int
    /// Number of verses in this chapter — used to clamp the anchor picker
    /// to real verse numbers instead of a generic 1...176 list. Passed in
    /// by the parent (ScholarReaderView) which already has the chapter
    /// loaded.
    let verseCount: Int
    /// Navigate to a verse (used by thread cards to jump to the other end).
    /// `nil` disables navigation from this pane.
    var onOpenRef: ((VerseRef) -> Void)? = nil

    @State private var selectedNoteId: UUID?
    /// This mode's threads touching this chapter. A thread with a "why" is
    /// in practice a shared note pinned between two verses — it shows here
    /// at *both* ends (stored once on the thread, so the ends never drift).
    @State private var chapterThreads: [VerseThread] = []
    /// Thread whose "why" is being edited via the alert.
    @State private var editingThread: VerseThread?
    @State private var whyDraft = ""
    /// Thread opened full-length in the "Pull thread" sheet.
    @State private var pulledThread: VerseThread?

    var body: some View {
        Group {
            if let id = selectedNoteId, let note = note(byID: id) {
                NoteEditorPane(
                    note: note,
                    book: book,
                    chapter: chapter,
                    verseCount: verseCount,
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
                    threads: chapterThreads,
                    chapterRef: (book: book, chapter: chapter),
                    onSelect: { selectedNoteId = $0.id },
                    onCreate: createNote,
                    onOpenThread: { thread in
                        if let ref = otherEnd(of: thread) {
                            onOpenRef?(ref)
                        }
                    },
                    onPullThread: { pulledThread = $0 },
                    onEditWhy: { thread in
                        whyDraft = thread.why
                        editingThread = thread
                    },
                    onDeleteThread: deleteThread
                )
            }
        }
        .task(id: paneKey) {
            refreshThreads()
        }
        .onAppear {
            refreshThreads()
        }
        .sheet(item: $pulledThread) { thread in
            ThreadDetailView(
                thread: thread,
                onOpenRef: { ref in onOpenRef?(ref) },
                onDelete: { deleteThread(thread) }
            )
        }
        .alert("Why these connect", isPresented: Binding(
            get: { editingThread != nil },
            set: { if !$0 { editingThread = nil } }
        )) {
            TextField("why these connect for you…", text: $whyDraft)
            Button("Cancel", role: .cancel) { editingThread = nil }
            Button("Save") {
                editingThread?.why = whyDraft
                try? modelContext.save()
                editingThread = nil
                refreshThreads()
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

    // MARK: - Threads

    private var paneKey: String {
        "\(book.rawValue)-\(chapter)-\(layer?.kindRaw ?? "")"
    }

    /// Threads born in this room's mode, touching this chapter.
    private func refreshThreads() {
        guard let layer, let translationId = bibleStore.translation?.identifier else { return }
        chapterThreads = AnnotationStore(context: modelContext)
            .threads(translation: translationId, book: book, chapter: chapter)
            .filter { $0.modeRaw == layer.kindRaw }
    }

    private func otherEnd(of thread: VerseThread) -> VerseRef? {
        // Prefer the end that is NOT in this chapter; for a same-chapter
        // thread, jump to its target.
        if let from = thread.fromRef, from.book != book || from.chapter != chapter {
            return from
        }
        return thread.toRef
    }

    private func deleteThread(_ thread: VerseThread) {
        let store = AnnotationStore(context: modelContext)
        store.deleteThread(thread)
        try? store.save()
        refreshThreads()
    }
}

// MARK: - List

private struct NotesListPane: View {
    let notes: [VerseNote]
    /// Threads touching this chapter in this mode. A thread with a "why" is
    /// a shared note between two verses, so it lists here alongside notes.
    let threads: [VerseThread]
    let chapterRef: (book: Book, chapter: Int)
    let onSelect: (VerseNote) -> Void
    let onCreate: () -> Void
    let onOpenThread: (VerseThread) -> Void
    let onPullThread: (VerseThread) -> Void
    let onEditWhy: (VerseThread) -> Void
    let onDeleteThread: (VerseThread) -> Void

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

            if notes.isEmpty && threads.isEmpty {
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
                        if !threads.isEmpty {
                            threadsSection
                        }
                    }
                }
            }
        }
    }

    private var threadsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                ThreadLoopIcon()
                    .stroke(AppColor.textFaint, style: ThreadLoopIcon.strokeStyle)
                    .frame(width: 12, height: 15)
                Text("THREADS · \(threads.count)")
                    .font(AppFont.microCaps)
                    .tracking(AppSpacing.smallCapsTracking)
                    .foregroundStyle(AppColor.textFaint)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 4)

            ForEach(threads) { thread in
                Button {
                    onOpenThread(thread)
                } label: {
                    threadRow(thread)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        onPullThread(thread)
                    } label: {
                        Label("Pull thread", systemImage: "arrow.up.and.down.text.horizontal")
                    }
                    Button {
                        onEditWhy(thread)
                    } label: {
                        Label("Edit why…", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onDeleteThread(thread)
                    } label: {
                        Label("Cut thread", systemImage: "scissors")
                    }
                }
                Divider().padding(.leading, 16)
            }
        }
    }

    private func threadRow(_ thread: VerseThread) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Circle().fill(thread.mode.accentColor).frame(width: 6, height: 6)
                Text(endpointsLabel(thread))
                    .font(AppFont.uiBody)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColor.textFaint)
            }
            if thread.why.isEmpty {
                Text("no why yet — long-press to add one")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(AppColor.textFaint)
                    .padding(.leading, 13)
            } else {
                Text(thread.why)
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 13)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// "v14 → Numbers 21:9" from this chapter's side of the thread; fully
    /// qualified on both sides if neither end is local (shouldn't happen).
    private func endpointsLabel(_ thread: VerseThread) -> String {
        func short(_ ref: VerseRef) -> String {
            ref.book == chapterRef.book && ref.chapter == chapterRef.chapter
                ? "v\(ref.verse)"
                : ref.display
        }
        guard let from = thread.fromRef, let to = thread.toRef else { return "thread" }
        return "\(short(from)) → \(short(to))"
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
    let verseCount: Int
    let onBack: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false
    @State private var anchorPickerOpen = false
    @State private var formatController = MarkdownEditController()

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
            MarkdownFormatBar(controller: formatController)
            Rectangle()
                .fill(AppColor.border)
                .frame(width: 1, height: 15)
                .padding(.horizontal, 4)
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
            NoteAnchorPicker(
                note: note,
                verseCount: verseCount,
                onDismiss: { anchorPickerOpen = false }
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private var titleField: some View {
        TextField("Title", text: $note.title)
            .font(AppFont.uiBody.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .submitLabel(.next)
    }

    private var bodyField: some View {
        ScrollView {
            MarkdownTextEditor(text: $note.text, controller: formatController)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }
}
