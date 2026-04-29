import SwiftUI
import SwiftData

/// The reader. Renders one chapter with sticky title, optional Psalm
/// superscription, and the verse body. Hosts three layered annotation
/// affordances:
///
/// 1. Highlights — whole-verse color overlay (4 colors). Sub-string
///    highlighting is post-MVP; v1 trades range precision for tap-light UX.
/// 2. Notes — free-form typed notes anchored to a verse, indicated by a
///    small dot in the verse-number gutter.
/// 3. Custom section headers — user-authored headers rendered above the
///    anchoring verse.
///
/// All three are scoped to the active `LayerKind` from `LayerStore`. Switching
/// layers swaps which annotations are visible without losing data.
///
/// Tap interaction: in poetic books each verse is a tappable block; in prose
/// books verses concatenate into one flowing Text so the verse *number* runs
/// carry an `attributed:link` to a `grapho://verse/N` URL that an
/// `OpenURLAction` intercepts. That keeps the prose-flow look while making
/// each verse number an intentional, accident-free target.
struct ChapterReaderView: View {
    @Environment(BibleStore.self) private var bibleStore
    @Environment(LayerStore.self) private var layerStore
    @Environment(\.modelContext) private var modelContext
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue
    @AppStorage(PreferenceKey.headerMode) private var headerModeRaw: String = HeaderMode.custom.rawValue

    let route: ChapterRoute
    let advance: (ChapterRoute) -> Void

