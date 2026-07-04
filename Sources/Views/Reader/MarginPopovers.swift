import SwiftUI

/// Popover behind a margin note dot (design turn 3a): one card per note on
/// the verse, each led by its mode chip. Notes from every mode are visible
/// while reading — the dot color already promised as much.
struct NoteCardsPopover: View {
    /// (note, the mode of the layer it lives on) — resolved by the parent so
    /// this view stays dumb about SwiftData.
    let notes: [(note: VerseNote, mode: LayerKind)]
    let verseNumber: Int
    let onOpen: (VerseNote) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(notes, id: \.note.id) { entry in
                Button {
                    onOpen(entry.note)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Circle().fill(entry.mode.accentColor).frame(width: 7, height: 7)
                            Text("\(entry.mode.displayName.uppercased()) · v\(verseNumber)")
                                .font(AppFont.microCaps)
                                .tracking(1.5)
                                .foregroundStyle(entry.mode.accentColor)
                        }
                        Text(entry.note.previewContent)
                            .font(AppFont.noteCard)
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(6)
                            .multilineTextAlignment(.leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
        .presentationCompactAdaptation(.popover)
    }
}

/// Popover behind a gutter thread loop (design turn 9a): every thread
/// touching the verse, either direction, colored by the mode each was made
/// in. Tapping a row carries you to the other end.
struct ThreadListPopover: View {
    let ref: VerseRef
    let threads: [VerseThread]
    let onOpen: (VerseRef) -> Void
    /// Open the full-length reading view (design language: "pull" it).
    let onPull: (VerseThread) -> Void
    let onDelete: (VerseThread) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THREADED · \(threads.count)")
                .font(AppFont.microCaps)
                .tracking(1.5)
                .foregroundStyle(AppColor.textFaint)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

            ForEach(threads) { thread in
                if let other = thread.otherEnd(of: ref) {
                    Divider().overlay(AppColor.cardBorder)
                    Button {
                        onOpen(other)
                    } label: {
                        HStack(alignment: .top, spacing: 9) {
                            Circle()
                                .fill(thread.mode.accentColor)
                                .frame(width: 7, height: 7)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(other.display)
                                    .font(AppFont.threadRef)
                                    .foregroundStyle(AppColor.textPrimary)
                                if !thread.why.isEmpty {
                                    Text(thread.why)
                                        .font(AppFont.listSection)
                                        .foregroundStyle(AppColor.textMuted)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            onPull(thread)
                        } label: {
                            Label("Pull thread", systemImage: "arrow.up.and.down.text.horizontal")
                        }
                        Button(role: .destructive) {
                            onDelete(thread)
                        } label: {
                            Label("Cut thread", systemImage: "scissors")
                        }
                    }
                }
            }
        }
        .frame(width: 262, alignment: .leading)
        .presentationCompactAdaptation(.popover)
    }
}
