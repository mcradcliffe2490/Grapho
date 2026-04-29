import SwiftUI
import SwiftData

/// Landscape "Scholar" layout: reading column on the left, freeform PencilKit
/// scratchpad on the right. Both panes are scoped to the same `AnnotationLayer`,
/// so switching layers swaps highlights, notes, AND the scratchpad drawing
/// in lockstep.
///
/// The split is 60/40 in favor of reading — the right pane is for sketches
/// and marginalia, not the primary surface.
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
                // Reuse the portrait reader as the left pane verbatim — same
                // highlight/note/header machinery.
                ChapterReaderView(route: route, advance: advance)
                    .frame(width: geo.size.width * 0.6)

                Divider()

                scratchpad
                    .frame(width: geo.size.width * 0.4 - 1)
            }
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
                Button {
                    clearDrawing()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(AppColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear scratchpad")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColor.surface)

            DrawingCanvasView(
                drawingData: $scratchpadData,
                pencilOnly: pencilOnly,
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

    private func clearDrawing() {
        scratchpadData = Data()
        if let layer = activeLayer {
            layer.pkScratchpadData = Data()
            try? modelContext.save()
        }
    }
}
