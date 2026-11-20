# Simulator caption accessibility checks

The `SRay-iOS` scheme includes two XCUITest cases that use a fixed synthetic caption source in Debug builds. The tests exercise the production view and caption session. The fixture never requests microphone access and never contacts a translation provider.

Run the suite on an installed iPhone or iPad simulator.

```sh
xcrun simctl list devices available
xcodebuild -project SRay.xcodeproj -scheme SRay-iOS \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -derivedDataPath /tmp/sray-ui-tests -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

The largest-text case checks that Start is reachable, rotates an active conversation, confirms the caption remains visible in the accessibility tree, and ends the session. The iPad case checks that a wide window lays out the status and caption in separate columns and that Shift–Command–E ends and clears the session. The iPad-only case skips on iPhone.

Both cases passed on an iPad Pro 11-inch M5 simulator on iOS 27.0, and the rotation case passed on iPhone 18 Pro with the same runtime. Run these checks separately from the package and device SDK builds in Apple CI.

Issue #22 remains open for measuring contrast and testing VoiceOver, Switch Control, Reduce Motion, Reduce Transparency, pointer and gaze/pinch on devices. Repeat the complete conversation flow once playback and the ASL controls are available.
