import SwiftUI
import SwiftData

/// The reader. Renders one chapter with the Figma's chrome:
/// - Top toolbar (`< >` arrows, USFM ref centered, active-layer label
///   tappable on the right)
/// - Centered "BOOKNAME / chapterNumber" title block
/// - Custom user-authored section headers (small caps, thin divider)
/// - Per-verse paragraph rendering with superscript numbers
/// - Inline color-dot highlight picker on verse tap
///
/// Reader portrait shows the toolbar inline; Scholar landscape suppresses
/// it because the parent `ScholarReaderView` provides one for the whole
/// window.
struct ChapterReaderView: View {
    @Environment(BibleStore.self) private var bibleStore
    @Environment(LayerStore.self) private var layerStore
    @Environment(\.modelContext) private var modelContext
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue
    @AppStorage(PreferenceKey.headerMode) private var headerModeRaw: String = HeaderMode.custom.rawValue

    let route: ChapterRoute
    let navigation: ReaderNavigation
    /// Layout flavor — Reader (portrait) shows its own toolbar; Scholar
    /// (landscape) hides it (the split parent owns the chrome).
    var style: ReaderStyle = .reader

    private var advance: (ChapterRoute) -> Void { navigation.advance }

    @State private var activeLayer: AnnotationLayer?
    /// Verse number whose inline color picker is currently open. `nil` when
    /// no picker is shown.
    @State private var pickerVerse: Int?
    @State private var noteEditorTarget: NoteEditTarget?

    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }
    private var headerMode: HeaderMode { .current(rawValue: headerModeRaw) }

    /// Identifies the editor sheet target — note ID or "new for verse N".
    private struct NoteEditTarget: Identifiable {
        enum Mode { case newSectionHeader(verse: Int) }
        let mode: Mode
        let id: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if style == .reader {
                    topToolbar
                        .padding(.top, 16)
                }

                chapterTitleBlock
                    .padding(.top, style == .reader ? 24 : 32)

                if let chapter = chapter {
                    if let superscription = chapter.superscription {
                        Text(superscription)
                            .font(AppFont.superscription)
                            .italic()
                            .foregroundStyle(AppColor.textFaint)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                    }

                    chapterBody(chapter)
                        .padding(.top, 16)

                    chapterFooter
                        .padding(.top, 32)
                } else {
                    Text("Chapter not available in this translation.")
                        .font(AppFont.uiBody)
                        .foregroundStyle(AppColor.textFaint)
                        .padding(.top, 32)
                }
            }
            .padding(.leading, style.leadingMargin)
            .padding(.trailing, style.trailingMargin)
            .padding(.bottom, 96)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.color.ignoresSafeArea())
        // Library bubble — left margin, fixed in screen space. Reader
        // portrait shows it here; Scholar's parent supplies its own copy
        // so the bubble lives at the window edge, not the column edge.
        .overlay(alignment: .topLeading) {
            if style == .reader {
                LibraryMenuButton(navigation: navigation)
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: chapterKey) {
            await onChapterAppear()
        }
        .sheet(item: $noteEditorTarget) { target in
            sheet(for: target)
        }
        .onTapGesture {
            // Tap outside any verse closes the picker.
            if pickerVerse != nil { withAnimation(.easeOut(duration: 0.15)) { pickerVerse = nil } }
        }
    }

    // MARK: - Top toolbar

    private var topToolbar: some View {
        HStack(alignment: .center) {
            Button {
                if let prev = navigator?.previous(before: route) { advance(prev) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(navigator?.previous(before: route) == nil)
            Button {
                if let next = navigator?.next(after: route) { advance(next) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .disabled(navigator?.next(after: route) == nil)

            Spacer()

            Text("\(usfmAbbrev(route.book))   \(route.chapter)")
                .font(AppFont.wordmark)
                .tracking(2)
                .foregroundStyle(AppColor.textSecondary)

            Spacer()

            LayerLabelTapTarget()
        }
    }

    // MARK: - Chapter title block

    private var chapterTitleBlock: some View {
        VStack(spacing: 4) {
            Text(route.book.displayName.uppercased())
                .font(AppFont.chapterTitleBookLabel)
                .tracking(AppSpacing.smallCapsTracking)
                .foregroundStyle(AppColor.textSecondary)
            Text("\(route.chapter)")
                .font(AppFont.chapterTitleNumeral)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chapter body

    @ViewBuilder
    private func chapterBody(_ chapter: BibleChapter) -> some View {
        let interleaved = interleavedItems(chapter.verses)

        VStack(alignment: .leading, spacing: route.book.isPoetic ? AppSpacing.verseSpacingPoetic + 4 : AppSpacing.verseSpacingProse) {
            ForEach(interleaved.indices, id: \.self) { idx in
                let item = interleaved[idx]
                switch item {
                case .header(let note):
                    if headerMode == .custom {
                        SectionHeaderView(text: note.text)
                            .onTapGesture {
                                // Re-edit existing header by anchor verse
                                noteEditorTarget = NoteEditTarget(
                                    mode: .newSectionHeader(verse: note.verseId ?? 0),
                                    id: "h\(note.verseId ?? 0)"
                                )
                            }
                    }
                case .verse(let verse):
                    verseRow(verse)
                }
            }
        }
    }

    @ViewBuilder
    private func verseRow(_ verse: BibleVerse) -> some View {
        let isSelected = pickerVerse == verse.number
        let highlight = highlightColor(for: verse.number)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // Note indicator dot in the gutter — appears for both anchored
            // notes and section-header re-entry hints.
            if hasAnchoredNote(for: verse.number) {
                Circle()
                    .fill(layerStore.active.accentColor)
                    .frame(width: 5, height: 5)
                    .offset(y: 8)
            } else {
                Color.clear.frame(width: 5, height: 5)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(verseAttributed(verse))
                    .lineSpacing(AppSpacing.scriptureLineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    inlineColorPicker(for: verse.number, current: highlight)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(highlight?.color ?? (isSelected ? AppColor.surface.opacity(0.6) : .clear))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.15)) {
                    pickerVerse = (pickerVerse == verse.number) ? nil : verse.number
                }
            }
        }
    }

    /// Inline 4-dot color picker that appears under a verse on tap. Includes
    /// a clear button when a highlight already exists.
    private func inlineColorPicker(for verseNumber: Int, current: HighlightColor?) -> some View {
        HStack(spacing: 10) {
            ForEach(HighlightColor.allCases) { color in
                Button {
                    setHighlight(verseNumber: verseNumber, color: color)
                    withAnimation(.easeOut(duration: 0.15)) { pickerVerse = nil }
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().strokeBorder(
                                color == current ? AppColor.textSecondary : .clear,
                                lineWidth: 1.5
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Highlight \(color.rawValue)")
            }
            if current != nil {
                Button {
                    clearHighlight(verseNumber: verseNumber)
                    withAnimation(.easeOut(duration: 0.15)) { pickerVerse = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear highlight")
            }
            Spacer()
        }
        .padding(.top, 2)
    }

    private var chapterFooter: some View {
        VStack(spacing: 12) {
            Rectangle().fill(AppColor.border).frame(height: 0.5).padding(.vertical, 32)
            if let next = navigator?.next(after: route) {
                Button {
                    advance(next)
                } label: {
                    HStack(spacing: 6) {
                        Text("\(next.book.displayName) \(next.chapter)")
                        Image(systemName: "chevron.right").font(.system(size: 12))
                    }
                    .font(AppFont.uiBody)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    // MARK: - Sheets

    @ViewBuilder
    private func sheet(for target: NoteEditTarget) -> some View {
        switch target.mode {
        case .newSectionHeader(let verse):
            NoteEditorSheet(
                title: "Header before verse \(verse)",
                placeholder: "Section title",
                initialText: existingSectionHeader(for: verse)?.text ?? "",
                onSave: { text in
                    if !text.isEmpty, let layer = activeLayer {
                        AnnotationStore(context: modelContext)
                            .setSectionHeader(beforeVerse: verse, text: text, on: layer)
                    }
                    noteEditorTarget = nil
                },
                onCancel: { noteEditorTarget = nil }
            )
        }
    }

    // MARK: - Body composition

    /// Either a section header note or a verse — the chapter renders these
    /// in order so a header anchored to verse N appears immediately before
    /// that verse.
    private enum ChapterItem {
        case header(VerseNote)
        case verse(BibleVerse)
    }

    private func interleavedItems(_ verses: [BibleVerse]) -> [ChapterItem] {
        let headersByVerse: [Int: VerseNote] = {
            guard let layer = activeLayer else { return [:] }
            var out: [Int: VerseNote] = [:]
            for note in layer.notes
            where note.kindRaw == NoteKind.sectionHeader.rawValue {
                if let v = note.verseId { out[v] = note }
            }
            return out
        }()
        var items: [ChapterItem] = []
        for verse in verses {
            if let header = headersByVerse[verse.number] {
                items.append(.header(header))
            }
            items.append(.verse(verse))
        }
        return items
    }

    // MARK: - Lookups & helpers

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

    /// Whether this verse has any anchored note (kind `.note`) — used to
    /// decide if the gutter dot appears. Section headers don't count.
    private func hasAnchoredNote(for verseNumber: Int) -> Bool {
        activeLayer?.notes.contains {
            $0.verseId == verseNumber && $0.kindRaw == NoteKind.note.rawValue
        } ?? false
    }

    private func existingSectionHeader(for verseNumber: Int) -> VerseNote? {
        activeLayer?.notes.first {
            $0.verseId == verseNumber && $0.kindRaw == NoteKind.sectionHeader.rawValue
        }
    }

    private func setHighlight(verseNumber: Int, color: HighlightColor) {
        guard let layer = activeLayer else { return }
        AnnotationStore(context: modelContext)
            .setHighlight(verseNumber: verseNumber, color: color, on: layer)
    }

    private func clearHighlight(verseNumber: Int) {
        guard let layer = activeLayer else { return }
        AnnotationStore(context: modelContext)
            .clearHighlight(verseNumber: verseNumber, on: layer)
    }

    /// USFM short codes for the toolbar reference. Uses 3-letter casings the
    /// Figma uses (Pe1 → "Pe1" → reformatted to "1Pe").
    private func usfmAbbrev(_ book: Book) -> String {
        // Display per the Figma: e.g. "JHN", "GEN", "1CO". Our raw values are
        // already in this form.
        book.rawValue
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

    // MARK: - Attributed strings

    private func verseAttributed(_ verse: BibleVerse) -> AttributedString {
        var num = AttributedString("\(verse.number) ")
        num.font = AppFont.verseNumber
        num.foregroundColor = AppColor.textFaint
        num.baselineOffset = 5
        var body = AttributedString(verse.text)
        body.font = AppFont.scriptureBody
        body.foregroundColor = AppColor.textPrimary
        return num + body
    }
}

/// Small-caps section header with thin underline divider. Lifted out so the
/// reader stays compact and other surfaces (like the chapter overview, if it
/// ever grows section indices) can reuse it.
struct SectionHeaderView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text.uppercased())
                .font(AppFont.sectionHeader)
                .tracking(AppSpacing.smallCapsTracking)
                .foregroundStyle(AppColor.sectionHeader)
            Rectangle()
                .fill(AppColor.border)
                .frame(height: 0.5)
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