    @State private var activeLayer: AnnotationLayer?
    @State private var pendingAction: PendingAction?

    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }
    private var headerMode: HeaderMode { .current(rawValue: headerModeRaw) }

    /// Rolled into one enum so a single `sheet(item:)` covers all three
    /// flows. Avoids three independent booleans drifting out of sync.
    private enum PendingAction: Identifiable {
        case verseAction(verseNumber: Int)
        case editNote(verseNumber: Int)
        case editSectionHeader(verseNumber: Int)

        var id: String {
            switch self {
            case .verseAction(let n): return "v\(n)"
            case .editNote(let n): return "n\(n)"
            case .editSectionHeader(let n): return "h\(n)"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StickyTitleView(book: route.book, chapter: route.chapter)

                if let chapter = chapter {
                    if let superscription = chapter.superscription {
                        Text(superscription)
                            .font(AppFont.superscription)
                            .foregroundStyle(AppColor.textFaint)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 16)
                    }

                    chapterBody(chapter)

                    chapterFooter
                } else {
                    Text("Chapter not available in this translation.")
                        .foregroundStyle(AppColor.textFaint)
                        .padding(.top, 32)
                }
            }
            .padding(.leading, AppSpacing.readingMarginLeading)
            .padding(.trailing, AppSpacing.readingMarginTrailing)
            .padding(.top, AppSpacing.chapterTopPadding)
            .padding(.bottom, 96)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.color.ignoresSafeArea())
        .navigationTitle("\(route.book.displayName) \(route.chapter)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LayerSwitcher()
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            handleVerseURL(url)
        })
        .task(id: chapterKey) {
            await onChapterAppear()
        }
        .sheet(item: $pendingAction) { action in
            sheet(for: action)
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheet(for action: PendingAction) -> some View {
        switch action {
        case .verseAction(let n):
            VerseActionSheet(
                book: route.book,
                chapter: route.chapter,
                verseNumber: n,
                currentColor: highlightColor(for: n),
                layerKind: layerStore.active,
                onPickColor: { color in
                    if let layer = activeLayer {
                        AnnotationStore(context: modelContext)
                            .setHighlight(verseNumber: n, color: color, on: layer)
                    }
                },
                onClearHighlight: {
                    if let layer = activeLayer {
                        AnnotationStore(context: modelContext)
                            .clearHighlight(verseNumber: n, on: layer)
                    }
                },
                onAddNote: {
                    pendingAction = .editNote(verseNumber: n)
                },
                onAddSectionHeader: {
                    pendingAction = .editSectionHeader(verseNumber: n)
                },
                onDismiss: { pendingAction = nil }
            )

        case .editNote(let n):
            NoteEditorSheet(
                title: "Note on \(route.book.displayName) \(route.chapter):\(n)",
                placeholder: "Type your note…",
                onSave: { text in
                    if !text.isEmpty, let layer = activeLayer {
                        AnnotationStore(context: modelContext)
                            .addNote(verseNumber: n, text: text, on: layer)
                    }
                    pendingAction = nil
                },
                onCancel: { pendingAction = nil }
            )

        case .editSectionHeader(let n):
            NoteEditorSheet(
                title: "Header before verse \(n)",
                placeholder: "Section title",
                initialText: existingSectionHeader(for: n)?.text ?? "",
                onSave: { text in
                    if !text.isEmpty, let layer = activeLayer {
                        AnnotationStore(context: modelContext)
                            .setSectionHeader(beforeVerse: n, text: text, on: layer)
                    }
                    pendingAction = nil
                },
                onCancel: { pendingAction = nil }
            )
        }
    }

    // MARK: - Chapter body

    @ViewBuilder
    private func chapterBody(_ chapter: BibleChapter) -> some View {
        if route.book.isPoetic {
            VStack(alignment: .leading, spacing: AppSpacing.verseSpacingPoetic + 6) {
                ForEach(chapter.verses) { verse in
                    poeticVerseBlock(verse)
                }
            }
        } else {
            proseChapterBody(chapter)
        }
    }

    @ViewBuilder
    private func poeticVerseBlock(_ verse: BibleVerse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if headerMode == .custom, let header = sectionHeader(for: verse.number) {
                sectionHeaderView(header)
            }
            HStack(alignment: .top, spacing: 6) {
                noteIndicator(for: verse.number)
                Text(poeticVerseAttributed(verse))
                    .lineSpacing(AppSpacing.scriptureLineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(highlightColor(for: verse.number)?.color ?? .clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        pendingAction = .verseAction(verseNumber: verse.number)
                    }
            }
        }
    }

    /// Prose path: build one big AttributedString. Headers are interleaved as
    /// separate Text views via a `ForEach` chunk — when the chapter contains
    /// section headers, we split the prose into runs between headers and
    /// stack them. Inside each run, verses concatenate as flowing prose.
    @ViewBuilder
    private func proseChapterBody(_ chapter: BibleChapter) -> some View {
        let runs = proseRuns(verses: chapter.verses)
        VStack(alignment: .leading, spacing: 16) {
            ForEach(runs) { run in
                if headerMode == .custom, let header = run.header {
                    sectionHeaderView(header)
                }
                Text(run.attributed)
                    .lineSpacing(AppSpacing.scriptureLineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var chapterFooter: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 32)
            if let next = navigator?.next(after: route) {
                Button {
                    advance(next)
                } label: {
                    HStack(spacing: 6) {
                        Text("\(next.book.displayName) \(next.chapter)")
                        Image(systemName: "chevron.right")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(AppColor.border, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else {
                Text("End of canon.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textFaint)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Section header & note rendering

    @ViewBuilder
    private func sectionHeaderView(_ note: VerseNote) -> some View {
        Text(note.text.uppercased())
            .font(AppFont.sectionHeader)
            .tracking(1.2)
            .foregroundStyle(AppColor.sectionHeader)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onTapGesture {
                pendingAction = .editSectionHeader(verseNumber: note.verseId)
            }
    }

    @ViewBuilder
    private func noteIndicator(for verseNumber: Int) -> some View {
        if hasNote(for: verseNumber) {
            Circle()
                .fill(layerStore.active.accentColor)
                .frame(width: 6, height: 6)
                .padding(.top, 8)
        } else {
            Color.clear.frame(width: 6, height: 6)
        }
    }

    // MARK: - URL handling (prose verse-number tap)

    private func handleVerseURL(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == "grapho", url.host == "verse" else {
            return .systemAction
        }
        let last = url.lastPathComponent
        guard let n = Int(last) else { return .discarded }
        pendingAction = .verseAction(verseNumber: n)
        return .handled
    }

    // MARK: - Lookups

    private var chapter: BibleChapter? {
        bibleStore.translation?.chapter(book: route.book, number: route.chapter)
    }

    private var navigator: ChapterNavigator? {
        bibleStore.translation.map(ChapterNavigator.init)
    }

    private var chapterKey: String {
        "\(route.book.rawValue)-\(route.chapter)-\(layerStore.active.rawValue)"
    }

    private func highlightColor(for verseNumber: Int) -> HighlightColor? {
        activeLayer?.highlights.first { $0.verseId == verseNumber }?.color
    }

    private func hasNote(for verseNumber: Int) -> Bool {
        activeLayer?.notes.contains {
            $0.verseId == verseNumber && $0.kindRaw == NoteKind.note.rawValue
        } ?? false
    }

    private func sectionHeader(for verseNumber: Int) -> VerseNote? {
        activeLayer?.notes.first {
            $0.verseId == verseNumber && $0.kindRaw == NoteKind.sectionHeader.rawValue
        }
    }

    private func existingSectionHeader(for verseNumber: Int) -> VerseNote? {
        sectionHeader(for: verseNumber)
    }

    // MARK: - Lifecycle

    private func onChapterAppear() async {
        guard let translationId = bibleStore.translation?.identifier else { return }
        let store = AnnotationStore(context: modelContext)
        activeLayer = store.findOrCreateLayer(
            kind: layerStore.active,
            translation: translationId,
            book: route.book,
            chapter: route.chapter
        )
        store.recordVisit(translation: translationId, book: route.book, chapter: route.chapter)
        try? store.save()
        LastReadingPosition(book: route.book, chapter: route.chapter).save()
    }

    // MARK: - Attributed string construction

    /// Build the AttributedString for one poetic verse. No verse-number link
    /// here — the entire block is tappable via `.onTapGesture`.
    private func poeticVerseAttributed(_ verse: BibleVerse) -> AttributedString {
        var num = AttributedString("\(verse.number) ")
        num.font = AppFont.verseNumber
        num.foregroundColor = AppColor.textFaint
        num.baselineOffset = 4

        var body = AttributedString(verse.text)
        body.font = AppFont.scriptureBody
        body.foregroundColor = AppColor.textPrimary

        return num + body
    }

    /// One contiguous prose run, optionally headed by a custom section header.
    /// Splitting prose into runs lets us interleave header views without
    /// breaking word-wrap inside a single Text.
    private struct ProseRun: Identifiable {
        let id: Int                   // first verse number in the run
        let header: VerseNote?        // header that opens this run, if any
        let attributed: AttributedString
    }

    private func proseRuns(verses: [BibleVerse]) -> [ProseRun] {
        // Collect headers anchored to verses, indexed by verseNumber.
        let headersByVerse: [Int: VerseNote] = {
            guard let layer = activeLayer else { return [:] }
            var dict: [Int: VerseNote] = [:]
            for note in layer.notes where note.kindRaw == NoteKind.sectionHeader.rawValue {
                dict[note.verseId] = note
            }
            return dict
        }()

        var runs: [ProseRun] = []
        var currentHeader: VerseNote? = nil
        var currentVerses: [BibleVerse] = []
        var currentFirstVerse: Int? = nil

        func flush() {
            guard !currentVerses.isEmpty, let firstVerse = currentFirstVerse else { return }
            let attr = proseAttributed(verses: currentVerses)
            runs.append(ProseRun(id: firstVerse, header: currentHeader, attributed: attr))
            currentHeader = nil
            currentVerses = []
            currentFirstVerse = nil
        }

        for verse in verses {
            if let header = headersByVerse[verse.number], !currentVerses.isEmpty {
                // Flush prior run, then start a new one with this header.
                flush()
                currentHeader = header
            } else if let header = headersByVerse[verse.number] {
                // First verse of the chapter has a header — apply to the
                // initial run.
                currentHeader = header
            }
            if currentFirstVerse == nil { currentFirstVerse = verse.number }
            currentVerses.append(verse)
        }
        flush()
        return runs
    }

    /// Build a flowing AttributedString for a contiguous prose run. Each
    /// verse's number becomes a `grapho://verse/N` link so taps land in the
    /// `OpenURLAction` handler. Highlights are applied as background colors
    /// per verse range.
    private func proseAttributed(verses: [BibleVerse]) -> AttributedString {
        var out = AttributedString("")

        var bodyAttrs = AttributeContainer()
        bodyAttrs.font = AppFont.scriptureBody
        bodyAttrs.foregroundColor = AppColor.textPrimary

        for (index, verse) in verses.enumerated() {
            // Build this verse's segment (number + text), tracking the range
            // we'll need for highlight backgrounding.
            let segmentStart = out.endIndex

            if index > 0 {
                out += AttributedString(" ", attributes: bodyAttrs)
            }

            var numAttrs = AttributeContainer()
            numAttrs.font = AppFont.verseNumber
            numAttrs.foregroundColor = AppColor.textFaint
            numAttrs.baselineOffset = 4
            // Tappable link — intercepted by OpenURLAction so the system
            // browser never opens.
            numAttrs.link = URL(string: "grapho://verse/\(verse.number)")
            // Re-state foregroundColor AFTER setting link so it wins over
            // the system link tint.
            numAttrs.foregroundColor = AppColor.textFaint
            numAttrs.underlineStyle = nil
            out += AttributedString("\(verse.number) ", attributes: numAttrs)

            out += AttributedString(verse.text, attributes: bodyAttrs)

            if let color = highlightColor(for: verse.number) {
                let range = segmentStart..<out.endIndex
                out[range].backgroundColor = color.color
            }
        }
        return out
    }
}
