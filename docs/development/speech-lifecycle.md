# Speech lifecycle implementation

Issue #9. Implemented modules are not yet connected to the app UI. Device audio behavior remains unverified.

## Ownership

`SpeechCore` contains one main-actor `SpeechSession` and an injected `SpeechBackend` contract. The app composition root must create exactly one session/backend and share it across windows. Call `run(onEvent:)` from a caller-owned task after an explicit user start, and call `stop()` on end/interruption. Duplicate starts on that session are ignored.

Every run has a private identity. Stop invalidates it before releasing resources. Permission results, buffered recognition and cancellation cleanup from an old run cannot start capture or stop a later run. An OS permission dialog itself cannot be dismissed by cancelling the task; a late answer is ignored and cannot acquire the microphone. No automatic restart occurs after completion/failure; the caller must explicitly run a new request.

Snapshots are delivered synchronously on the main actor through `onEvent`. Keep that callback short. It is the integration point for the finalized-utterance boundary in #10, not a translation client. Session storage is cleared on termination. The downstream conversation store must enforce its own content limits and clearing policy.

## Apple adapter

`SpeechPlatform.AppleSpeechBackend` is compiled only for iOS and visionOS. It selects en-US, checks on-device capability and permission again before capture, and sets `requiresOnDeviceRecognition = true`. It never retries with cloud recognition. [Apple documents both the capability requirement and request flag](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition).

The adapter owns an audio engine, one input tap and one recognition request. Teardown invalidates callbacks, stops the engine, removes its tap, ends audio, cancels recognition, finishes the event stream and deactivates its audio session. Setup failures take the same cleanup path. The event stream holds at most 32 pending snapshots; overflow becomes a typed failure rather than silently discarding a final result. Framework error text is not exposed or logged.

Before integration, add accurate `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` values to the host targets. [Speech authorization requires its usage description even for on-device requests](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition). The current unavailable app screen invokes neither permission API nor capture. The composition root, permission UI and interruption hooks remain outstanding; this PR does not enable recording.

## Verification

```sh
swift test --package-path Packages/SRayKit
swift build --package-path Packages/SRayKit --triple arm64-apple-ios17.0 \
  --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
swift build --package-path Packages/SRayKit --triple arm64-apple-xros2.0 \
  --sdk "$(xcrun --sdk xros --show-sdk-path)"
```

Use separate scratch paths when switching SDKs. The implementation was compiled with Xcode 27.0 in Swift 6 mode for both device SDKs. Twelve Swift Testing functions (fourteen scenarios) cover authorization stop/cancellation, denied/unavailable states, duplicate starts, setup failure, stream completion/failure, final delivery, explicit restart, active cancellation, stale buffered events and actual bounded-stream overflow. A local mutation removing cleanup made the suite fail; restoring it passed. Tests use a DEBUG-only controlled backend beside its interface and explicit async signals without sleeps.

These tests establish controller behavior and a controlled stream, not framework audio teardown or the Apple adapter's physical network behavior. Issue #4 owns device/asset feasibility. Issue #21 owns full app interruption recovery. The application integration, repeated physical capture cycles, audio-session deactivation, denied/revoked permissions and disconnected capture must be validated before issue #9 closes.

## CI dependency

PR #46 introduces device-SDK compilation for every package and discovers test targets automatically. This branch is stacked on mrst-8 so the required Apple CI check covers these modules immediately. Merge PR #46 first, then update this branch from develop before merging its own changes. The existing speech-probe workflow alone does not validate this implementation.
