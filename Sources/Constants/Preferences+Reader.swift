import SwiftUI

/// Tiny wrappers that turn the raw `@AppStorage` strings into typed enum
/// values inside views. Lifted to one place so every view that needs the
/// active palette / header mode reads from the same shape.
extension BackgroundPalette {
    /// Resolve the user's choice from `UserDefaults`, defaulting to `.offWhite`
    /// if unset or unrecognized. Use the `@AppStorage` wrapper inside views
    /// for reactivity; this is the parsing helper.
    static func current(rawValue: String) -> BackgroundPalette {
        BackgroundPalette(rawValue: rawValue) ?? .default
    }
}

extension HeaderMode {
    static func current(rawValue: String) -> HeaderMode {
        HeaderMode(rawValue: rawValue) ?? .custom
    }
}
