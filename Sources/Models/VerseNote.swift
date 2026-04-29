import Foundation
import SwiftData

/// A typed note OR custom section header anchored to a specific verse.
/// One model handles both because the lifecycle and anchor are identical;
/// `kind` controls rendering and behavior.
@Model
final class VerseNote {
    @Attribute(.unique) var id: UUID
    var verseId: Int
    var text: String
    var kindRaw: String
    var createdAt: Date
    var layer: AnnotationLayer?

    init(
        id: UUID = UUID(),
        verseId: Int,
        text: String,
        kind: NoteKind = .note,
        createdAt: Date = .now,
        layer: AnnotationLayer? = nil
    ) {
        self.id = id
        self.verseId = verseId
        self.text = text
        self.kindRaw = kind.rawValue
        self.createdAt = createdAt
        self.layer = layer
    }

    var kind: NoteKind {
        get { NoteKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }
}
