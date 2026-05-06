import SwiftUI
import SwiftData

/// Reusable verse-anchor picker for note editors. Shown inside a `.popover`
/// from a tappable chip; lets the user attach the note to a specific verse,
/// detach it ("No anchor"), or pick from the chapter's actual verse list.
///
/// Sized large enough to show ~12 verses at a glance — the previous default
/// felt cramped because SwiftUI's compact-adaptation collapsed the popover
/// to one row. Both the in-pane editor (Scholar right pane) and the
/// full-screen note editor route through this view so the affordance stays
/// uniform.
struct NoteAnchorPicker: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: VerseNote
    /// Real verse count for the anchored chapter. The list is clamped to
    /// `1...max(verseCount, 1)` — falling back to 1 keeps the picker sane
    /// even if metadata is missing for some reason.
    let verseCount: Int
    let onDismiss: () -> Void

    /// Maximum height used both as the popover content height and as the
    /// scroll-region cap. Sized to fit ~12 rows comfortably.
    private static let pickerHeight: CGFloat = 480
    private static let pickerWidth: CGFloat = 320

    private var range: ClosedRange<Int> {
        let upper = max(verseCount, 1)
        return 1...upper
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 0) {
                    noAnchorRow
                    Divider()
                    ForEach(range, id: \.self) { v in
                        verseRow(v)
                        if v != range.upperBound {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .frame(width: Self.pickerWidth, height: Self.pickerHeight)
    }

    private var header: some View {
        HStack {
            Text("ANCHOR")
                .font(AppFont.microCaps)
                .tracking(AppSpacing.smallCapsTracking)
                .foregroundStyle(AppColor.textFaint)
            Spacer()
            Button("Done", action: onDismiss)
                .font(AppFont.uiBody)
                .foregroundStyle(AppColor.textSecondary)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var noAnchorRow: some View {
        Button {
            AnnotationStore(context: modelContext).clearNoteAnchor(note)
            try? modelContext.save()
            onDismiss()
        } label: {
            HStack {
                Text("No anchor")
                    .font(AppFont.uiBody)
                Spacer()
                if note.verseId == nil {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundStyle(AppColor.textPrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func verseRow(_ v: Int) -> some View {
        Button {
            note.verseId = v
            note.updatedAt = .now
            try? modelContext.save()
            onDismiss()
        } label: {
            HStack {
                Text("Verse \(v)")
                    .font(AppFont.uiBody)
                Spacer()
                if note.verseId == v {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(AppColor.textPrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
