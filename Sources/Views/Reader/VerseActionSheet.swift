import SwiftUI

/// Bottom sheet that appears when the user taps a verse number in the reader.
/// Combines the three v1 verse-anchored actions in one place: pick a highlight
/// color, write a note, set a section header.
///
/// Single sheet (rather than three) so the reader stays tap-light: one tap
/// opens the surface, the user chooses what to do from there.
struct VerseActionSheet: View {
    let book: Book
    let chapter: Int
    let verseNumber: Int
    let currentColor: HighlightColor?
    let layerKind: LayerKind

    let onPickColor: (HighlightColor) -> Void
    let onClearHighlight: () -> Void
    let onAddNote: () -> Void
    let onAddSectionHeader: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            colorRow
            actionsRow
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.background)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(book.displayName) \(chapter):\(verseNumber)")
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text("\(layerKind.displayName) layer")
                    .font(.caption)
                    .foregroundStyle(layerKind.accentColor)
            }
            Spacer()
        }
    }

    private var colorRow: some View {
        HStack(spacing: 12) {
            ForEach(HighlightColor.allCases) { color in
                Button {
                    onPickColor(color)
                    onDismiss()
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().strokeBorder(
                                color == currentColor ? AppColor.textPrimary : AppColor.border,
                                lineWidth: color == currentColor ? 2 : 0.5
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Highlight \(color.rawValue)")
            }
            if currentColor != nil {
                Button {
                    onClearHighlight()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear highlight")
            }
            Spacer()
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            actionButton(label: "Add note", icon: "square.and.pencil") {
                onAddNote()
                onDismiss()
            }
            actionButton(label: "Section header", icon: "text.justify") {
                onAddSectionHeader()
                onDismiss()
            }
            Spacer()
        }
    }

    private func actionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.callout)
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(AppColor.border, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
