import Foundation
import SwiftData

/// SwiftData CRUD layer. All access to the @Model graph flows through here so
/// callers stay declarative and testable. Methods are synchronous and assume
/// the caller is on the main actor (matching SwiftData's recommended use of
/// the main-thread `ModelContext`).
@MainActor
struct AnnotationStore {

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Annotation layers

    /// Returns the layer for (kind, translation, book, chapter), creating it
    /// lazily on first request. Layers are conceptually always-present per
    /// the design doc, but we don't materialize them until annotation begins.
    func findOrCreateLayer(
        kind: LayerKind,
        translation: String,
        book: Book,
        chapter: Int
    ) -> AnnotationLayer {
        let kindRaw = kind.rawValue
        let bookRaw = book.rawValue
        let descriptor = FetchDescriptor<AnnotationLayer>(
            predicate: #Predicate { layer in
                layer.kindRaw == kindRaw
                    && layer.translation == translation
                    && layer.book == bookRaw
                    && layer.chapter == chapter
            }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let layer = AnnotationLayer(
            kind: kind,
            translation: translation,
            book: bookRaw,
            chapter: chapter
        )
        context.insert(layer)
        return layer
    }

    /// All layers across all kinds for a chapter — used when rendering
    /// chapter-grid indicator dots.
    func layers(translation: String, book: Book, chapter: Int) -> [AnnotationLayer] {
        let bookRaw = book.rawValue
        let descriptor = FetchDescriptor<AnnotationLayer>(
            predicate: #Predicate { layer in
                layer.translation == translation
                    && layer.book == bookRaw
                    && layer.chapter == chapter
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Wipe drawing strokes only — preserves highlights, notes, and headers.
    func clearDrawing(on layer: AnnotationLayer) {
        layer.pkDrawingData = Data()
    }

    // MARK: - Reading history

    private static let historyCap = 100

    /// Append a visit and trim the oldest beyond the per-translation cap.
    func recordVisit(translation: String, book: Book, chapter: Int) {
        let visit = ChapterVisit(
            translation: translation,
            book: book.rawValue,
            chapter: chapter
        )
        context.insert(visit)
        trimVisits(translation: translation)
    }

    func lastVisit(translation: String) -> ChapterVisit? {
        var descriptor = FetchDescriptor<ChapterVisit>(
            predicate: #Predicate { $0.translation == translation },
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func recentVisits(translation: String, limit: Int = Self.historyCap) -> [ChapterVisit] {
        var descriptor = FetchDescriptor<ChapterVisit>(
            predicate: #Predicate { $0.translation == translation },
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    private func trimVisits(translation: String) {
        let descriptor = FetchDescriptor<ChapterVisit>(
            predicate: #Predicate { $0.translation == translation },
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor), all.count > Self.historyCap else { return }
        for stale in all.dropFirst(Self.historyCap) {
            context.delete(stale)
        }
    }

    // MARK: - Persistence

    /// Force a save. SwiftData auto-saves on context changes, but explicit
    /// saves are useful at known commit points (chapter exit, drawing commit).
    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
