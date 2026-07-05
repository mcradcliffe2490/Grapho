import XCTest

/// Drives the app through its main surfaces and attaches a screenshot at
/// each stop. Not an assertion suite — a visual-verification tour whose
/// attachments get exported after a run:
///
///   xcodebuild test -scheme Grapho -only-testing:GraphoUITests \
///       -resultBundlePath tour.xcresult
///   xcrun xcresulttool export attachments --path tour.xcresult --output-path shots/
final class ScreenshotTourTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches the app, walks past the first-run chooser if it appears
    /// (simulator clones can start with fresh defaults), then forces the
    /// requested reading practice through Settings so the test is
    /// deterministic regardless of persisted state. Note: argument-domain
    /// UserDefaults overrides don't reach `@AppStorage` Bools, so it's all
    /// done through the UI.
    @MainActor
    private func launchApp(readingMode: String = "Read & Study") -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let begin = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Begin'")).firstMatch
        if begin.waitForExistence(timeout: 5) {
            begin.tap()
        }
        _ = app.buttons["Settings"].waitForExistence(timeout: 10)
        app.buttons["Settings"].tap()
        let modeRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", readingMode)
        ).firstMatch
        _ = modeRow.waitForExistence(timeout: 5)
        modeRow.tap()
        app.navigationBars.buttons.firstMatch.tap() // back to Home
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func openJohn3(_ app: XCUIApplication) {
        // Book rows and chapter tiles are NavigationLinks — buttons to XCUI.
        _ = app.buttons["John"].firstMatch.waitForExistence(timeout: 10)
        app.buttons["John"].firstMatch.tap()
        _ = app.buttons["3"].firstMatch.waitForExistence(timeout: 5)
        app.buttons["3"].firstMatch.tap()
        // Verse 1 confirms the chapter rendered.
        _ = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Nicodemus'")
        ).firstMatch.waitForExistence(timeout: 5)
    }

    @MainActor
    func test_practiceChooser() {
        let app = XCUIApplication()
        app.launch()
        // The chooser only appears while `hasChosenPractice` is still false
        // on this simulator (clones can persist state between runs).
        let begin = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Begin'")).firstMatch
        if begin.waitForExistence(timeout: 5) {
            shot(app, "01-practice-chooser")
            begin.tap()
        }
        _ = app.buttons["John"].firstMatch.waitForExistence(timeout: 10)
        shot(app, "02-home")
    }

    @MainActor
    func test_readerAndThreads() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        openJohn3(app)
        shot(app, "03-lectio-reader")

        // Verse 14 → action menu.
        let verse14 = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Moses lifted up the serpent'")
        ).firstMatch
        verse14.tap()
        _ = app.buttons["Thread…"].waitForExistence(timeout: 3)
        shot(app, "04-verse-action-menu")

        // Thread picker with suggestions.
        app.buttons["Thread…"].tap()
        _ = app.textFields.firstMatch.waitForExistence(timeout: 3)
        shot(app, "05-thread-picker")

        // Type an exact reference and take the parsed row.
        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("Numbers 21:9")
        let candidate = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Numbers 21:9'")
        ).firstMatch
        if candidate.waitForExistence(timeout: 3) {
            candidate.tap()
            _ = app.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH 'THREADED'")
            ).firstMatch.waitForExistence(timeout: 3)
            shot(app, "06-thread-why")
            app.buttons["Done"].tap()
        }
        shot(app, "07-reader-with-thread-loop")
    }

    @MainActor
    func test_scholarSplit() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launchApp()
        openJohn3(app)
        shot(app, "08-scholar-reflow-split")
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func test_paperMode() {
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp(readingMode: "Paper")
        openJohn3(app)
        _ = app.staticTexts["PAPER"].waitForExistence(timeout: 5)
        shot(app, "09-paper-mode")
    }

    @MainActor
    func test_notesBrowser() {
        let app = launchApp()
        openJohn3(app)
        app.buttons["Library"].firstMatch.tap()
        _ = app.staticTexts["Notes"].firstMatch.waitForExistence(timeout: 3)
        app.staticTexts["Notes"].firstMatch.tap()
        sleep(1)
        shot(app, "10-notes-browser")

        // New note → type live markdown into the body editor.
        app.buttons["New note"].firstMatch.tap()
        let body = app.textViews.firstMatch
        guard body.waitForExistence(timeout: 3) else { return }
        body.tap()
        body.typeText("## Born anew\nThe verb carries **two senses** at *once*.\n> unless one is born anew\n- again, temporal\n- from above, spatial")
        shot(app, "11-markdown-editor")
    }
}
