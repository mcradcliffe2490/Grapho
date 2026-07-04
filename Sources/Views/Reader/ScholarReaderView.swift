import SwiftUI
import SwiftData

/// Landscape "Scholar" layout, evolved into the **reflow split** (design turn
/// 6b): reader on the left, study pane on the right, and a draggable divider
/// between them — the text reflows as you resize, nothing gets covered, and
/// dragging the divider to the right edge collapses the pane to a thin tab
/// for pure reading.
///
/// Inside the pane, the three study modes are **rooms you move sideways
/// between** (turn 7a): a horizontal pager slides the mode's content over
/// while the pane's tint eases to the mode color. Switch by swiping, tapping
/// the tri-color tabs up top, or the color dots at the bottom.
struct ScholarReaderView: View {
    @Environment(BibleStore.self) private var bibleStore
    @Environment(LayerStore.self) private var layerStore
    @Environment(\.modelContext) private var modelContext
    @AppStorage(PreferenceKey.pencilOnlyDraw) private var pencilOnly: Bool = false
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue
    /// Reader fraction of the window. Persisted so the split survives
    /// relaunch; 1.0 means the pane is collapsed to its thin edge.
    @AppStorage(PreferenceKey.scholarSplitFraction) private var splitFraction: Double = 0.5

    let route: ChapterRoute
    let navigation: ReaderNavigation

