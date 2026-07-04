import SwiftUI
import SwiftData

/// The notes browser (design turn 10a): note-list beside the page. The list
/// runs down the left in canonical order — books collapse, a book opens to
/// its notes grouped by chapter — and clicking a note swaps the editor on
/// the right. In compact width (Split View, future iPhone) the two become
/// separate screens (10b): rows push the full-screen editor instead.
struct NotesBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(BibleStore.self) private var bibleStore
    @Environment(LayerStore.self) private var layerStore

    /// All typed notes (kind == .note). Sourced via `@Query` so the list
    /// updates live as the user edits in the right column.
    @Query(filter: #Predicate<VerseNote> { $0.kindRaw == "note" })
    private var allNotes: [VerseNote]

    @State private var searchText = ""
    @State private var selectedNoteId: UUID?
    /// Books whose groups are open. `nil` until first render, which seeds it
    /// with the selected note's book (10a: only that book starts open).
    @State private var expandedBooks: Set<Book>?
    @State private var showShareSheet = false
    @State private var exportMarkdown = ""

    var body: some View {
        Group {
            if sizeClass == .compact {
                listPane(pushesRows: true)
            } else {
                HStack(spacing: 0) {
                    listPane(pushesRows: false)
                        .frame(width: 300)
                    Rectangle().fill(Color(hex: "#E7E2D9")).frame(width: 1)
                    if let note = selectedNote {
                        NoteEditorColumn(note: note)
                            .id(note.id)
                    } else {
                        emptyEditorState
                    }
                }
            }
        }
        .background(Color(hex: "#FCFBF8").ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [exportMarkdown])
        }
        .onAppear {
            if selectedNoteId == nil {
                selectedNoteId = allNotes.max(by: { $0.updatedAt < $1.updatedAt })?.id
            }
        }
    }

    // MARK: - Derived data

    private var selectedNote: VerseNote? {
        allNotes.first { $0.id == selectedNoteId } ?? nil
    }

    private var filteredNotes: [VerseNote] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allNotes }
        return allNotes.filter {
            $0.title.lowercased().contains(q) || $0.text.lowercased().contains(q)
        }
    }

    private struct BookGroup {
        let book: Book
        let chapters: [(chapter: Int, notes: [VerseNote])]
        var count: Int { chapters.reduce(0) { $0 + $1.notes.count } }
    }

    /// Canonical order throughout: books in canon order, chapters ascending,
    /// notes by verse anchor within a chapter.
    private var groups: [BookGroup] {
        var byBook: [Book: [Int: [VerseNote]]] = [:]
        for note in filteredNotes {
            guard let raw = note.layer?.book, let book = Book(rawValue: raw),
                  let chapter = note.layer?.chapter else { continue }
            byBook[book, default: [:]][chapter, default: []].append(note)
        }
        return Book.allCases.compactMap { book in
            guard let chapters = byBook[book] else { return nil }
            let ordered = chapters.keys.sorted().map { ch in
                (chapter: ch, notes: chapters[ch]!.sorted {
                    ($0.verseId ?? 0, $0.createdAt) < ($1.verseId ?? 0, $1.createdAt)
                })
            }
            return BookGroup(book: book, chapters: ordered)
        }
    }

    private var effectiveExpanded: Set<Book> {
        if let expandedBooks { return expandedBooks }
        // Seed: the selected note's book (or the first group) starts open.
        if let selected = selectedNote, let raw = selected.layer?.book,
           let book = Book(rawValue: raw) {
            return [book]
        }
        return groups.first.map { [$0.book] } ?? []
    }

    // MARK: - List pane

    private func listPane(pushesRows: Bool) -> some View {
        VStack(spacing: 0) {
            listHeader
            searchField
            if groups.isEmpty {
                emptyListState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(groups, id: \.book) { group in
                                bookRow(group)
                                if effectiveExpanded.contains(group.book) {
                                    ForEach(group.chapters, id: \.chapter) { entry in
                                        chapterLabel(entry.chapter)
                                        ForEach(entry.notes) { note in
                                            noteRow(note, pushes: pushesRows)
                                                .id(note.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    .onAppear {
                        // Bring the selected note into view once. Falls back
                        // to the default pick because this inner onAppear can
                        // fire before the outer one assigns selectedNoteId.
                        let id = selectedNoteId
                            ?? allNotes.max(by: { $0.updatedAt < $1.updatedAt })?.id
                        if let id {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color(hex: "#F4F1EC"))
    }

    private var listHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColor.textMuted)
            }
            .buttonStyle(.plain)
            Text("Notes")
                .font(Font.custom("CrimsonText-Regular", size: 23, relativeTo: .title2))
                .foregroundStyle(AppColor.textPrimary)
            Text("\(allNotes.count)")
                .font(AppFont.listSection)
                .foregroundStyle(AppColor.textFaint)
            Spacer()
            Button {
                exportMarkdown = buildMarkdownExport()
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(allNotes.isEmpty)
            .accessibilityLabel("Export notes")
            Button {
                addNote()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New note")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#C7C0B4"))
            TextField("Search notes", text: $searchText)
                .font(AppFont.listSection)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color(hex: "#E7E2D9"), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func bookRow(_ group: BookGroup) -> some View {
        Button {
            var expanded = effectiveExpanded
            if expanded.contains(group.book) {
                expanded.remove(group.book)
            } else {
                expanded.insert(group.book)
            }
            expandedBooks = expanded
        } label: {
            HStack(spacing: 9) {
                Image(systemName: effectiveExpanded.contains(group.book) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColor.textFaint)
                    .frame(width: 11)
                Text(group.book.displayName)
                    .font(Font.custom("CrimsonText-Bold", size: 16, relativeTo: .body))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Text("\(group.count)")
                    .font(AppFont.microCaps)
                    .foregroundStyle(Color(hex: "#C2BBAF"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 11)
            .padding(.bottom, 10)
            .overlay(alignment: .top) {
                Rectangle().fill(Color(hex: "#EAE5DC")).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chapterLabel(_ chapter: Int) -> some View {
        Text("CHAPTER \(chapter)")
            .font(AppFont.microCaps)
            .tracking(1.5)
            .foregroundStyle(Color(hex: "#B0A99E"))
            .padding(.leading, 40)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func noteRow(_ note: VerseNote, pushes: Bool) -> some View {
        if pushes {
            NavigationLink(value: LibraryRoute.noteEditor(note.id)) {
                noteRowLabel(note, selected: false)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                bumpUpdatedAtIfEdited()
                selectedNoteId = note.id
            } label: {
                noteRowLabel(note, selected: note.id == selectedNoteId)
            }
            .buttonStyle(.plain)
        }
    }

    private func noteRowLabel(_ note: VerseNote, selected: Bool) -> some View {
        let mode = note.layer?.kind ?? .exegetical
        let ref = refText(for: note)
        return HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(mode.accentColor)
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(ref)
                    .font(AppFont.microCaps)
                    .tracking(0.9)
                    .foregroundStyle(selected ? mode.accentColor : Color(hex: "#B0A99E"))
                Text(note.displayTitle)
                    .font(Font.custom("CrimsonText-Regular", size: 16, relativeTo: .body))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                if !note.previewSnippet.isEmpty {
                    Text(note.previewSnippet)
                        .font(AppFont.listSection)
                        .foregroundStyle(AppColor.textMuted)
                        .lineLimit(1)
                        .padding(.top, 1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 34)
        .padding(.trailing, 18)
        .padding(.vertical, 8)
        .background(selected ? mode.accentColor.opacity(0.06) : .clear)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(selected ? mode.accentColor : .clear)
                .frame(width: 3)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Empty states

    private var emptyListState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No notes")
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textSecondary)
            Text(searchText.isEmpty
                 ? "Tap a verse and choose Note to start one."
                 : "Try a different search term.")
                .font(.footnote)
                .foregroundStyle(AppColor.textFaint)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private var emptyEditorState: some View {
        VStack(spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 26))
                .foregroundStyle(AppColor.textFaint)
            Text("Select a note")
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textFaint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func refText(for note: VerseNote) -> String {
        guard let raw = note.layer?.book, let book = Book(rawValue: raw),
              let chapter = note.layer?.chapter else { return "" }
        if let verse = note.verseId {
            return "\(book.displayName) \(chapter):\(verse)".uppercased()
        }
        return "\(book.displayName) \(chapter)".uppercased()
    }

    /// New note from the browser anchors to the current reading position's
    /// chapter in the active mode — the nearest sensible home.
    private func addNote() {
        guard let translationId = bibleStore.translation?.identifier else { return }
        let position = LastReadingPosition.read()
            ?? LastReadingPosition(book: .GEN, chapter: 1)
        let store = AnnotationStore(context: modelContext)
        let layer = store.findOrCreateLayer(
            kind: layerStore.active,
            translation: translationId,
            book: position.book,
            chapter: position.chapter
        )
        let note = store.addNote(text: "", on: layer)
        try? store.save()
        selectedNoteId = note.id
        expandedBooks = effectiveExpanded.union([position.book])
    }

    /// Nudge `updatedAt` on the note being left so recency sorts stay honest.
    private func bumpUpdatedAtIfEdited() {
        guard let note = selectedNote else { return }
        note.updatedAt = .now
        try? modelContext.save()
    }

    // MARK: - Export

    /// Build a Markdown document from all currently-filtered notes, grouped
    /// by book then chapter. Lightweight format — good for clipboard,
    /// AirDrop, or piping into another notes app.
    private func buildMarkdownExport() -> String {
        var lines: [String] = ["# Grapho — Notes Export", ""]
        let formatter = ISO8601DateFormatter()
        for group in groups {
            lines.append("## \(group.book.displayName)")
            lines.append("")
            for entry in group.chapters {
                lines.append("### Chapter \(entry.chapter)")
                lines.append("")
                for note in entry.notes {
                    let anchor = note.verseId.map { " (v\($0))" } ?? ""
                    lines.append("**\(note.displayTitle)**\(anchor) — _\(formatter.string(from: note.updatedAt))_")
                    lines.append("")
                    lines.append(note.text)
                    lines.append("")
                }
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - UIKit share sheet bridge

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
