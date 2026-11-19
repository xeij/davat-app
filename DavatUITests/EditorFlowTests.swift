import XCTest

/// Tap-through: + opens the picker, a template opens the editor, Done closes both and Home lists the invite.
/// Expects a signed-in simulator (LocalBackend session).
final class EditorFlowTests: XCTestCase {
    @MainActor func testTemplateDoneSavesToHome() {
        let app = XCUIApplication()
        app.launch()
        let untitled = app.buttons.matching(NSPredicate(format: "label == 'untitled'"))
        XCTAssertTrue(app.buttons["New invite"].waitForExistence(timeout: 10))
        let before = untitled.count

        app.buttons["New invite"].tap()
        let template = app.buttons["template.disco birthday"]
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: template)
        waitForExpectations(timeout: 5)
        template.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        XCTAssertTrue(app.buttons["New invite"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["start with"].exists, "template picker should be dismissed")
        let deadline = Date().addingTimeInterval(5)
        while untitled.count <= before, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertEqual(untitled.count, before + 1)

        untitled.firstMatch.tap()   // a saved invite reopens in the editor
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["New invite"].waitForExistence(timeout: 5))
    }
}
