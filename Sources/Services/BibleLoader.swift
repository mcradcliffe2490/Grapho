import Foundation

enum BibleLoaderError: LocalizedError {
    case bundledResourceMissing
    case fileNotFound(URL)
    case invalidJSON(underlying: Error)
    case unexpectedShape(detail: String)
    case empty

    var errorDescription: String? {
        switch self {
        case .bundledResourceMissing:
            return "Bundled WEB Bible could not be found inside the app."
        case .fileNotFound(let url):
            return "Translation file not found at \(url.lastPathComponent)."
        case .invalidJSON(let underlying):
            return "Translation file is not valid JSON: \(underlying.localizedDescription)"
        case .unexpectedShape(let detail):
            return "Translation file does not match the expected format. \(detail)"
        case .empty:
            return "Translation file contained no recognizable books."
        }
    }
}

/// Parses Bible JSON in the flat public-domain format and returns an
/// in-memory `BibleTranslation`.
///
/// Expected format:
/// ```
/// { "Genesis": { "1": { "1": "In the beginning…", "2": "…" } } }
/// ```
/// Top-level keys are full English book names (matched case-insensitively
/// against `Book.from(displayName:)`). Books not in the canonical 66 are
/// silently skipped — apocrypha or extra material won't break parsing.
struct BibleLoader {

    /// Identifier used for the bundled translation. Stable across app
    /// versions so existing annotations remain attached.
    static let bundledIdentifier = "web"
    /// Filename of the bundled translation in the app resources.
    static let bundledResourceName = "web-bible"
    static let bundledDisplayName = "World English Bible"

    // MARK: - Public entry points

    /// Loads the WEB shipped inside the app bundle.
    func loadBundled() throws -> BibleTranslation {
        guard let url = Bundle.main.url(forResource: Self.bundledResourceName, withExtension: "json") else {
            throw BibleLoaderError.bundledResourceMissing
        }
        return try parse(
            url: url,
            identifier: Self.bundledIdentifier,
            displayName: Self.bundledDisplayName
        )
    }

    /// Loads an imported translation from disk. The caller is responsible for
    /// having copied the file into the app's Documents directory; the
    /// `TranslationImporter` does that work.
    func loadImported(at url: URL, identifier: String, displayName: String) throws -> BibleTranslation {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw BibleLoaderError.fileNotFound(url)
        }
        return try parse(url: url, identifier: identifier, displayName: displayName)
    }

    // MARK: - Parsing

    private func parse(url: URL, identifier: String, displayName: String) throws -> BibleTranslation {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BibleLoaderError.fileNotFound(url)
        }

        let raw: [String: [String: [String: String]]]
        do {
            raw = try JSONDecoder().decode([String: [String: [String: String]]].self, from: data)
        } catch {
            throw BibleLoaderError.invalidJSON(underlying: error)
        }

        var books: [Book: BibleBook] = [:]
        for (bookName, chaptersRaw) in raw {
            guard let book = Book.from(displayName: bookName) else { continue }
            let bibleBook = parseBook(book, chaptersRaw: chaptersRaw)
            guard !bibleBook.chapters.isEmpty else { continue }
            books[book] = bibleBook
        }

        guard !books.isEmpty else { throw BibleLoaderError.empty }

        return BibleTranslation(identifier: identifier, displayName: displayName, books: books)
    }

    private func parseBook(_ book: Book, chaptersRaw: [String: [String: String]]) -> BibleBook {
        var chapters: [Int: BibleChapter] = [:]
        for (chapterKey, versesRaw) in chaptersRaw {
            guard let chapterNumber = Int(chapterKey), chapterNumber > 0 else { continue }
            let chapter = parseChapter(book: book, number: chapterNumber, versesRaw: versesRaw)
            guard !chapter.verses.isEmpty else { continue }
            chapters[chapterNumber] = chapter
        }
        return BibleBook(book: book, chapters: chapters)
    }

    private func parseChapter(book: Book, number: Int, versesRaw: [String: String]) -> BibleChapter {
        // Sort verses by numeric value so reads don't have to re-sort.
        let sorted = versesRaw
            .compactMap { (key, value) -> (Int, String)? in
                guard let n = Int(key), n > 0 else { return nil }
                return (n, value)
            }
            .sorted { $0.0 < $1.0 }

        var verses = sorted.map { BibleVerse(number: $0.0, text: $0.1) }
        var superscription: String?

        if book.hasSuperscriptions, let firstIndex = verses.firstIndex(where: { $0.number == 1 }) {
            let original = verses[firstIndex].text
            let split = SuperscriptionSplitter.split(verseOneText: original)
            if let inscription = split.superscription {
                superscription = inscription
                verses[firstIndex] = BibleVerse(number: 1, text: split.verseText)
            }
        }

        return BibleChapter(
            book: book,
            number: number,
            verses: verses,
            superscription: superscription
        )
    }
}
