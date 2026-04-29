import SwiftUI

/// Round graduation-cap bubble that floats in the right margin of the reader,
/// fixed in screen space (it does NOT scroll with the chapter content).
/// Tapping it reveals a popover "drawer" with a Layers section listing the
/// three layers by their full names. Replaces the old toolbar segmented
/// switcher.
///
/// Lives in both Reader and Scholar — layers exist in both modes, and
/// keeping one access pattern means the user's mental model survives a
/// rotation. Scholar mode adds a few extra actions (clear strokes) that
/// Reader hides.
struct FloatingScholarMenu: View {
    @Environment(LayerStore.self) private var layerStore
    let style: ReaderStyle
    /// Optional clear-actions surfaced from the parent. Scholar provides
    /// these so the user can wipe the inline canvas / scratchpad without
    /// hunting for a button. Reader passes nil and the section is hidden.
    let onClearInlineDrawing: (() -> Void)?
    let onClearScratchpad: (() -> Void)?

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            Image(systemName: "graduationcap")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(layerStore.active.accentColor)
                .frame(width: 44, height: 44)
                .background(AppColor.background)
                .overlay(
                    Circle().strokeBorder(AppColor.border, lineWidth: 0.5)
                )
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scholar menu")
        .popover(isPresented: $isOpen, arrowEdge: .trailing) {
            drawer
                .frame(minWidth: 240)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var drawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Layers")
            ForEach(LayerKind.allCases) { kind in
                layerRow(kind)
                if kind != LayerKind.allCases.last { Divider() }
            }

            if style == .scholar, (onClearInlineDrawing != nil || onClearScratchpad != nil) {
                Divider().padding(.top, 8)
                sectionHeader("Drawing")
                if let action = onClearInlineDrawing {
                    actionRow(label: "Clear ink on text", icon: "eraser", action: {
                        action()
                        isOpen = false
                    })
                    Divider()
                }
                if let action = onClearScratchpad {
                    actionRow(label: "Clear scratchpad", icon: "trash", action: {
                        action()
                        isOpen = false
                    })
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppFont.layerIndicator)
            .foregroundStyle(AppColor.textFaint)
            .tracking(1)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func layerRow(_ kind: LayerKind) -> some View {
        Button {
            layerStore.active = kind
            isOpen = false
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(kind.accentColor)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.displayName)
                        .font(.callout)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(kind.shortLabel)
                        .font(.caption2)
                        .foregroundStyle(AppColor.textFaint)
                }
                Spacer()
                if kind == layerStore.active {
                    Image(systemName: "checkmark")
                        .foregroundStyle(kind.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func actionRow(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(label)
                    .font(.callout)
                Spacer()
            }
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
