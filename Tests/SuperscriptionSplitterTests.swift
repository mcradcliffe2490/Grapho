import XCTest
@testable import Grapho

final class SuperscriptionSplitterTests: XCTestCase {

    func test_singleSentenceInscription_splitsCleanly() {
        let input = "A Psalm by David. Yahweh is my shepherd; I shall lack nothing."
        let result = SuperscriptionSplitter.split(verseOneText: input)
        XCTAssertEqual(result.superscription, "A Psalm by David.")
        XCTAssertEqual(result.verseText, "Yahweh is my shepherd; I shall lack nothing.")
    }

    func test_multiPartInscription_consumesAllInscriptionSentences() {
        let input = "For the Chief Musician; on stringed instruments. A Psalm by David. Answer me when I call, God of my righteousness."
        let result = SuperscriptionSplitter.split(verseOneText: input)
        XCTAssertEqual(
            result.superscription,
            "For the Chief Musician; on stringed instruments. A Psalm by David."
        )
        XCTAssertEqual(result.verseText, "Answer me when I call, God of my righteousness.")
    }

    func test_inscriptionWithEmbeddedQuote_doesNotMisSplitOnQuotedPeriod() {
        // Psalm 9 in WEB: 'For the Chief Musician. Set to "The Death of the Son." A Psalm by David. I will give thanks to Yahweh with my whole heart.'
        let input = "For the Chief Musician. Set to \"The Death of the Son.\" A Psalm by David. I will give thanks to Yahweh with my whole heart."
        let result = SuperscriptionSplitter.split(verseOneText: input)
        XCTAssertEqual(
            result.superscription,
            "For the Chief Musician. Set to \"The Death of the Son.\" A Psalm by David."
        )
        XCTAssertEqual(result.verseText, "I will give thanks to Yahweh with my whole heart.")
    }

    func test_psalmWithoutInscription_returnsNilSuperscription() {
        // Psalm 1 has no inscription; verse 1 IS verse text.
        let input = "Blessed is the man who doesn't walk in the counsel of the wicked, nor stand on the path of sinners, nor sit in the seat of scoffers;"
        let result = SuperscriptionSplitter.split(verseOneText: input)
        XCTAssertNil(result.superscription)
        XCTAssertEqual(result.verseText, input)
    }

    func test_byDavidInscription_splits() {
        let input = "By David. To you, Yahweh, I lift up my soul."
        let result = SuperscriptionSplitter.split(verseOneText: input)
        XCTAssertEqual(result.superscription, "By David.")
        XCTAssertEqual(result.verseText, "To you, Yahweh, I lift up my soul.")
    }

    func test_sonsOfKorahInscription_splits() {
        let input = "For the Chief Musician. By the sons of Korah. As the deer pants for the water brooks."
        let result = SuperscriptionSplitter.split(verseOneText: input)
        XCTAssertEqual(
            result.superscription,
            "For the Chief Musician. By the sons of Korah."
        )
        XCTAssertEqual(result.verseText, "As the deer pants for the water brooks.")
    }

    func test_emptyString_returnsNoSuperscription() {
        let result = SuperscriptionSplitter.split(verseOneText: "")
        XCTAssertNil(result.superscription)
        XCTAssertEqual(result.verseText, "")
    }

    func test_singleSentenceNoInscription_passesThrough() {
        let input = "Why do the nations rage, and the peoples plot a vain thing?"
        let result = SuperscriptionSplitter.split(verseOneText: input)
        XCTAssertNil(result.superscription)
        XCTAssertEqual(result.verseText, input)
    }
}
