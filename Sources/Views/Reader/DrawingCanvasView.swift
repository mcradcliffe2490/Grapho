import SwiftUI
import PencilKit

/// `PKCanvasView` subclass that lets finger touches fall through to whatever
/// is below it (typically a `ScrollView` carrying text), while still claiming
/// pencil touches for drawing. Used by the Scholar inline canvas so the
/// reader scrolls under finger drag and the pencil draws on top of the words.
///
/// The trick: hit-test by inspecting the touch types in the current event.
/// If any active touch is `.pencil`, claim the hit; otherwise return false
/// so UIKit walks past us to the underlying view. The standalone
/// `drawingPolicy = .pencilOnly` would block finger *drawing*, but it
/// wouldn't help with scroll passthrough — that's why this subclass exists.
final class PassThroughCanvasView: PKCanvasView {
    /// When `true`, this canvas behaves as an overlay that ignores finger
    /// hits entirely (their touches reach views below). When `false`, the
    /// canvas is a normal scroll-and-draw surface and gets all hits.
    var passesFingerThrough: Bool = true

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard passesFingerThrough else {
            return super.point(inside: point, with: event)
        }
        guard let touches = event?.allTouches else {
            // No touch info yet — claim the hit so a freshly-arriving pencil
            // event can route here. Subsequent finger events get re-evaluated.
            return super.point(inside: point, with: event)
        }
        // Claim the hit only if at least one touch is pencil.
        return touches.contains { $0.type == .pencil }
    }
}

/// Imperative handle onto a live canvas for custom tool UI. SwiftUI owns the
/// canvas's data flow; undo/clear are inherently imperative, so they go
/// through this thin reference instead of being faked with bindings.
@MainActor
final class CanvasController {
    weak var canvas: PKCanvasView?

    func undo() {
        canvas?.undoManager?.undo()
    }

    func clear() {
        canvas?.drawing = PKDrawing()
    }
}

/// SwiftUI wrapper around `PKCanvasView` (specifically `PassThroughCanvasView`).
/// Loads serialized `PKDrawing` data in, calls `onChange` with new data after
/// a short debounce, and switches between pencil-only and finger-allowed input
/// based on user preference.
///
/// The debounce matters: `canvasViewDrawingDidChange` fires on every stroke
/// segment. Persisting on each call would thrash SwiftData. 1.5 s of idle
/// after the last change is the right balance — fast enough that an
/// accidental app-switch doesn't lose work, slow enough that no real session
/// of drawing involves more than a handful of saves.
///
/// The tool picker is the standard `PKToolPicker` floating palette; we make
/// the canvas first-responder on appear so the palette shows up.
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data
    let pencilOnly: Bool
    /// Pass finger touches through to whatever's below the canvas. Used by
    /// the inline draw-on-text overlay in Scholar mode so the reader keeps
    /// its scroll-on-finger behavior. The standalone scratchpad sets this
    /// to `false` since it's the only thing in its pane.
    var passesFingerThrough: Bool = false
    /// When set, the canvas uses this tool and the `PKToolPicker` palette is
    /// never shown — the caller owns tool UI (Paper mode's pill). `nil`
    /// keeps today's behavior: Apple's floating picker.
    var tool: PKTool?
    /// Optional handle for imperative canvas actions (undo / clear) from
    /// custom tool UI. The representable attaches its canvas on make.
    var controller: CanvasController?
    let onChange: (Data) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PassThroughCanvasView()
        canvas.passesFingerThrough = passesFingerThrough
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // The inline canvas piggybacks on the outer ScrollView; disable its
        // own scrolling so it doesn't fight for finger pans.
        canvas.isScrollEnabled = !passesFingerThrough
        canvas.alwaysBounceVertical = !passesFingerThrough
        canvas.alwaysBounceHorizontal = false
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1

        if let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }

        controller?.canvas = canvas

        if let tool {
            canvas.tool = tool
        } else {
            // Tool picker: present once attached to a window. Doing it on next
            // run-loop avoids the canvas-not-yet-in-window race.
            DispatchQueue.main.async { [weak canvas] in
                guard let canvas, let window = canvas.window else { return }
                let picker = PKToolPicker.shared(for: window) ?? PKToolPicker()
                picker.setVisible(true, forFirstResponder: canvas)
                picker.addObserver(canvas)
                canvas.becomeFirstResponder()
                context.coordinator.toolPicker = picker
            }
        }

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Update policy if the user toggled the pref while the view is alive.
        let desired: PKCanvasViewDrawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        if canvas.drawingPolicy != desired {
            canvas.drawingPolicy = desired
        }
        if let pt = canvas as? PassThroughCanvasView {
            pt.passesFingerThrough = passesFingerThrough
        }

        if let tool {
            canvas.tool = tool
        }

        // Reload the drawing only when the externally-bound data actually
        // changes from a *different* source (e.g. layer switch) — never echo
        // our own write back through here, or every save would clobber the
        // in-flight stroke.
        if drawingData != context.coordinator.lastWrittenData,
           let drawing = try? PKDrawing(data: drawingData),
           drawing.dataRepresentation() != canvas.drawing.dataRepresentation() {
            canvas.drawing = drawing
        }
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker?.setVisible(false, forFirstResponder: canvas)
        coordinator.toolPicker?.removeObserver(canvas)
        coordinator.saveWorkItem?.cancel()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView
        var toolPicker: PKToolPicker?
        var saveWorkItem: DispatchWorkItem?
        /// Snapshot of the last data we pushed *out* through `onChange`. We
        /// compare against this in `updateUIView` to avoid clobbering the
        /// canvas with our own writes.
        var lastWrittenData: Data = Data()

        init(parent: DrawingCanvasView) {
            self.parent = parent
            self.lastWrittenData = parent.drawingData
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            scheduleSave(canvasView)
        }

        private func scheduleSave(_ canvasView: PKCanvasView) {
            saveWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self, weak canvasView] in
                guard let self, let canvasView else { return }
                let data = canvasView.drawing.dataRepresentation()
                self.lastWrittenData = data
                self.parent.onChange(data)
            }
            saveWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
        }
    }
}
