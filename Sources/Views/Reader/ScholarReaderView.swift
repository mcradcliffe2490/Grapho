import SwiftUI
import SwiftData

/// Landscape "Scholar" layout: reading column on the left (with an inline
/// draw-on-text PencilKit overlay), freeform PencilKit scratchpad on the
/// right. Both surfaces are scoped to the same `AnnotationLayer`, so
/// switching layers swaps highlights, notes, the inline ink, AND the
/// scratchpad drawing in lockstep.
///
/// The split is 50/50 — the right pane gets equal real estate, matching the
/// design that the scratchpad is for writing *next to* the verses, not just
/// quick marginalia. Text margins widen in this mode (via `ReaderStyle`)
/// so the reading column doesn't crowd the divider.
struct ScholarReaderView: View {
    @Environment(BibleStore.self) private var bibleStore
    @Environment(LayerStore.self) private var layerStore
    @Environment(\.modelContext) private var modelContext
    @AppStorage(PreferenceKey.pencilOnlyDraw) private var pencilOnly: Bool = false
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue
    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }

    let route: ChapterRoute
    let advance: (ChapterRoute) -> Void

    @State private var activeLayer: AnnotationLayer?
    @State private var scratchpadData: Data = Data()

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left: portrait reader with style=.scholar (wider margins +
                // inline draw-on-text canvas activated).
                ChapterReaderView(route: route, advance: advance, style: .scholar)
                    .frame(width: geo.size.width * 0.5)

                Divider()

                scratchpad
                    .frame(width: geo.size.width * 0.5 - 1)
            }
        }
        .overlay(alignment: .topTrailing) {
            // One floating menu for the whole window — sits in the right
            // margin of the scratchpad pane. The embedded ChapterReaderView
            // suppresses its own menu when style == .scholar.
            FloatingScholarMenu(
                style: .scholar,
                onClearInlineDrawing: { clearInlineDrawing() },
                onClearScratchpad: { clearScratchpad() }
            )
            .padding(.trailing, 16)
            .padding(.top, 12)
        }
        .task(id: scratchpadKey) {
            await loadScratchpad()
        }
    }

    private var scratchpad: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "pencil.tip")
                    .foregroundStyle(layerStore.active.accentColor)
                Text("\(layerStore.active.displayName) scratchpad")
                    .font(AppFont.layerIndicator)
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColor.surface)

            DrawingCanvasView(
                drawingData: $scratchpadData,
                pencilOnly: pencilOnly,
                passesFingerThrough: false,
                onChange: { data in
                    persistScratchpad(data)
                }
            )
            .background(palette.color)
        }
    }

    private var scratchpadKey: String {
        "\(route.book.rawValue)-\(route.chapter)-\(layerStore.active.rawValue)"
    }

    private func loadScratchpad() async {
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

    private func clearScratchpad() {
        scratchpadData = Data()
        if let layer = activeLayer {
            layer.pkScratchpadData = Data()
            try? modelContext.save()
        }
    }

    private func clearInlineDrawing() {
        if let layer = activeLayer {
            layer.pkDrawingData = Data()
            try? modelContext.save()
        }
    }
}
