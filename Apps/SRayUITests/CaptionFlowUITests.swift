import UIKit
import XCTest

/// Exercises the public caption controls with an in-process synthetic recognizer.
@MainActor
final class CaptionFlowUITests: XCTestCase {
    /// Exercises the app wiring with its explicitly enabled local geometry fixture.
    func testSyntheticPoseCanPlayReplayAndClearOnEnd() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SRAY_SYNTHETIC_ASL"] = "1"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let start = app.buttons["caption.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        let enable = app.buttons["asl.demo.enable"]
        let sample = app.buttons["asl.demo.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        XCTAssertTrue(enable.isHittable)
        enable.tap()
        XCTAssertTrue(app.buttons["asl.demo.pause"].waitForExistence(timeout: 10))
        sample.tap()

        let replay = app.buttons["asl.demo.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 15))
        let caption = app.staticTexts["caption.latest"]
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
        XCTAssertEqual(caption.label, "Geometric sample caption.")

        app.buttons["asl.demo.pause"].tap()
        XCTAssertTrue(enable.waitForExistence(timeout: 10))
        XCTAssertEqual(enable.label, "Resume Demo")
        replay.tap()

        app.buttons["caption.end"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertFalse(caption.exists)
        XCTAssertFalse(replay.exists)
    }

    /// A failed local translation offers recovery and preserves the triggering caption.
    func testSyntheticFailureKeepsCaptionUntilExplicitResume() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SRAY_SYNTHETIC_ASL"] = "failure"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let start = app.buttons["caption.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let sample = app.buttons["asl.demo.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        app.buttons["asl.demo.enable"].tap()
        sample.tap()

        let status = app.staticTexts["asl.demo.status"]
        let caption = app.staticTexts["caption.latest"]
        let omission = app.staticTexts["asl.demo.omission"]
        XCTAssertTrue(omission.waitForExistence(timeout: 10))
        XCTAssertEqual(caption.label, "Geometric sample caption.")
        XCTAssertEqual(status.label, "Demo unavailable. Resume to try again.")
        XCTAssertEqual(omission.label, "Sample unavailable")
        XCTAssertFalse(app.buttons["asl.demo.replay"].exists)

        app.buttons["asl.demo.enable"].tap()
        XCTAssertEqual(status.label, "Demo active")
        XCTAssertTrue(caption.exists)
        XCTAssertTrue(omission.exists)
        XCTAssertFalse(app.buttons["asl.demo.replay"].exists)
    }

    /// Viewing the disclosure preserves the existing conversation and its captions.
    func testASLPrivacyDetailsReturnToTheActiveConversation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SRAY_SYNTHETIC_CAPTIONS"] = "1"
        app.launch()

        let start = app.buttons["caption.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let caption = app.staticTexts["caption.latest"]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        let details = app.buttons["asl.privacy.details"]
        XCTAssertTrue(details.isHittable)
        details.tap()

        let disclosure = app.staticTexts["asl.privacy.provider"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        XCTAssertTrue(disclosure.label.contains("Sign MT"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "ASL Privacy"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["asl.privacy.close"].tap()
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["caption.end"].exists)
    }

    /// Switching to pose-only presentation retains captions and restoring them pauses the demo.
    func testSyntheticOutputModePreservesHiddenCaptionsWithoutResuming() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SRAY_SYNTHETIC_ASL"] = "1"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let start = app.buttons["caption.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let sample = app.buttons["asl.demo.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        app.buttons["asl.demo.enable"].tap()

        let output = app.buttons["asl.demo.output"]
        output.tap()
        app.buttons["Pose Only"].tap()
        sample.tap()
        let replay = app.buttons["asl.demo.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 15))

        let caption = app.staticTexts["caption.latest"]
        XCTAssertFalse(caption.exists)
        output.tap()
        app.buttons["Captions Only"].tap()
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
        XCTAssertEqual(caption.label, "Geometric sample caption.")
        XCTAssertFalse(replay.exists)

        output.tap()
        app.buttons["Captions and Pose"].tap()
        XCTAssertTrue(app.buttons["asl.demo.enable"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["asl.demo.enable"].label, "Resume Demo")
        XCTAssertTrue(caption.exists)
        XCTAssertTrue(replay.exists)
    }

    /// An over-limit sample remains readable in full and produces no replay.
    func testSyntheticOverLimitCaptionStaysLocal() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SRAY_SYNTHETIC_ASL"] = "over-limit"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let start = app.buttons["caption.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let sample = app.buttons["asl.demo.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        app.buttons["asl.demo.enable"].tap()
        sample.tap()

        let limitation = app.staticTexts["asl.demo.omission"]
        XCTAssertTrue(limitation.waitForExistence(timeout: 10))
        XCTAssertEqual(limitation.label, "Sample exceeds the text limit")
        let caption = app.staticTexts["caption.latest"]
        XCTAssertEqual(caption.label, String(repeating: "Sample ", count: 39) + "Do not take the stairs.")
        XCTAssertFalse(app.buttons["asl.demo.replay"].exists)
    }

    /// The pause action stays reachable while reading captions below the demo panel.
    func testDemoPauseRemainsReachableAfterScrolling() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SRAY_SYNTHETIC_ASL"] = "over-limit"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        let start = app.buttons["caption.start"]
        XCTAssertTrue(start.wait(for: \.isHittable, toEqual: true, timeout: 10))
        start.tap()

        let enable = app.buttons["asl.demo.enable"]
        XCTAssertTrue(enable.waitForExistence(timeout: 10))
        enable.tap()
        let sample = app.buttons["asl.demo.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        sample.tap()

        let caption = app.staticTexts["caption.latest"]
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
        let pause = app.buttons["asl.demo.pause"]
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.buttons["asl.demo.output"].exists)
        XCTAssertFalse(scroll.buttons["asl.demo.pause"].exists)

        let live = app.staticTexts["caption.live"]
        let originalPosition = live.frame.minY
        let window = app.windows.firstMatch
        let readAreaBottom = app.buttons["Return to Live"].frame.minY
        let origin = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        let dragStart = origin.withOffset(CGVector(dx: 0, dy: readAreaBottom - 35))
        let dragEnd = origin.withOffset(CGVector(dx: 0, dy: readAreaBottom * 0.45))
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd)

        XCTAssertLessThan(live.frame.minY, originalPosition - 40)
        XCTAssertTrue(pause.isHittable)
        XCTAssertEqual(pause.label, "Pause Demo")
        pause.tap()
        XCTAssertTrue(caption.exists)
        XCTAssertTrue(enable.waitForExistence(timeout: 10))
        XCTAssertEqual(enable.label, "Resume Demo")
    }

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
        let caption = app.staticTexts["caption.latest"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        XCTAssertTrue(caption.waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        XCTAssertTrue(end.isHittable)
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        XCTAssertTrue(caption.exists)
        XCTAssertEqual(caption.label, "Take the elevator to the second floor.")
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

    /// Visiting the Home Screen clears the pose and the enabled window before an explicit restart.
    func testSyntheticPlaybackCannotResumeAfterBackground() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SRAY_SYNTHETIC_ASL"] = "1"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let start = app.buttons["caption.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let sample = app.buttons["asl.demo.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        app.buttons["asl.demo.enable"].tap()
        sample.tap()
        let replay = app.buttons["asl.demo.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 15))

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5) ||
                      app.state == .runningBackgroundSuspended)
        app.activate()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(start.wait(for: \.isHittable, toEqual: true, timeout: 10))
        let caption = app.staticTexts["caption.latest"]
        XCTAssertFalse(caption.exists)
        XCTAssertFalse(replay.exists)

        start.tap()
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["asl.demo.enable"].label, "Enable Demo")
        sample.tap()
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
        XCTAssertFalse(replay.exists)
        XCTAssertTrue(app.buttons["asl.demo.enable"].exists)
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
        let caption = app.staticTexts["caption.latest"]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5) ||
                      app.state == .runningBackgroundSuspended)
        app.activate()

        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.wait(for: \.isHittable, toEqual: true, timeout: 10))
        XCTAssertFalse(caption.exists)
        XCTAssertFalse(app.buttons["caption.end"].exists)
    }
}
