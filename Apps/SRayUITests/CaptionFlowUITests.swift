import UIKit
import XCTest

/// Exercises the public caption controls with an in-process synthetic recognizer.
@MainActor
final class CaptionFlowUITests: XCTestCase {
    /// The same local conversation and its controls survive a rotation at the largest text size.
    func testCaptionConversationSurvivesRotationAtLargestTextSize() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }

        let app = XCUIApplication()
        app.launchEnvironment["SRAY_SYNTHETIC_CAPTIONS"] = "1"
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let start = app.buttons["caption.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        XCTAssertEqual(start.label, "Start Captions")
        start.tap()

        let end = app.buttons["caption.end"]
        let caption = app.staticTexts["Take the elevator to the second floor."]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        XCTAssertTrue(caption.waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        XCTAssertTrue(end.isHittable)
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        XCTAssertTrue(caption.exists)
        end.tap()

        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        XCTAssertFalse(caption.exists)
    }

    /// A wide iPad window separates status and transcript and supports keyboard ending.
    func testWideIPadLayoutAndKeyboardEnd() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        let app = XCUIApplication()
        app.launchEnvironment["SRAY_SYNTHETIC_CAPTIONS"] = "1"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let start = app.buttons["caption.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let status = app.staticTexts["caption.status"]
        let live = app.staticTexts["caption.live"]
        XCTAssertTrue(live.waitForExistence(timeout: 5))
        XCTAssertTrue(status.exists)
        XCTAssertGreaterThan(live.frame.minX, status.frame.maxX)

        app.typeKey("e", modifierFlags: [.command, .shift])
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(live.exists)
    }

    /// Returning from the Home Screen requires a new conversation and clears previous captions.
    func testBackgroundClearsCaptionAndRequiresExplicitRestart() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SRAY_SYNTHETIC_CAPTIONS"] = "1"
        app.launch()

        let start = app.buttons["caption.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let caption = app.staticTexts["Take the elevator to the second floor."]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5) ||
                      app.state == .runningBackgroundSuspended)
        app.activate()

        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        XCTAssertFalse(caption.exists)
        XCTAssertFalse(app.buttons["caption.end"].exists)
    }
}
