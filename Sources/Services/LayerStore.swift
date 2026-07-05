import Foundation
import Observation

/// Holds the currently-active annotation layer for the reader. Lifted out of
/// any single view because three sibling views need to read it (the toolbar
/// switcher, the canvas, and the verse layer-indicator badge) and exactly one
/// needs to write it. Persisted to `UserDefaults` so the user's last choice
/// survives launches.
@Observable
@MainActor
final class LayerStore {
    var active: LayerKind {
        didSet {
            UserDefaults.standard.set(active.rawValue, forKey: PreferenceKey.activeLayerKind)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: PreferenceKey.activeLayerKind)
        self.active = LayerKind(rawValue: raw ?? "") ?? .exegetical
    }
}
