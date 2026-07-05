import XCTest
@testable import Grapho

final class ChapterNavigatorTests: XCTestCase {

    // Synthetic translation: Genesis 1-3, Exodus 1-2, Matthew 1, Revelation 1.
    // Sparse on purpose so we exercise book-rollover with gaps.
    private func makeTranslation() -> BibleTranslation {
        func chapter(_ book: Book, _ n: Int) -> BibleChapter {
            BibleChapter(book: book, number: n, verses: [BibleVerse(number: 1, text: "x")], superscription: nil)
        }
        let genesis = BibleBook(book: .GEN, chapters: [
            1: chapter(.GEN, 1), 2: chapter(.GEN, 2), 3: chapter(.GEN, 3)
        ])
        let exodus = BibleBook(book: .EXO, chapters: [
            1: chapter(.EXO, 1), 2: chapter(.EXO, 2)
        ])
        let matthew = BibleBook(book: .MAT, chapters: [1: chapter(.MAT, 1)])
        let revelation = BibleBook(book: .REV, chapters: [1: chapter(.REV, 1)])
        return BibleTranslation(
            identifier: "test",
            displayName: "Test",
            books: [.GEN: genesis, .EXO: exodus, .MAT: matthew, .REV: revelation]
        )
    }

    func test_next_withinSameBook() {
        let nav = ChapterNavigator(translation: makeTranslation())
        let next = nav.next(after: ChapterRoute(book: .GEN, chapter: 1))
        XCTAssertEqual(next, ChapterRoute(book: .GEN, chapter: 2))
    }

    func test_next_rollsOverToNextAvailableBook_skippingMissing() {
        let nav = ChapterNavigator(translation: makeTranslation())
        // Exodus is the last available OT book in the synthetic translation;
        // next should skip over Leviticus..Malachi and land on Matthew 1.
        let next = nav.next(after: ChapterRoute(book: .EXO, chapter: 2))
        XCTAssertEqual(next, ChapterRoute(book: .MAT, chapter: 1))
    }

    func test_next_atEndOfCanon_returnsNil() {
        let nav = ChapterNavigator(translation: makeTranslation())
        XCTAssertNil(nav.next(after: ChapterRoute(book: .REV, chapter: 1)))
    }

    func test_previous_withinSameBook() {
        let nav = ChapterNavigator(translation: makeTranslation())
        let prev = nav.previous(before: ChapterRoute(book: .GEN, chapter: 3))
        XCTAssertEqual(prev, ChapterRoute(book: .GEN, chapter: 2))
    }

    func test_previous_rollsBackOverMissingBooks() {
        let nav = ChapterNavigator(translation: makeTranslation())
        // Matthew 1 ← previous should walk back over the empty-NT/OT slots
        // between Exodus and Matthew and land on Exodus 2.
        let prev = nav.previous(before: ChapterRoute(book: .MAT, chapter: 1))
        XCTAssertEqual(prev, ChapterRoute(book: .EXO, chapter: 2))
    }

    func test_previous_atStartOfCanon_returnsNil() {
        let nav = ChapterNavigator(translation: makeTranslation())
        XCTAssertNil(nav.previous(before: ChapterRoute(book: .GEN, chapter: 1)))
    }
}
