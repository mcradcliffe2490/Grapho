import Foundation
import SwiftData

/// One row per chapter view — used for "Continue Reading" and the History
/// view. The store caps total rows per translation at 100 (oldest dropped).
@Model
final class ChapterVisit {
    @Attribute(.unique) var id: UUID
    var translation: String
    var book: String
    var chapter: Int
    var visitedAt: Date

    init(
        id: UUID = UUID(),
        translation: String,
        book: String,
        chapter: Int,
        visitedAt: Date = .now
    ) {
        self.id = id
        self.translation = translation
        self.book = book
        self.chapter = chapter
        self.visitedAt = visitedAt
    }
}
