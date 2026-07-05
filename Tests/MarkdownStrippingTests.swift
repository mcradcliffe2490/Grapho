import XCTest
@testable import Grapho

final class MarkdownStrippingTests: XCTestCase {

    func test_headingMarkerRemoved() {
        XCTAssertEqual("## Lifted up".strippingMarkdown, "Lifted up")
        XCTAssertEqual("# One\n### Three".strippingMarkdown, "One\nThree")
    }

    func test_quoteAndListMarkersRemoved() {
        XCTAssertEqual("> a quote".strippingMarkdown, "a quote")
        XCTAssertEqual("- first\n- second".strippingMarkdown, "first\nsecond")
        XCTAssertEqual("1. numbered".strippingMarkdown, "numbered")
    }

    func test_inlineMarksRemoved_contentKept() {
        XCTAssertEqual("both **senses** at *once*".strippingMarkdown, "both senses at once")
        XCTAssertEqual("the verb is `hypsoo` here".strippingMarkdown, "the verb is hypsoo here")
        XCTAssertEqual("_from above_".strippingMarkdown, "from above")
    }

    func test_plainTextUntouched() {
        let plain = "Nicodemus hears only the first; Jesus means both."
        XCTAssertEqual(plain.strippingMarkdown, plain)
    }

    func test_midWordUnderscoresAndAsterisksSurvive() {
        // snake_case and math shouldn't be eaten by the italic rules.
        XCTAssertEqual("verse_id stays verse_id".strippingMarkdown, "verse_id stays verse_id")
    }
}
