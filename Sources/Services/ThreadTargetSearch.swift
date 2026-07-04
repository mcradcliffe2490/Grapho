import Foundation

/// Finds candidate verses for the "thread to…" picker (design turn 8a):
/// typed references parse directly, and an empty/partial query falls back to
/// suggestions that share significant words with the source verse. Pure and
/// dependency-free so it's unit-testable like the other logic services.
struct ThreadTargetSearch {
    let translation: BibleTranslation

    struct Candidate: Hashable, Identifiable {
        let ref: VerseRef
        let text: String

        var id: VerseRef { ref }

        /// Short trailing context for the picker row ("the bronze serpent…").
        var snippet: String {
            text.count <= 60 ? text : String(text.prefix(57)) + "…"
        }
    }

    // MARK: - Reference parsing

    /// Parses "John 3:16", "1 Cor 13:4", "jhn 3 16", "Psalm 23:1" — a book
    /// name/abbreviation prefix followed by chapter and verse numbers. Returns
    /// `nil` when the text doesn't resolve to a real verse in this translation.
    func parseReference(_ query: String) -> Candidate? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        // Split trailing "chapter:verse" (or "chapter verse") off the book part.
        let pattern = #/^(.+?)[\s.]+(\d+)[:\s.](\d+)$/#
        guard let match = trimmed.firstMatch(of: pattern),
              let chapter = Int(match.2), let verse = Int(match.3),
              let book = matchBook(String(match.1))
        else { return nil }
        guard let text = translation.chapter(book: book, number: chapter)?.verse(verse)?.text
        else { return nil }
        return Candidate(ref: VerseRef(book: book, chapter: chapter, verse: verse), text: text)
    }

    /// Case-insensitive match against display names ("John", "1 Samuel") and
    /// USFM abbreviations ("JHN", "1SA"), accepting unambiguous prefixes of
    /// display names ("Gen", "Num") so partial typing still resolves.
    private func matchBook(_ raw: String) -> Book? {
        let name = raw.lowercased().trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        if let exact = Book.allCases.first(where: {
            $0.displayName.lowercased() == name || $0.rawValue.lowercased() == name
        }) {
            return exact
        }
        let prefixMatches = Book.allCases.filter { $0.displayName.lowercased().hasPrefix(name) }
        return prefixMatches.count == 1 ? prefixMatches.first : nil
    }

    // MARK: - Shared-word suggestions

    /// Words too common to signal a real connection. Curated, not exhaustive —
    /// length ≥ 5 filtering below does most of the work.
    private static let stopWords: Set<String> = [
        "shall", "which", "there", "their", "these", "those", "because",
        "before", "after", "would", "could", "should", "against", "through",
        "saying", "said", "unto", "therefore", "again", "answered", "certainly"
    ]

    /// Verses elsewhere in the translation sharing significant words with the
    /// source verse — "SUGGESTED · SHARED WORDS" in the picker. Scans the whole
    /// translation in memory; call off the main actor.
    func suggestions(for source: VerseRef, limit: Int = 4) -> [Candidate] {
        guard let sourceText = translation.chapter(book: source.book, number: source.chapter)?
            .verse(source.verse)?.text
        else { return [] }
        let keywords = significantWords(in: sourceText)
        guard !keywords.isEmpty else { return [] }

        var scored: [(candidate: Candidate, score: Int)] = []
        for book in translation.orderedBooks {
            for chapter in book.orderedChapters {
                for verse in chapter.verses {
                    let ref = VerseRef(book: book.book, chapter: chapter.number, verse: verse.number)
                    if ref == source { continue }
                    let shared = significantWords(in: verse.text).intersection(keywords)
                    if shared.count >= 2 {
                        scored.append((Candidate(ref: ref, text: verse.text), shared.count))
                    }
                }
            }
        }
        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.candidate)
    }

    private func significantWords(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 5 && !Self.stopWords.contains($0) }
        )
    }
}
