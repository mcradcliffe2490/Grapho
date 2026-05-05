import SwiftUI

/// Small caps active-layer label that doubles as a tap target for switching
/// layers. Sits in the top-right of the reader toolbar where the Figma puts
/// "EXEGETICAL", colored in the layer's accent. Tap → popover with the three
/// layers by full name.
///
/// Replaces the floating graduation-cap menu.
struct LayerLabelTapTarget: View {
    @Environment(LayerStore.self) private var layerStore
    @State private var open = false

    var body: some View {
        Button {
            open = true
        } label: {
            Text(layerStore.active.displayName.uppercased())
                .font(AppFont.wordmark)
                .tracking(2)
                .foregroundStyle(layerStore.active.accentColor)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .top) {
            popoverContents
                .presentationCompactAdaptation(.popover)
        }
    }

    private var popoverContents: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LAYER")
                .font(AppFont.microCaps)
                .tracking(AppSpacing.smallCapsTracking)
                .foregroundStyle(AppColor.textFaint)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(LayerKind.allCases) { kind in
                Button {
                    layerStore.active = kind
                    open = false
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(kind.accentColor)
                            .frame(width: 10, height: 10)
                        Text(kind.displayName)
                            .font(AppFont.uiBody)
                            .foregroundStyle(AppColor.textPrimary)
                        Spacer()
                        if kind == layerStore.active {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(kind.accentColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 220)
            }
        }
        .padding(.bottom, 8)
    }
}
