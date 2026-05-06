import SwiftUI
import SwiftData

/// Full-screen notes browser, reachable from the reader's library bubble or
/// (someday) from a Library tab. Lists every typed note across all books and
/// chapters, grouped by book in canonical order, searchable, and exportable.
///
/// "Export" for v1 produces a Markdown blob and routes through the system
/// share sheet — clipboard, save-as, mail, whatever. Post-MVP we can polish
/// into a richer document export.
struct NotesBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue
    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }

    /// All typed notes (kind == .note), most-recently-updated first. Sourced
    /// directly via `@Query` so the list updates live as the user edits in
    /// the right pane.
    @Query(
        filter: #Predicate<VerseNote> { $0.kindRaw == "note" },
        sort: \.updatedAt,
        order: .reverse
    )
    private var allNotes: [VerseNote]

    @State private var searchText: String = ""
    @State private var showShareSheet = false
    @State private var exportMarkdown: String = ""

    /// Filter by search text (matches title or body, case-insensitive).
    private var filteredNotes: [VerseNote] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allNotes }
        return allNotes.filter {
            $0.title.lowercased().contains(q) || $0.text.lowercased().contains(q)
        }
    }

    /// Group filtered notes by Book (resolved from the layer's book code),
    /// in canonical order.
    private var groupedByBook: [(book: Book, notes: [VerseNote])] {
        var grouped: [Book: [VerseNote]] = [:]
        for note in filteredNotes {
            guard let bookCode = note.layer?.book,
                  let book = Book(rawValue: bookCode)
            else { continue }
            grouped[book, default: []].append(note)
        }
        return Book.allCases.compactMap { book in
            guard let notes = grouped[book], !notes.isEmpty else { return nil }
            return (book: book, notes: notes)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()

            if filteredNotes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedByBook, id: \.book) { group in
                            bookGroupSection(group.book, notes: group.notes)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .background(palette.color.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [exportMarkdown])
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Back")
                        .font(AppFont.uiBody)
                }
                .foregroundStyle(AppColor.textSecondary)
            }
            .buttonStyle(.plain)

            Text("Notes")
                .font(.custom("CrimsonText-Regular", size: 22, relativeTo: .title))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.leading, 12)

            Spacer()

            Button {
                exportMarkdown = buildMarkdownExport()
                showShareSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                    Text("Export")
                        .font(AppFont.uiBody)
                }
                .foregroundStyle(AppColor.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(allNotes.isEmpty)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(AppColor.textFaint)
            TextField("Search notes…", text: $searchText)
                .font(AppFont.uiBody)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.textFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
    }

    // MARK: - Groups & rows

    @ViewBuilder
    private func bookGroupSection(_ book: Book, notes: [VerseNote]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(book.displayName.uppercased())
                    .font(AppFont.listSection)
                    .tracking(AppSpacing.smallCapsTracking)
                    .foregroundStyle(AppColor.textFaint)
                Rectangle().fill(AppColor.border).frame(height: 0.5)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ForEach(notes) { note in
                NavigationLink(value: LibraryRoute.noteEditor(note.id)) {
                    NotesBrowserRow(note: note)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No notes")
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textSecondary)
            Text(searchText.isEmpty
                 ? "Add notes from the right pane in Scholar mode."
                 : "Try a different search term.")
                .font(.footnote)
                .foregroundStyle(AppColor.textFaint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Export

    /// Build a Markdown document from all currently-filtered notes, grouped
    /// by book then chapter. Lightweight format — good for clipboard,
    /// AirDrop, or piping into another notes app.
    private func buildMarkdownExport() -> String {
        var lines: [String] = ["# Grapho — Notes Export", ""]
        let formatter = ISO8601DateFormatter()
        for group in groupedByBook {
            lines.append("## \(group.book.displayName)")
            lines.append("")
            // Group within a book by chapter.
            let byChapter = Dictionary(grouping: group.notes, by: { $0.layer?.chapter ?? 0 })
            let chapters = byChapter.keys.sorted()
            for ch in chapters {
                lines.append("### Chapter \(ch)")
                lines.append("")
                for note in byChapter[ch] ?? [] {
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

private struct NotesBrowserRow: View {
    let note: VerseNote

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(note.displayTitle)
                        .font(AppFont.uiBody)
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
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
                    if let chapter = note.layer?.chapter {
                        Text("ch. \(chapter)")
                            .font(.caption2)
                            .foregroundStyle(AppColor.textFaint)
                    }
                    Spacer()
                    Text(formatted(note.updatedAt))
                        .font(.caption2)
                        .foregroundStyle(AppColor.textFaint)
                }
                if !note.previewSnippet.isEmpty {
                    Text(note.previewSnippet)
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColor.border).frame(height: 0.5)
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - UIKit share sheet bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
