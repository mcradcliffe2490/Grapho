import SwiftUI
import SwiftData
import PencilKit

/// Paper mode (design turns 3b/5a): the chapter printed on ruled paper — red
/// margin rule, faint lines — with a PencilKit canvas over everything. Draw
/// over the text, between lines, or in the writing space below the dashed
/// rule; finger scrolls, pencil draws, and the page is remembered exactly as
/// left. No study modes, no verse-tied anything.
struct PaperChapterView: View {
    @Environment(BibleStore.self) private var bibleStore
    @Environment(\.modelContext) private var modelContext

    let route: ChapterRoute
    let navigation: ReaderNavigation

    @State private var page: PaperPage?
    @State private var drawingData = Data()
    @State private var tool: PaperTool = .pen
    @State private var controller = CanvasController()
    /// Fades the handwriting hint once the page has any ink.
    @State private var hasInk = false

    /// The ruled-line rhythm; text leading is derived from it so the print
    /// sits on the lines.
    private let lineHeight: CGFloat = 36
    private let marginRuleX: CGFloat = 66

    private let paperColor = Color(hex: "#FCFBF7")
    private let ruleColor = Color(hex: "#ECE6D7")
    private let marginRuleColor = Color(hex: "#F0C9C2")

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(ruleColor).frame(height: 1)
            ScrollView {
                ZStack(alignment: .topLeading) {
                    ruledLines
                    printedChapter
                        .padding(.leading, marginRuleX + 16)
                        .padding(.trailing, 40)
                    DrawingCanvasView(
                        drawingData: $drawingData,
                        pencilOnly: false,
                        passesFingerThrough: true,
                        tool: tool.pkTool,
                        controller: controller,
                        onChange: persistDrawing
                    )
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .background(paperColor.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            toolPill
                .padding(.bottom, 20)
        }
        .overlay(alignment: .topLeading) {
            LibraryMenuButton(navigation: navigation, book: route.book)
                .padding(.leading, 16)
                .padding(.top, 60)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: pageKey) {
            await loadPage()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                navigation.openBook(route.book)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "#B7A98A"))
            }
            .buttonStyle(.plain)
            Button {
                if let prev = navigator?.previous(before: route) { navigation.advance(prev) }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#B7A98A"))
            }
            .buttonStyle(.plain)
            .disabled(navigator?.previous(before: route) == nil)
            Button {
                if let next = navigator?.next(after: route) { navigation.advance(next) }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#B7A98A"))
            }
            .buttonStyle(.plain)
            .disabled(navigator?.next(after: route) == nil)

            Spacer()

            Text("\(route.book.displayName.uppercased())  \(route.chapter)")
                .font(AppFont.wordmark)
                .tracking(2.5)
                .foregroundStyle(Color(hex: "#B7A98A"))

            Spacer()