    /// One layer per mode, loaded together so adjacent rooms in the pager
    /// are populated before they slide in.
    @State private var layers: [LayerKind: AnnotationLayer] = [:]
    @State private var scratchpads: [LayerKind: Data] = [:]
    @State private var rightPaneMode: RightPaneMode = .notes

    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }

    private let minFraction = 0.35
    private let maxFraction = 0.72
    /// Width of the reopen tab when the pane is collapsed.
    private let collapsedTabWidth: CGFloat = 22

    private var isCollapsed: Bool { splitFraction >= 0.99 }

    enum RightPaneMode: String, CaseIterable, Identifiable {
        case notes
        case writing
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
                    .frame(width: readerWidth(in: geo.size.width))

                if isCollapsed {
                    collapsedEdgeTab
                } else {
                    divider(totalWidth: geo.size.width)
                    studyPane
                        .frame(width: max(geo.size.width * (1 - splitFraction) - 1, 0))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isCollapsed)
            .coordinateSpace(name: "scholar")
        }
        // Library bubble at the window's left edge — works in both modes the
        // same way so the user's mental model is consistent across rotation.
        .overlay(alignment: .topLeading) {
            LibraryMenuButton(navigation: navigation, book: route.book)
                .padding(.leading, 16)
                .padding(.top, 12)
        }
        .task(id: paneKey) {
            await loadLayers()
        }
        .background(palette.color.ignoresSafeArea())
    }

    private func readerWidth(in total: CGFloat) -> CGFloat {
        isCollapsed ? total - collapsedTabWidth : total * splitFraction
    }

    // MARK: - Divider & collapse

    private func divider(totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color(hex: "#E4E0D8"))
            .frame(width: 1)
            .overlay {
                // Drag handle — three dots in a lozenge, centered.
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(AppColor.textFaint).frame(width: 2.5, height: 2.5)
                    }
                }
                .frame(width: 9, height: 44)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#E4E0D8"), lineWidth: 1))
            }
            .contentShape(Rectangle().inset(by: -12))
            .gesture(
                DragGesture(coordinateSpace: .named("scholar"))
                    .onChanged { value in
                        let fraction = value.location.x / totalWidth
                        if fraction > maxFraction + 0.1 {
                            // Dragged past the max — collapse for pure reading.
                            splitFraction = 1.0
                        } else {
                            splitFraction = min(max(fraction, minFraction), maxFraction)
                        }
                    }
            )
    }

    private var collapsedEdgeTab: some View {
        Button {
            splitFraction = 0.5
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                ForEach(LayerKind.allCases) { kind in
                    Circle().fill(kind.accentColor).frame(width: 5, height: 5)
                }
            }
            .foregroundStyle(AppColor.textFaint)
            .frame(width: collapsedTabWidth)
            .frame(maxHeight: .infinity)
            .background(AppColor.surface.opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open study pane")
    }

    // MARK: - Study pane

    private var studyPane: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    splitFraction = 1.0
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.textFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse study pane")
                Spacer()
                Text("STUDY")
                    .font(AppFont.microCaps)
                    .tracking(AppSpacing.smallCapsTracking)
                    .foregroundStyle(AppColor.textFaint)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            modeTabs
            Divider().overlay(AppColor.border)

            paneToggleRow

            // The rooms — horizontal pager keyed to the active mode.
            TabView(selection: modeSelection) {
                ForEach(LayerKind.allCases) { kind in
                    room(for: kind)
                        .tag(kind)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            modeDots
        }
        .background(
            layerStore.active.accentColor.opacity(0.05)
                .animation(.easeInOut(duration: 0.45), value: layerStore.active)
        )
        .background(AppColor.surface.opacity(0.4))
    }

    private var modeSelection: Binding<LayerKind> {
        Binding(
            get: { layerStore.active },
            set: { layerStore.active = $0 }
        )
    }

    /// Tri-color segmented control (6b): dot + small-caps name per mode,
    /// active tab tinted and underlined in its accent.
    private var modeTabs: some View {
        HStack(spacing: 0) {
            ForEach(LayerKind.allCases) { kind in
                let isActive = kind == layerStore.active
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) { layerStore.active = kind }
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isActive ? kind.accentColor : Color.black.opacity(0.16))
                            .frame(width: 6, height: 6)
                        Text(kind.displayName.uppercased())
                            .font(AppFont.microCaps)
                            .tracking(1)
                            .fontWeight(isActive ? .semibold : .regular)
                            .foregroundStyle(isActive ? kind.accentColor : AppColor.textFaint)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(isActive ? kind.accentColor.opacity(0.07) : .clear)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(isActive ? kind.accentColor : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// NOTES | WRITING pill, right-aligned (6b). The mode name itself lives
    /// on the tabs above and the room header below — no need to say it a
    /// third time here.
    private var paneToggleRow: some View {
        HStack {
            Spacer()
            HStack(spacing: 0) {
                ForEach(RightPaneMode.allCases) { mode in
                    let selected = mode == rightPaneMode
                    Button {
                        rightPaneMode = mode
                    } label: {
                        Text(mode.displayName.uppercased())
                            .font(AppFont.microCaps)
                            .tracking(1)
                            .fontWeight(.semibold)
                            .foregroundStyle(selected ? .white : AppColor.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(selected ? layerStore.active.accentColor : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Capsule().fill(Color(hex: "#E9E5DE")))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// One mode's room: its name + tagline, then the notes drawer or the
    /// scratchpad, whichever the pill selects.
    @ViewBuilder
    private func room(for kind: LayerKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(kind.displayName.uppercased())
                    .font(AppFont.microCaps)
                    .tracking(3)
                    .fontWeight(.bold)
                    .foregroundStyle(kind.accentColor)
                Text(kind.tagline)
                    .font(AppFont.superscription)
                    .italic()
                    .foregroundStyle(AppColor.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)

            switch rightPaneMode {
            case .writing:
                DrawingCanvasView(
                    drawingData: scratchpadBinding(for: kind),
                    pencilOnly: pencilOnly,
                    onChange: { data in persistScratchpad(data, kind: kind) }
                )
            case .notes:
                NotesPaneView(
                    layer: layers[kind],
                    book: route.book,
                    chapter: route.chapter,
                    verseCount: chapterVerseCount,
                    onOpenRef: { ref in
                        navigation.advance(ref.focusedRoute)
                    }
                )
            }
        }
    }

    /// Compact pager dots at the bottom (7a): the active mode's dot stretches
    /// into a pill in its accent color.
    private var modeDots: some View {
        HStack(spacing: 9) {
            ForEach(LayerKind.allCases) { kind in
                let isActive = kind == layerStore.active
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) { layerStore.active = kind }
                } label: {
                    Capsule()
                        .fill(isActive ? kind.accentColor : Color.black.opacity(0.14))
                        .frame(width: isActive ? 22 : 7, height: 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kind.displayName)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .animation(.easeInOut(duration: 0.4), value: layerStore.active)
    }

    // MARK: - Data

    private var paneKey: String {
        "\(route.book.rawValue)-\(route.chapter)"
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

    private func scratchpadBinding(for kind: LayerKind) -> Binding<Data> {
        Binding(
            get: { scratchpads[kind] ?? Data() },
            set: { scratchpads[kind] = $0 }
        )
    }

    private func loadLayers() async {
        guard let translationId = bibleStore.translation?.identifier else { return }
        let store = AnnotationStore(context: modelContext)
        for kind in LayerKind.allCases {
            let layer = store.findOrCreateLayer(
                kind: kind,
                translation: translationId,
                book: route.book,
                chapter: route.chapter
            )
            layers[kind] = layer
            scratchpads[kind] = layer.pkScratchpadData
        }
    }

    private func persistScratchpad(_ data: Data, kind: LayerKind) {
        guard let layer = layers[kind] else { return }
        layer.pkScratchpadData = data
        try? modelContext.save()
    }
}
