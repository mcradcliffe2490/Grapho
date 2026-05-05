import SwiftUI
import SwiftData

/// Landscape "Scholar" layout: 50/50 split. Reader column on the left, a
/// two-mode notes area on the right.
///
/// The right pane has a segmented toggle at the top — Writing mode shows a
/// PencilKit canvas (the scratchpad), and Text Notes mode shows an
/// Apple Notes-style drawer of typed notes.
///
/// Drawing now lives only in the right pane; the inline draw-on-text
/// overlay we tried earlier is gone. Less ambiguous, no gesture-conflict
/// risk, and matches the user's revised spec for v2.
struct ScholarReaderView: View {
    @Environment(BibleStore.self) private var bibleStore
    @Environment(LayerStore.self) private var layerStore
    @Environment(\.modelContext) private var modelContext
    @AppStorage(PreferenceKey.pencilOnlyDraw) private var pencilOnly: Bool = false
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue

    let route: ChapterRoute
    let advance: (ChapterRoute) -> Void

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
                ChapterReaderView(route: route, advance: advance, style: .scholar)
                    .frame(width: geo.size.width * 0.5)
                Divider()
                rightPane
                    .frame(width: geo.size.width * 0.5 - 1)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Layer access in Scholar lives here too — same caps tap target
            // as Reader portrait, so the access pattern doesn't change with
            // rotation.
            LayerLabelTapTarget()
                .padding(.trailing, 24)
                .padding(.top, 16)
        }
        .task(id: paneKey) {
            await loadActiveLayer()
        }
        .background(palette.color.ignoresSafeArea())
    }

    private var rightPane: some View {
        VStack(spacing: 0) {
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
                        chapter: route.chapter
                    )
                }
            }
            .background(palette.color)
        }
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
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            // Subtle bottom underline on the active tab.
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
        .background(AppColor.surface.opacity(0.5))
    }

    private var paneKey: String {
        "\(route.book.rawValue)-\(route.chapter)-\(layerStore.active.rawValue)"
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
