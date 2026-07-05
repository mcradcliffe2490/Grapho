import SwiftUI
import SwiftData

/// The bottom of a note (design turns 9b/10a): the threads drawn out from
/// its anchor verse as chips, then "Linked mentions" — every note elsewhere
/// whose verse threads back into this one, gathered automatically. Also
/// hosts the "+ Thread" button so new connections can be woven from inside
/// a note.
struct NoteThreadsSection: View {
    let note: VerseNote

    @Environment(BibleStore.self) private var bibleStore
    @Environment(\.modelContext) private var modelContext

    @State private var threads: [VerseThread] = []
    @State private var mentions: [(note: VerseNote, mode: LayerKind, from: VerseRef)] = []
    @State private var pickerOpen = false

    private var anchorRef: VerseRef? { note.anchorRef }

    private var mode: LayerKind { note.layer?.kind ?? .exegetical }

    var body: some View {
        if let anchorRef {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(Color(hex: "#EDE9E1")).frame(height: 1)

                threadsHeader(anchorRef)
                    .padding(.top, 16)

                if threads.isEmpty {
                    Text("No threads yet — weave one to another verse.")
                        .font(AppFont.threadRef)
                        .italic()
                        .foregroundStyle(AppColor.textFaint)
                        .padding(.top, 10)
                } else {
                    chipRows(anchorRef)
                        .padding(.top, 11)
                }

                if !mentions.isEmpty {
                    Text("↩ LINKED MENTIONS · \(mentions.count)")
                        .font(AppFont.microCaps)
                        .tracking(1.5)
                        .foregroundStyle(AppColor.textFaint)
                        .padding(.top, 22)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(mentions, id: \.note.id) { mention in
                            mentionCard(mention)
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .task(id: note.id) {
                reload(anchorRef)
            }
            // Also refresh when the picker popover closes any way other
            // than Done (tap-outside still created the thread).
            .onChange(of: pickerOpen) { _, isOpen in
                if !isOpen { reload(anchorRef) }
            }
        }
    }

    private func threadsHeader(_ anchor: VerseRef) -> some View {
        HStack(spacing: 7) {
            ThreadLoopIcon()
                .stroke(threads.isEmpty ? AppColor.textFaint : mode.accentColor, style: ThreadLoopIcon.strokeStyle)
                .frame(width: 12, height: 15)
            Text("THREADS · \(threads.count)")
                .font(AppFont.microCaps)
                .tracking(1.5)
                .foregroundStyle(AppColor.textFaint)
            Spacer()
            Button {
                pickerOpen = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                    Text("Thread")
                        .font(AppFont.listSection)
                }
                .foregroundStyle(mode.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(mode.accentColor.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $pickerOpen, arrowEdge: .bottom) {
                if let translation = bibleStore.translation {
                    ThreadPickerFlow(
                        sourceRef: anchor,
                        translation: translation,
                        mode: mode,
                        onCreateThread: { target in
                            createThread(from: anchor, to: target)
                        },
                        onSetWhy: { thread, why in
                            thread.why = why
                            try? AnnotationStore(context: modelContext).save()
                        },
                        onDone: {
                            pickerOpen = false
                            reload(anchor)
                        }
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
    }

    private func chipRows(_ anchor: VerseRef) -> some View {
        FlowingChips(items: threads.compactMap { thread in
            thread.otherEnd(of: anchor).map { other in
                ChipModel(id: thread.id, label: other.display, color: thread.mode.accentColor)
            }
        })
    }

    private func mentionCard(_ mention: (note: VerseNote, mode: LayerKind, from: VerseRef)) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Circle().fill(mention.mode.accentColor).frame(width: 6, height: 6)
                Text("\(mention.mode.displayName.uppercased()) · \(mention.from.display.uppercased())")
                    .font(AppFont.microCaps)
                    .tracking(1)
                    .fontWeight(.semibold)
                    .foregroundStyle(mention.mode.accentColor)
            }
            Text(mention.note.previewContent)
                .font(Font.custom("CrimsonText-Regular", size: 14, relativeTo: .footnote))
                .foregroundStyle(Color(hex: "#4B453D"))
                .lineLimit(2)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#F6F3EE")))
    }

    // MARK: - Data

    private func reload(_ anchor: VerseRef) {
        let translationId = bibleStore.translation?.identifier ?? "web"
        let store = AnnotationStore(context: modelContext)
        let touching = store.threads(translation: translationId, book: anchor.book, chapter: anchor.chapter)
            .filter { $0.fromRef == anchor || $0.toRef == anchor }
        threads = touching
        // Linked mentions: notes anchored at the far end of threads coming in.
        mentions = touching
            .filter { $0.toRef == anchor }
            .compactMap { $0.fromRef }
            .flatMap { from in
                store.notes(at: from, translation: translationId)
                    .filter { $0.note.id != note.id }
                    .map { (note: $0.note, mode: $0.mode, from: from) }
            }
    }

    private func createThread(from: VerseRef, to target: VerseRef) -> VerseThread {
        let store = AnnotationStore(context: modelContext)
        let thread = store.addThread(
            translation: bibleStore.translation?.identifier ?? "web",
            from: from,
            to: target,
            mode: mode
        )
        try? store.save()
        return thread
    }
}

// MARK: - Chips

struct ChipModel: Identifiable {
    let id: UUID
    let label: String
    let color: Color
}

/// Wrapping row of thread chips (10a): white pill, mode dot, verse ref.
struct FlowingChips: View {
    let items: [ChipModel]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { chip in
                HStack(spacing: 7) {
                    Circle().fill(chip.color).frame(width: 6, height: 6)
                    Text(chip.label)
                        .font(AppFont.listSection)
                        .foregroundStyle(Color(hex: "#3A352F"))
                }
                .padding(.leading, 9)
                .padding(.trailing, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white))
                .overlay(Capsule().strokeBorder(Color(hex: "#EAE5DC"), lineWidth: 1))
            }
        }
    }
}

/// Minimal wrapping layout — lines break when chips overflow the width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: rows.last.map { $0.minY + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private struct Row {
        var minY: CGFloat
        var height: CGFloat
        var width: CGFloat
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                rows.append(Row(minY: y, height: rowHeight, width: x - spacing))
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        rows.append(Row(minY: y, height: rowHeight, width: max(x - spacing, 0)))
        return rows
    }
}
