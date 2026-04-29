import SwiftUI
import PencilKit

/// SwiftUI wrapper around `PKCanvasView`. Loads serialized `PKDrawing` data
/// in, calls `onChange` with new data after a short debounce, and switches
/// between pencil-only and finger-allowed input based on user preference.
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
    let onChange: (Data) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.alwaysBounceVertical = true
        canvas.alwaysBounceHorizontal = false

        if let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }

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

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Update policy if the user toggled the pref while the view is alive.
        let desired: PKCanvasViewDrawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        if canvas.drawingPolicy != desired {
            canvas.drawingPolicy = desired
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
