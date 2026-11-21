# Simulator caption accessibility checks

The `SRay-iOS` scheme includes XCUITest cases that use a fixed synthetic caption source in Debug builds. The tests exercise the production view and caption session. The fixture never requests microphone access and never contacts a translation provider.

Run the suite on an installed iPhone or iPad simulator.

```sh
xcrun simctl list devices available
xcodebuild -project SRay.xcodeproj -scheme SRay-iOS \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -derivedDataPath /tmp/sray-ui-tests -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

The largest-text case checks that Start is reachable, rotates an active conversation, confirms the caption remains visible in the accessibility tree, and ends the session. The iPad case checks that a wide window lays out the status and caption in separate columns and that Shift–Command–E ends and clears the session. The iPad-only case skips on iPhone.

All three cases passed on an iPad Pro 11-inch M5 simulator on iOS 27.0. The rotation case also passed on iPhone 18 Pro with the same runtime. The background check uses Home and then reactivates the existing app. It verifies the synthetic caption is cleared and the controls require a fresh start. Apple CI runs these checks on both iOS device families, separately from the package and device SDK builds.

Issue #22 remains open for measuring contrast and testing VoiceOver, Switch Control, Reduce Motion, Reduce Transparency, pointer and gaze/pinch on devices. Repeat the complete conversation flow once playback and the ASL controls are available.

Enable Reduce Transparency in system Accessibility settings. Verify the conversation background and the start and end control areas use a solid surface in both light and dark appearance. Repeat with the largest caption text size and with the local pose demo. Check that controls remain legible above the transcript and that signing motion remains available. Document device, OS, appearance and measured contrast when recording physical evidence.
