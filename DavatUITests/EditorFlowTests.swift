import XCTest

/// Tap-through: + opens the picker, a template opens the editor, Done goes to details, Publish lands on the
/// invite's detail screen, which can reopen the editor and delete the invite.
/// Expects a signed-in simulator (LocalBackend session).
final class EditorFlowTests: XCTestCase {
    @MainActor func testNewInvitePublishesToDetail() {
        let app = XCUIApplication()
        app.launch()
        let title = "ui test \(Int(Date().timeIntervalSince1970))"
        XCTAssertTrue(app.buttons["New invite"].waitForExistence(timeout: 10))

        app.buttons["New invite"].tap()
        let template = app.buttons["template.disco birthday"]
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: template)
        waitForExpectations(timeout: 5)
        template.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        let field = app.textFields["title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Publish"].isEnabled, "publish needs a title")
        field.tap()
        field.typeText(title)
        app.buttons["Publish"].tap()

        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertFalse(app.staticTexts["start with"].exists, "template picker should be dismissed")

        app.buttons["More"].tap()
        app.buttons["Edit design"].tap()   // a published invite reopens in the editor
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 5))

        app.buttons["More"].tap()
        app.buttons["Delete"].tap()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.buttons["New invite"].waitForExistence(timeout: 5))
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.buttons[title])
        waitForExpectations(timeout: 5)
    }
}
