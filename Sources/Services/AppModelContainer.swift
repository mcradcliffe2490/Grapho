import Foundation
import SwiftData

/// Single owner of the SwiftData container. `shared` is the on-disk store used
/// by the running app; `preview` is in-memory for SwiftUI previews and tests.
@MainActor
final class AppModelContainer {
    let container: ModelContainer

    static let shared: AppModelContainer = {
        do {
            return try AppModelContainer(inMemory: false)
        } catch {
            // SwiftData failure at startup is unrecoverable — surface the
            // underlying error so the user gets actionable diagnostics rather
            // than a silent crash.
            fatalError("Failed to initialize SwiftData store: \(error)")
        }
    }()

    static let preview: AppModelContainer = {
        do {
            return try AppModelContainer(inMemory: true)
        } catch {
            fatalError("Failed to initialize preview SwiftData store: \(error)")
        }
    }()

    private init(inMemory: Bool) throws {
        let schema = Schema([
            AnnotationLayer.self,
            Highlight.self,
            VerseNote.self,
            ChapterVisit.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        self.container = try ModelContainer(for: schema, configurations: [configuration])
    }
}