            Text("PAPER")
                .font(AppFont.microCaps)
                .tracking(2)
                .foregroundStyle(Color(hex: "#CFC8BA"))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 15)
    }

    // MARK: - Paper & print

    private var ruledLines: some View {
        GeometryReader { geo in
            Path { path in
                var y = lineHeight
                while y < geo.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += lineHeight
                }
            }
            .stroke(ruleColor, lineWidth: 0.7)

            Path { path in
                path.move(to: CGPoint(x: marginRuleX, y: 0))
                path.addLine(to: CGPoint(x: marginRuleX, y: geo.size.height))
            }
            .stroke(marginRuleColor, lineWidth: 1)
        }
    }

    private var printedChapter: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let chapter = chapter {
                if let superscription = chapter.superscription {
                    Text(superscription)
                        .font(AppFont.superscription)
                        .italic()
                        .foregroundStyle(AppColor.textMuted)
                        .padding(.top, 10)
                }
                Text("\(route.book.displayName) \(route.chapter)")
                    .font(Font.custom("CrimsonText-Regular", size: 30, relativeTo: .title))
                    .foregroundStyle(AppColor.textPrimary)
                    .padding(.top, chapter.superscription == nil ? 12 : 4)
                    .padding(.bottom, 10)

                ForEach(chapter.verses) { verse in
                    Text(verseAttributed(verse))
                        .lineSpacing(lineHeight - crimsonLineHeight)
                        .padding(.bottom, 0)
                }

                // The writing space: dashed rule, then room that's yours.
                Rectangle()
                    .fill(.clear)
                    .frame(height: 1)
                    .overlay(
                        Line()
                            .stroke(Color(hex: "#DED7C6"), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                    .padding(.top, 18)
                if !hasInk {
                    Text("write here — this space is yours…")
                        .font(Font.custom("CrimsonText-Italic", size: 19, relativeTo: .body))
                        .foregroundStyle(Color(hex: "#D3CBB8"))
                        .padding(.top, 12)
                }
                Color.clear.frame(height: 340)
            } else {
                Text("Chapter not available in this translation.")
                    .font(AppFont.uiBody)
                    .foregroundStyle(AppColor.textFaint)
                    .padding(.top, 32)
            }
        }
        .padding(.bottom, 40)
    }

    /// Crimson 18's natural line height — the delta to `lineHeight` becomes
    /// `lineSpacing` so the print rides the ruled lines.
    private var crimsonLineHeight: CGFloat {
        UIFont(name: "CrimsonText-Regular", size: 18)?.lineHeight ?? 22
    }

    private func verseAttributed(_ verse: BibleVerse) -> AttributedString {
        var num = AttributedString("\(verse.number) ")
        num.font = Font.custom("Inter", size: 9)
        num.foregroundColor = Color(hex: "#CBC4B6")
        num.baselineOffset = 5
        var body = AttributedString(verse.text)
        body.font = Font.custom("CrimsonText-Regular", size: 18, relativeTo: .body)
        body.foregroundColor = Color(hex: "#2b2723")
        return num + body
    }

    // MARK: - Tool pill

    private var toolPill: some View {
        HStack(spacing: 15) {
            ForEach(PaperTool.allCases) { candidate in
                Button {
                    tool = candidate
                } label: {
                    ZStack {
                        Circle()
                            .fill(candidate.swatch)
                            .frame(width: 22, height: 22)
                        if candidate == .eraser {
                            Image(systemName: "eraser")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColor.textMuted)
                        }
                    }
                    .overlay(
                        Circle().strokeBorder(
                            tool == candidate ? AppColor.inkSurface : Color.black.opacity(0.12),
                            lineWidth: tool == candidate ? 2.5 : 1.5
                        )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(candidate.label)
            }

            Rectangle().fill(Color(hex: "#E0D8C6")).frame(width: 1, height: 20)

            Button("Undo") { controller.undo() }
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textMuted)
                .buttonStyle(.plain)
            Button("Clear") { clearPage() }
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textMuted)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(paperColor.opacity(0.94))
                .shadow(color: Color(hex: "#28221C").opacity(0.22), radius: 14, y: 5)
        )
        .overlay(Capsule().strokeBorder(Color(hex: "#E7E0CF"), lineWidth: 1))
    }

    // MARK: - Data

    private var chapter: BibleChapter? {
        bibleStore.translation?.chapter(book: route.book, number: route.chapter)
    }

    private var navigator: ChapterNavigator? {
        bibleStore.translation.map(ChapterNavigator.init)
    }

    private var pageKey: String {
        "\(route.book.rawValue)-\(route.chapter)"
    }

    private func loadPage() async {
        guard let translationId = bibleStore.translation?.identifier else { return }
        let store = AnnotationStore(context: modelContext)
        let page = store.findOrCreatePaperPage(
            translation: translationId,
            book: route.book,
            chapter: route.chapter
        )
        self.page = page
        self.drawingData = page.drawingData
        self.hasInk = !page.drawingData.isEmpty
        store.recordVisit(translation: translationId, book: route.book, chapter: route.chapter)
        try? store.save()
        LastReadingPosition(book: route.book, chapter: route.chapter).save()
    }

    private func persistDrawing(_ data: Data) {
        guard let page else { return }
        page.drawingData = data
        page.updatedAt = .now
        hasInk = !((try? PKDrawing(data: data))?.strokes.isEmpty ?? true)
        try? modelContext.save()
    }

    private func clearPage() {
        controller.clear()
        page?.drawingData = Data()
        hasInk = false
        try? modelContext.save()
    }
}

/// A horizontal line shape for dashed strokes.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

/// Paper's four tools (design 5a): graphite pencil, blue ink pen, a wide
/// soft highlighter, and a stroke eraser.
enum PaperTool: String, CaseIterable, Identifiable {
    case pen, ink, marker, eraser

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pen: return "Pencil"
        case .ink: return "Ink"
        case .marker: return "Highlighter"
        case .eraser: return "Eraser"
        }
    }

    var swatch: Color {
        switch self {
        case .pen: return Color(hex: "#33322F")
        case .ink: return Color(hex: "#2F4A7A")
        case .marker: return Color(hex: "#F2D06A")
        case .eraser: return .white
        }
    }

    var pkTool: PKTool {
        switch self {
        case .pen:
            return PKInkingTool(.pencil, color: UIColor(Color(hex: "#33322F")), width: 3)
        case .ink:
            return PKInkingTool(.pen, color: UIColor(Color(hex: "#2F4A7A")), width: 2.5)
        case .marker:
            return PKInkingTool(.marker, color: UIColor(Color(hex: "#F2D06A")), width: 16)
        case .eraser:
            return PKEraserTool(.vector)
        }
    }
}
