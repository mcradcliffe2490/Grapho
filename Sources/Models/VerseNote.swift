import Foundation
import SwiftData

/// A typed note OR custom section header anchored to a chapter. One model
/// covers both because they share lifecycle and ownership; `kind` controls
/// rendering and behavior.
///
/// `verseId` is optional: a free-form note may apply to the whole chapter
/// rather than a specific verse. Section-header notes always have a verse
/// anchor (the verse the header introduces).
///
/// `title` is user-authored display name shown in the notes drawer; empty
/// string means the drawer falls back to the first line of `text`.
@Model
final class VerseNote {
    @Attribute(.unique) var id: UUID
    /// Verse number this note anchors to. `nil` for chapter-scoped notes.
    var verseId: Int?
    var title: String = ""
    var text: String
    var kindRaw: String
    var createdAt: Date
    var updatedAt: Date = Date.now
    var layer: AnnotationLayer?

    init(
        id: UUID = UUID(),
        verseId: Int? = nil,
        title: String = "",
        text: String,
        kind: NoteKind = .note,
        createdAt: Date = .now,
        layer: AnnotationLayer? = nil
    ) {
        self.id = id
        self.verseId = verseId
        self.title = title
        self.text = text
        self.kindRaw = kind.rawValue
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.layer = layer
    }

    var kind: NoteKind {
        get { NoteKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    /// What to show as the title in a notes list. Falls back to the first
    /// line of body text, or "Untitled" if both are empty.
    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }
        let firstLine = text
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !firstLine.isEmpty { return firstLine.strippingMarkdown }
        return "Untitled"
    }

    /// Fully-qualified address of this note's verse anchor — `nil` for
    /// chapter-scoped notes or if the stored book code doesn't resolve.
    var anchorRef: VerseRef? {
        guard let layer,
              let book = Book(rawValue: layer.book),
              let verse = verseId
        else { return nil }
        return VerseRef(book: book, chapter: layer.chapter, verse: verse)
    }

    /// Body text when present, else the display title — what compact
    /// previews (margin cards, linked mentions) show. Markdown syntax is
    /// stripped: previews render plain, only the editor shows source.
    var previewContent: String {
        text.isEmpty ? displayTitle : text.strippingMarkdown
    }

    /// Preview line for the drawer. Skips the first text line if it was used
    /// as the title fallback.
    var previewSnippet: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !trimmedTitle.isEmpty {
            return (lines.first ?? "").strippingMarkdown
        }
        // Title was implicit (first line) — preview is the second line.
        return (lines.dropFirst().first ?? "").strippingMarkdown
    }
}

extension String {
    /// Removes markdown syntax for one-line/compact previews: heading,
    /// quote, and list markers at line starts, plus inline bold/italic/code
    /// marks. Display-only — stored note text is never touched.
    var strippingMarkdown: String {
        let patterns: [(String, String)] = [
            (#"(?m)^#{1,3}[ \t]+"#, ""),
            (#"(?m)^>[ \t]?"#, ""),
            (#"(?m)^[ \t]*([-*+]|\d+\.)[ \t]"#, ""),
            (#"\*\*([^\*\n]+)\*\*"#, "$1"),
            (#"(?<![\*\w])\*([^\*\n]+)\*(?!\*)"#, "$1"),
            (#"(?<!\w)_([^_\n]+)_(?!\w)"#, "$1"),
            (#"`([^`\n]+)`"#, "$1")
        ]
        return patterns.reduce(self) { result, rule in
            result.replacingOccurrences(of: rule.0, with: rule.1, options: .regularExpression)
        }
    }
}
