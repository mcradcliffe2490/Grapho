import SwiftUI
import SwiftData

/// The reading page, "Lectio calm" (design turns 2b/3a): verse numbers hang
/// faint in the left margin, highlights are a whisper behind the words, and
/// all annotation retreats to the right gutter — a dot per note (colored by
/// the mode it was made in, every mode visible while reading) and a thread
/// loop where the verse is threaded (turn 9a).
///
/// Tapping a verse opens the dark action menu — Highlight · Note · Thread…
/// (turn 8a). Tapping a gutter mark floats the notes / thread list in.
///
/// Reader portrait shows its own toolbar; Scholar landscape suppresses it
/// because the parent `ScholarReaderView` provides one for the whole window.
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
    /// All three layers for this chapter, in Exegetical → Devotional →
    /// Thematic order — margin dots show every mode's notes while reading,
    /// not just the active one.
    @State private var allLayers: [AnnotationLayer] = []
    /// Threads touching any verse of this chapter, either direction.
    @State private var chapterThreads: [VerseThread] = []
    /// `chapterThreads` indexed by local verse number, so verse rows don't
    /// re-filter the whole list on every render.
    @State private var threadsByVerse: [Int: [VerseThread]] = [:]

    /// Verse whose action menu popover is open.
    @State private var menuVerse: Int?
    /// Verse whose margin note cards are showing.
    @State private var notesPopoverVerse: Int?
    /// Verse whose thread list is showing.
    @State private var threadsPopoverVerse: Int?
    /// Verse briefly pulsed after arriving via a thread (route.focusVerse).
    @State private var flashVerse: Int?
    /// Thread opened full-length in the "Pull thread" sheet.
    @State private var pulledThread: VerseThread?
    /// The focus scroll runs once per arrival — without this guard, the
    /// keyed task re-fires on every layer switch and yanks the scroll
    /// position back to the focus verse.
    @State private var didFocus = false

    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }
    private var headerMode: HeaderMode { .current(rawValue: headerModeRaw) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if style == .reader {
                        topToolbar
                            .padding(.top, 20)
                    }

                    if let chapter = chapter {
                        previousChapterBar
                            .padding(.top, style == .reader ? 24 : 32)

                        if let superscription = chapter.superscription {
                            Text(superscription)
                                .font(AppFont.superscription)
                                .italic()
                                .foregroundStyle(AppColor.textFaint)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 24)
                        }

                        chapterBody(chapter)
                            .padding(.top, chapter.superscription == nil ? 28 : 20)

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
            .task(id: chapterKey) {
                await focusIfNeeded(proxy)
            }
        }
        .background(palette.color.ignoresSafeArea())
        // Library bubble — left margin, fixed in screen space. Reader
        // portrait shows it here; Scholar's parent supplies its own copy
        // so the bubble lives at the window edge, not the column edge.
        .overlay(alignment: .topLeading) {
            if style == .reader {
                LibraryMenuButton(navigation: navigation, book: route.book)
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $pulledThread) { thread in
            ThreadDetailView(
                thread: thread,
                onOpenRef: { target in advance(target.focusedRoute) },
                onDelete: { deleteThread(thread) }
            )
        }
        .task(id: chapterKey) {
            await onChapterAppear()
        }
        // Re-fetch on pop-back: notes and threads created downstream (the
        // full-screen editor, the thread web) must show in the margins
        // without needing a chapter or layer switch.
        .onAppear {
            refreshAnnotations()
        }
    }

    // MARK: - Top toolbar

    /// Chrome nearly gone (2b): chevrons small on the left, the chapter
    /// reference centered in tracked caps, the active mode chip on the right.
    private var topToolbar: some View {
        HStack(alignment: .center) {
            Button {
                if let prev = navigator?.previous(before: route) { advance(prev) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.textFaint)
            }
            .buttonStyle(.plain)
            .disabled(navigator?.previous(before: route) == nil)
            // Clear the floating library bubble overlaid at the window edge.
            .padding(.leading, 36)
            Button {
                if let next = navigator?.next(after: route) { advance(next) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.textFaint)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .disabled(navigator?.next(after: route) == nil)

            Spacer()

            Text("\(route.book.displayName.uppercased())  \(route.chapter)")
                .font(AppFont.wordmark)
                .tracking(3)
                .foregroundStyle(AppColor.textFaint)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(layerStore.active.accentColor)
                    .frame(width: 6, height: 6)
                LayerLabelTapTarget()
            }
        }
    }

    // MARK: - Chapter body

    @ViewBuilder
    private func chapterBody(_ chapter: BibleChapter) -> some View {
        let interleaved = interleavedItems(chapter.verses)

        VStack(alignment: .leading, spacing: route.book.isPoetic ? AppSpacing.verseSpacingPoetic : AppSpacing.verseSpacingProse) {
            ForEach(interleaved.indices, id: \.self) { idx in
                let item = interleaved[idx]
                switch item {
                case .header(let note):
                    if headerMode == .custom {
                        // Tap re-opens the anchor verse's menu, where the
                        // Header action edits or removes this header.
                        SectionHeaderView(text: note.text)
                            .onTapGesture {
                                menuVerse = note.verseId
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
        let ref = verseRef(verse.number)
        let verseNotes = notes(for: verse.number)
        let verseThreads = threads(touching: verse.number)

        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Hanging margin number.
            Text("\(verse.number)")
                .font(AppFont.verseNumber)
                .foregroundStyle(AppColor.marginNumber)
                .frame(width: 24, alignment: .trailing)

            Text(verseAttributed(verse))
                .lineSpacing(AppSpacing.scriptureLineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(flashVerse == verse.number
                              ? layerStore.active.accentColor.opacity(0.10)
                              : .clear)
                )
                .padding(.horizontal, -6)
                .padding(.vertical, -4)
                .contentShape(Rectangle())
                .onTapGesture { menuVerse = verse.number }
                .popover(
                    isPresented: presenting($menuVerse, verse.number),
                    attachmentAnchor: .point(.top),
                    arrowEdge: .bottom
                ) {
                    actionPopover(for: ref)
                }

            // Right gutter: note dots + thread loop.
            VStack(spacing: 5) {
                if !verseNotes.isEmpty {
                    Button {
                        notesPopoverVerse = verse.number
                    } label: {
                        VStack(spacing: 4) {
                            ForEach(Array(verseNotes.prefix(3).enumerated()), id: \.offset) { _, entry in
                                Circle()
                                    .fill(entry.mode.accentColor)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .contentShape(Rectangle().inset(by: -8))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: presenting($notesPopoverVerse, verse.number), arrowEdge: .trailing) {
                        NoteCardsPopover(notes: verseNotes, verseNumber: verse.number) { note in
                            notesPopoverVerse = nil
                            navigation.openNote(note.id)
                        }
                    }
                }
                if !verseThreads.isEmpty {
                    Button {
                        threadsPopoverVerse = verse.number
                    } label: {
                        ThreadLoopIcon()
                            .stroke(
                                (verseThreads.last?.mode ?? .exegetical).accentColor,
                                style: ThreadLoopIcon.strokeStyle
                            )
                            .frame(width: 15, height: 18)
                            .contentShape(Rectangle().inset(by: -6))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: presenting($threadsPopoverVerse, verse.number), arrowEdge: .trailing) {
                        ThreadListPopover(
                            ref: ref,
                            threads: verseThreads,
                            onOpen: { target in
                                threadsPopoverVerse = nil
                                advance(target.focusedRoute)
                            },
                            onPull: { thread in
                                threadsPopoverVerse = nil
                                pulledThread = thread
                            },
                            onDelete: { thread in
                                deleteThread(thread)
                            }
                        )
                    }
                }
                if verseNotes.isEmpty && verseThreads.isEmpty {
                    Color.clear.frame(width: 15, height: 6)
                }
            }
            .frame(width: 16)
        }
        .id(verse.number)
    }

    /// Binding that shows a popover while `state` equals this row's verse.
    private func presenting(_ state: Binding<Int?>, _ verse: Int) -> Binding<Bool> {
        Binding(
            get: { state.wrappedValue == verse },
            set: { if !$0 { state.wrappedValue = nil } }
        )
    }

    /// The verse menu needs a loaded translation (thread search runs against
    /// it); until then a tap simply does nothing rather than opening a menu
    /// wired to empty data.
    @ViewBuilder
    private func actionPopover(for ref: VerseRef) -> some View {
        if let translation = bibleStore.translation {
            VerseActionPopover(
                sourceRef: ref,
                translation: translation,
                mode: layerStore.active,
                currentHighlight: highlightColor(for: ref.verse),
                existingHeader: existingSectionHeader(before: ref.verse)?.text ?? "",
                onHighlight: { color in
                    if let color {
                        setHighlight(verseNumber: ref.verse, color: color)
                    } else {
                        clearHighlight(verseNumber: ref.verse)
                    }
                    menuVerse = nil
                },
                onNote: {
                    menuVerse = nil
                    openNewNote(anchoredAt: ref.verse)
                },
                onHeader: { text in
                    setSectionHeader(beforeVerse: ref.verse, text: text)
                    menuVerse = nil
                },
                onCreateThread: { target in
                    createThread(from: ref, to: target)
                },
                onSetWhy: { thread, why in
                    thread.why = why
                    try? AnnotationStore(context: modelContext).save()
                },
                onClose: { menuVerse = nil }
            )
        }
    }

    /// Mirror of the footer, pointing backward — "‹ John 2" at the top of
    /// the chapter, so moving back is as easy as moving forward.
    @ViewBuilder
    private var previousChapterBar: some View {
        if let prev = navigator?.previous(before: route) {
            Button {
                advance(prev)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 12))
                    Text("\(prev.book.displayName) \(prev.chapter)")
                }
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppColor.surface.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
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

    private func verseRef(_ verse: Int) -> VerseRef {
        VerseRef(book: route.book, chapter: route.chapter, verse: verse)
    }

    private func highlightColor(for verseNumber: Int) -> HighlightColor? {
        activeLayer?.highlights.first { $0.verseId == verseNumber }?.color
    }

    /// Notes on this verse across every mode; `allLayers` is already in
    /// Exegetical → Devotional → Thematic order so dot stacks are stable.
    private func notes(for verseNumber: Int) -> [(note: VerseNote, mode: LayerKind)] {
        allLayers.flatMap { layer in
            layer.notes
                .filter { $0.verseId == verseNumber && $0.kindRaw == NoteKind.note.rawValue }
                .map { (note: $0, mode: layer.kind) }
        }
    }

    private func threads(touching verseNumber: Int) -> [VerseThread] {
        threadsByVerse[verseNumber] ?? []
    }

    // MARK: - Mutations

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

    private func existingSectionHeader(before verseNumber: Int) -> VerseNote? {
        activeLayer?.notes.first {
            $0.verseId == verseNumber && $0.kindRaw == NoteKind.sectionHeader.rawValue
        }
    }

    /// Create/update the header above this verse; empty text removes it.
    private func setSectionHeader(beforeVerse verseNumber: Int, text: String) {
        guard let layer = activeLayer else { return }
        let store = AnnotationStore(context: modelContext)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if let existing = existingSectionHeader(before: verseNumber) {
                store.deleteNote(existing)
            }
        } else {
            store.setSectionHeader(beforeVerse: verseNumber, text: trimmed, on: layer)
        }
        try? store.save()
    }

    private func openNewNote(anchoredAt verseNumber: Int) {
        guard let layer = activeLayer else { return }
        let store = AnnotationStore(context: modelContext)
        let note = store.addNote(verseNumber: verseNumber, text: "", on: layer)
        try? store.save()
        navigation.openNote(note.id)
    }

    private func createThread(from: VerseRef, to target: VerseRef) -> VerseThread {
        let store = AnnotationStore(context: modelContext)
        let thread = store.addThread(
            translation: bibleStore.translation?.identifier ?? "web",
            from: from,
            to: target,
            mode: layerStore.active
        )
        try? store.save()
        chapterThreads.append(thread)
        return thread
    }

    private func deleteThread(_ thread: VerseThread) {
        let store = AnnotationStore(context: modelContext)
        store.deleteThread(thread)
        try? store.save()
        chapterThreads.removeAll { $0.id == thread.id }
        threadsPopoverVerse = nil
    }

    // MARK: - Lifecycle

    private func onChapterAppear() async {
        // The task re-runs on layer switches too — close any open popover so
        // it can't act on the previous layer's state.
        menuVerse = nil
        notesPopoverVerse = nil
        threadsPopoverVerse = nil
        guard let translationId = bibleStore.translation?.identifier else { return }
        let store = AnnotationStore(context: modelContext)
        activeLayer = store.findOrCreateLayer(
            kind: layerStore.active,
            translation: translationId,
            book: route.book,
            chapter: route.chapter
        )
        refreshAnnotations()
        store.recordVisit(translation: translationId, book: route.book, chapter: route.chapter)
        try? store.save()
        LastReadingPosition(book: route.book, chapter: route.chapter).save()
    }

    /// Read-only re-fetch of everything the margins render. Cheap and
    /// idempotent — safe to call on every appearance.
    private func refreshAnnotations() {
        guard let translationId = bibleStore.translation?.identifier else { return }
        let store = AnnotationStore(context: modelContext)
        let order = LayerKind.allCases
        allLayers = store.layers(translation: translationId, book: route.book, chapter: route.chapter)
            .sorted {
                (order.firstIndex(of: $0.kind) ?? 0) < (order.firstIndex(of: $1.kind) ?? 0)
            }
        chapterThreads = store.threads(translation: translationId, book: route.book, chapter: route.chapter)
        reindexThreads()
    }

    private func reindexThreads() {
        var index: [Int: [VerseThread]] = [:]
        for thread in chapterThreads {
            for ref in [thread.fromRef, thread.toRef] {
                if let ref, ref.book == route.book, ref.chapter == route.chapter {
                    index[ref.verse, default: []].append(thread)
                }
            }
        }
        threadsByVerse = index
    }

    /// Scroll to `route.focusVerse` (arriving via a thread) and pulse it.
    private func focusIfNeeded(_ proxy: ScrollViewProxy) async {
        guard let verse = route.focusVerse, !didFocus else { return }
        didFocus = true
        // Let the chapter lay out before jumping.
        try? await Task.sleep(for: .milliseconds(350))
        withAnimation(.easeInOut(duration: 0.45)) {
            proxy.scrollTo(verse, anchor: .center)
        }
        withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
            flashVerse = verse
        }
        try? await Task.sleep(for: .seconds(2))
        withAnimation(.easeOut(duration: 0.8)) {
            flashVerse = nil
        }
    }

    // MARK: - Attributed strings

    /// The verse body. Highlights render as a whisper — the wash sits behind
    /// the words themselves (no rounded box, no full-row fill).
    private func verseAttributed(_ verse: BibleVerse) -> AttributedString {
        var body = AttributedString(verse.text)
        body.font = AppFont.scriptureBody
        body.foregroundColor = AppColor.textPrimary
        if let highlight = highlightColor(for: verse.number) {
            body.backgroundColor = highlight.color.opacity(0.75)
        }
        return body
    }
}

/// Section header on the Lectio page (2b): centered Crimson italic with a
/// short hairline beneath — a breath, not a signpost.
struct SectionHeaderView: View {
    let text: String

    var body: some View {
        VStack(spacing: 16) {
            Text(text)
                .font(AppFont.sectionHeaderSerif)
                .foregroundStyle(AppColor.textMuted)
            Rectangle()
                .fill(Color(hex: "#E0DACF"))
                .frame(width: 26, height: 1)
        }
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }
}
