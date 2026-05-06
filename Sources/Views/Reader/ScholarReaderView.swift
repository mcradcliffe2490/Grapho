import SwiftUI
import SwiftData

/// Landscape "Scholar" layout: 50/50 split. Reader column on the left, a
/// two-mode notes area on the right.
///
/// The right pane has a layer-tap label centered at the very top, then a
/// segmented Writing | Notes toggle, then the active mode's content.
/// Writing mode shows a PencilKit canvas (the scratchpad); Notes mode shows
/// an Apple Notes-style drawer of typed notes.
///
/// Drawing now lives only in the right pane. The inline draw-on-text
/// overlay we tried earlier is gone — less ambiguous, no gesture-conflict
/// risk, and matches the user's revised spec for v2.
struct ScholarReaderView: View {
    @Environment(BibleStore.self) private var bibleStore
    @Environment(LayerStore.self) private var layerStore
    @Environment(\.modelContext) private var modelContext
    @AppStorage(PreferenceKey.pencilOnlyDraw) private var pencilOnly: Bool = false
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue

    let route: ChapterRoute
    let navigation: ReaderNavigation

    @State private var activeLayer: AnnotationLayer?
    @State private var scratchpadData: Data = Data()
    @State private var rightPaneMode: RightPaneMode = .writing

    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }

    enum RightPaneMode: String, CaseIterable, Identifiable {
        case writing
        case notes
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .writing: return "Writing"
            case .notes: return "Notes"
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ChapterReaderView(route: route, navigation: navigation, style: .scholar)
                    .frame(width: geo.size.width * 0.5)
                Divider()
                rightPane
                    .frame(width: geo.size.width * 0.5 - 1)
            }
        }
        // Library bubble at the window's left edge — works in both modes the
        // same way so the user's mental model is consistent across rotation.
        .overlay(alignment: .topLeading) {
            LibraryMenuButton(navigation: navigation)
                .padding(.leading, 16)
                .padding(.top, 12)
        }
        .task(id: paneKey) {
            await loadActiveLayer()
        }
        .background(palette.color.ignoresSafeArea())
    }

    private var rightPane: some View {
        VStack(spacing: 0) {
            // Layer-tap label sits centered above the mode toggle inside
            // the right pane (per design feedback — used to be over on the
            // global window-trailing edge).
            HStack {
                Spacer()
                LayerLabelTapTarget()
                Spacer()
            }
            .padding(.top, 14)
            .padding(.bottom, 8)

            modeToggle
            Divider()

            Group {
                switch rightPaneMode {
                case .writing:
                    DrawingCanvasView(
                        drawingData: $scratchpadData,
                        pencilOnly: pencilOnly,
                        onChange: persistScratchpad
                    )
                case .notes:
                    NotesPaneView(
                        layer: activeLayer,
                        book: route.book,
                        chapter: route.chapter,
                        verseCount: chapterVerseCount
                    )
                }
            }
            .background(palette.color)
        }
        .background(AppColor.surface.opacity(0.4))
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(RightPaneMode.allCases) { mode in
                Button {
                    rightPaneMode = mode
                } label: {
                    Text(mode.displayName.uppercased())
                        .font(AppFont.microCaps)
                        .tracking(AppSpacing.smallCapsTracking)
                        .foregroundStyle(mode == rightPaneMode ? AppColor.textPrimary : AppColor.textFaint)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(mode == rightPaneMode ? layerStore.active.accentColor : .clear)
                                    .frame(height: 1.5)
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var paneKey: String {
        "\(route.book.rawValue)-\(route.chapter)-\(layerStore.active.rawValue)"
    }

    /// Number of verses in the current chapter — used to clamp the
    /// notes anchor picker to real verse numbers. Falls back to 1 if the
    /// translation is missing this chapter, which shouldn't happen but
    /// keeps the picker non-empty.
    private var chapterVerseCount: Int {
        bibleStore.translation?
            .chapter(book: route.book, number: route.chapter)?
            .verses.count ?? 1
    }

    private func loadActiveLayer() async {
        guard let translationId = bibleStore.translation?.identifier else { return }
        let store = AnnotationStore(context: modelContext)
        let layer = store.findOrCreateLayer(
            kind: layerStore.active,
            translation: translationId,
            book: route.book,
            chapter: route.chapter
        )
        self.activeLayer = layer
        self.scratchpadData = layer.pkScratchpadData
    }

    private func persistScratchpad(_ data: Data) {
        guard let layer = activeLayer else { return }
        layer.pkScratchpadData = data
        try? modelContext.save()
    }
}
