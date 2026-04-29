import SwiftUI

/// Three-segment layer picker for the reader toolbar. Inactive segments are
/// muted; the active one is filled with the layer's accent color so the
/// drawing/highlight context is readable at a glance. Driven by the shared
/// `LayerStore` so every place that reads `active` updates in lockstep.
struct LayerSwitcher: View {
    @Environment(LayerStore.self) private var layerStore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LayerKind.allCases) { kind in
                Button {
                    layerStore.active = kind
                } label: {
                    Text(kind.shortLabel)
                        .font(AppFont.layerIndicator)
                        .frame(width: 28, height: 24)
                        .foregroundStyle(textColor(for: kind))
                        .background(background(for: kind))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kind.displayName)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(AppColor.border, lineWidth: 0.5)
        )
    }

    private func textColor(for kind: LayerKind) -> Color {
        kind == layerStore.active ? .white : AppColor.textSecondary
    }

    private func background(for kind: LayerKind) -> Color {
        kind == layerStore.active ? kind.accentColor : AppColor.surface
    }
}
