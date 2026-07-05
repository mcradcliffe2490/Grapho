import SwiftUI

/// The thread mark: one continuous stroke that rises from the lower-left,
/// curls over itself into a round loop, and trails off to the upper-right —
/// a thread mid-stitch. Replaces the design doc's glyph (a straight line with
/// a detached loop) with a single flowing path.
///
/// Drawn in a 15×18 design box and scaled to fit `rect`, so use `.frame` to
/// size it and `.stroke`/`foregroundStyle` to tint it:
///
///     ThreadLoopIcon()
///         .stroke(mode.accentColor, style: ThreadLoopIcon.strokeStyle)
///         .frame(width: 15, height: 18)
struct ThreadLoopIcon: Shape {
    static let strokeStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

    func path(in rect: CGRect) -> Path {
        // Design-box coordinates (15×18), scaled uniformly and centered.
        let scale = min(rect.width / 15, rect.height / 18)
        let dx = rect.midX - 7.5 * scale
        let dy = rect.midY - 9 * scale
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * scale + dx, y: y * scale + dy)
        }

        var path = Path()
        path.move(to: pt(1.5, 17.2))
        // Lower tail rising along the diagonal…
        path.addCurve(to: pt(7.6, 11.3), control1: pt(3.9, 15.3), control2: pt(6.0, 13.4))
        // …curl up and over into the loop…
        path.addCurve(to: pt(7.0, 7.7), control1: pt(8.9, 9.6), control2: pt(8.6, 7.4))
        // …around the loop and back onto the line…
        path.addCurve(to: pt(7.4, 10.8), control1: pt(5.2, 8.1), control2: pt(5.4, 10.9))
        // …then the upper tail continues the diagonal and eases upright.
        path.addCurve(to: pt(12.2, 6.2), control1: pt(9.4, 10.6), control2: pt(11.0, 8.4))
        path.addCurve(to: pt(13.6, 1.8), control1: pt(12.9, 4.9), control2: pt(13.4, 3.3))
        return path
    }
}

#Preview("Thread loop icon", traits: .sizeThatFitsLayout) {
    HStack(spacing: 24) {
        ForEach(LayerKind.allCases) { kind in
            ThreadLoopIcon()
                .stroke(kind.accentColor, style: ThreadLoopIcon.strokeStyle)
                .frame(width: 15, height: 18)
        }
        ThreadLoopIcon()
            .stroke(AppColor.textFaint, style: ThreadLoopIcon.strokeStyle)
            .frame(width: 30, height: 36)
    }
    .padding()
    .background(AppColor.background)
}
