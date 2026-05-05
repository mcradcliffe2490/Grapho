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

    // MARK: - Highlights

    /// Whole-verse highlight semantics for v1: `startOffset = 0`, `endOffset = -1`
    /// (sentinel for "to end of verse"). Sub-string highlighting is post-MVP.
    static let wholeVerseSentinel = -1

    /// Upsert: if a highlight already exists for this verse on this layer,
    /// update its color; otherwise insert a new one.
    func setHighlight(verseNumber: Int, color: HighlightColor, on layer: AnnotationLayer) {
        if let existing = layer.highlights.first(where: { $0.verseId == verseNumber }) {
            existing.color = color
        } else {
            let highlight = Highlight(
                verseId: verseNumber,
                startOffset: 0,
                endOffset: Self.wholeVerseSentinel,
                color: color,
                layer: layer
            )
            context.insert(highlight)
            layer.highlights.append(highlight)
        }
    }

    func clearHighlight(verseNumber: Int, on layer: AnnotationLayer) {
        let toRemove = layer.highlights.filter { $0.verseId == verseNumber }
        for h in toRemove {
            context.delete(h)
        }
    }

    // MARK: - Notes & section headers

    /// Free-form note. `verseNumber` is optional — a `nil` anchor means the
    /// note applies to the whole chapter rather than a specific verse.
    @discardableResult
    func addNote(
        verseNumber: Int? = nil,
        title: String = "",
        text: String,
        on layer: AnnotationLayer
    ) -> VerseNote {
        let note = VerseNote(
            verseId: verseNumber,
            title: title,
            text: text,
            kind: .note,
            layer: layer
        )
        context.insert(note)
        layer.notes.append(note)
        return note
    }

    /// Update an existing note's title/text and bump `updatedAt`.
    func updateNote(_ note: VerseNote, title: String? = nil, text: String? = nil, verseId: Int? = nil) {
        if let title { note.title = title }
        if let text { note.text = text }
        // Caller passes `nil` for verseId to mean "keep current"; to clear an
        // anchor, use `clearNoteAnchor` below.
        if let verseId { note.verseId = verseId }
        note.updatedAt = .now
    }

    func clearNoteAnchor(_ note: VerseNote) {
        note.verseId = nil
        note.updatedAt = .now
    }

    /// User-authored section header rendered above the given verse.
    @discardableResult
    func setSectionHeader(beforeVerse verseNumber: Int, text: String, on layer: AnnotationLayer) -> VerseNote {
        // One header per verse-anchor: replace if an existing header anchors
        // to the same verse on the same layer.
        if let existing = layer.notes.first(where: {
            $0.verseId == verseNumber && $0.kindRaw == NoteKind.sectionHeader.rawValue
        }) {
            existing.text = text
            existing.updatedAt = .now
            return existing
        }
        let header = VerseNote(verseId: verseNumber, text: text, kind: .sectionHeader, layer: layer)
        context.insert(header)
        layer.notes.append(header)
        return header
    }

    func deleteNote(_ note: VerseNote) {
        context.delete(note)
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
