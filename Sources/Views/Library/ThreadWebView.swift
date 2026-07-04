import SwiftUI
import SwiftData

/// "Your threads in {Book}" — the personal constellation of every connection
/// drawn in or out of a book, colored by the mode each was made in (design
/// turn 8c). Edges render in a `Canvas`; nodes are real views so a tap can
/// carry you to that verse's chapter.
///
/// Layout is a tiny force simulation (repulsion + edge springs + centering)
/// run once on appear — deterministic thanks to a seeded start, no
/// dependency, no physics engine.
struct ThreadWebView: View {
    let book: Book

    @Environment(BibleStore.self) private var bibleStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.backgroundPalette) private var paletteRaw: String = BackgroundPalette.default.rawValue
    private var palette: BackgroundPalette { .current(rawValue: paletteRaw) }

    @State private var threads: [VerseThread] = []
    @State private var layout: [VerseRef: CGPoint] = [:]
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            legend
            if threads.isEmpty {
                emptyState
            } else {
                web
            }
        }
        .background(palette.color.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            loadThreads()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.textMuted)
            }
            .buttonStyle(.plain)
            Text("Your threads in \(book.displayName)")
                .font(Font.custom("CrimsonText-Regular", size: 22, relativeTo: .title3))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Text("\(threads.count) drawn")
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textMuted)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(LayerKind.allCases) { kind in
                HStack(spacing: 5) {
                    Circle().fill(kind.accentColor).frame(width: 7, height: 7)
                    Text(kind.displayName)
                        .font(AppFont.microCaps)
                        .foregroundStyle(kind.accentColor)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            ThreadLoopIcon()
                .stroke(AppColor.textFaint, style: ThreadLoopIcon.strokeStyle)
                .frame(width: 30, height: 36)
            Text("No threads yet — tap a verse and choose Thread… to weave one.")
                .font(AppFont.threadRef)
                .italic()
                .foregroundStyle(AppColor.textFaint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var web: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, _ in
                    for thread in threads {
                        guard let from = thread.fromRef, let to = thread.toRef,
                              let p1 = layout[from], let p2 = layout[to] else { continue }
                        var path = Path()
                        path.move(to: p1)
                        // A slight bow so parallel edges don't collapse into
                        // one straight line — matches the mock's hand-drawn feel.
                        let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                        let normal = CGVector(dx: -(p2.y - p1.y), dy: p2.x - p1.x)
                        let length = max(hypot(normal.dx, normal.dy), 1)
                        let bow = CGPoint(
                            x: mid.x + normal.dx / length * 18,
                            y: mid.y + normal.dy / length * 18
                        )
                        path.addQuadCurve(to: p2, control: bow)
                        context.stroke(
                            path,
                            with: .color(thread.mode.accentColor.opacity(0.55)),
                            lineWidth: 1.6
                        )
                    }
                }

                ForEach(Array(layout.keys), id: \.self) { ref in
                    if let point = layout[ref] {
                        node(for: ref)
                            .position(point)
                    }
                }
            }
            .onAppear {
                canvasSize = geo.size
                computeLayout(in: geo.size)
            }
            .onChange(of: geo.size) { _, newSize in
                canvasSize = newSize
                computeLayout(in: newSize)
            }
        }
        .padding(.top, 8)
    }

    private func node(for ref: VerseRef) -> some View {
        let degree = threads.filter { $0.fromRef == ref || $0.toRef == ref }.count
        let color = nodeColor(for: ref)
        return NavigationLink(value: ref.focusedRoute) {
            VStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: degree > 1 ? 16 : 12, height: degree > 1 ? 16 : 12)
                Text(ref.display)
                    .font(Font.custom("CrimsonText-Regular", size: 13, relativeTo: .caption))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
    }

    /// Nodes take the color of their most recent thread — a verse touched by
    /// several modes shows the latest conversation it was part of.
    private func nodeColor(for ref: VerseRef) -> Color {
        threads.last { $0.fromRef == ref || $0.toRef == ref }?.mode.accentColor
            ?? AppColor.textFaint
    }

    // MARK: - Data & layout

    private func loadThreads() {
        let translationId = bibleStore.translation?.identifier ?? "web"
        threads = AnnotationStore(context: modelContext)
            .threads(translation: translationId, inBook: book)
        if canvasSize != .zero {
            computeLayout(in: canvasSize)
        }
    }

    private func computeLayout(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        var refs: [VerseRef] = []
        var edges: [(Int, Int)] = []
        var indexOf: [VerseRef: Int] = [:]
        for thread in threads {
            guard let from = thread.fromRef, let to = thread.toRef else { continue }
            for ref in [from, to] where indexOf[ref] == nil {
                indexOf[ref] = refs.count
                refs.append(ref)
            }
            edges.append((indexOf[from]!, indexOf[to]!))
        }
        guard !refs.isEmpty else { return }

        // Seeded pseudo-random start so the web looks the same every visit.
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func random() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(UInt32.max)
        }
        let inset: CGFloat = 70
        var positions = refs.map { _ in
            CGPoint(
                x: inset + random() * (size.width - 2 * inset),
                y: inset + random() * (size.height - 2 * inset)
            )
        }

        // Fruchterman–Reingold-ish: repulsion ∝ k²/d, springs ∝ d²/k.
        let area = size.width * size.height
        let k = sqrt(area / CGFloat(refs.count)) * 0.7
        for iteration in 0..<250 {
            var displacement = [CGVector](repeating: .zero, count: refs.count)
            for i in refs.indices {
                for j in refs.indices where j > i {
                    let dx = positions[i].x - positions[j].x
                    let dy = positions[i].y - positions[j].y
                    let distance = max(hypot(dx, dy), 0.5)
                    let force = (k * k) / distance
                    displacement[i].dx += dx / distance * force
                    displacement[i].dy += dy / distance * force
                    displacement[j].dx -= dx / distance * force
                    displacement[j].dy -= dy / distance * force
                }
            }
            for (a, b) in edges {
                let dx = positions[a].x - positions[b].x
                let dy = positions[a].y - positions[b].y
                let distance = max(hypot(dx, dy), 0.5)
                let force = (distance * distance) / k
                displacement[a].dx -= dx / distance * force
                displacement[a].dy -= dy / distance * force
                displacement[b].dx += dx / distance * force
                displacement[b].dy += dy / distance * force
            }
            // Cooling: cap movement, shrinking as iterations pass.
            let temperature = size.width / 10 * (1 - CGFloat(iteration) / 250)
            for i in refs.indices {
                let magnitude = max(hypot(displacement[i].dx, displacement[i].dy), 0.5)
                let step = min(magnitude, temperature)
                positions[i].x += displacement[i].dx / magnitude * step
                positions[i].y += displacement[i].dy / magnitude * step
                positions[i].x = min(max(positions[i].x, inset), size.width - inset)
                positions[i].y = min(max(positions[i].y, inset), size.height - inset)
            }
        }

        layout = Dictionary(uniqueKeysWithValues: zip(refs, positions))
    }
}
