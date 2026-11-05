# Offline English speech feasibility

Issue #4. Status: **preflight tooling implemented; physical offline validation outstanding**.

## Current evidence

The development host has Xcode 27.0 with iOS and visionOS SDKs. The prototype previously compiled for generic visionOS. Neither SDK presence nor compilation proves offline recognition. No iPhone, iPad or Vision Pro 30-minute offline session has been measured for SRay.

| Platform | Evaluation floor | SDK compilation | Physical offline recognition | Advertised support |
| --- | --- | --- | --- | --- |
| iPhone | iOS 17 candidate | Passed type-check (Swift 6 / Xcode 27) | Not tested | Not established |
| iPad | iPadOS 17 candidate | Passed type-check (Swift 6 / Xcode 27) | Not tested | Not established |
| Vision Pro | visionOS 2 candidate | Passed type-check (Swift 6 / Xcode 27) | Not tested | Not established |

The package uses these floors for investigation only. macOS 13 is a host-test target, not an additional product promise.

## Preflight module

`Tools/SpeechReadinessProbe` provides a small value-based readiness policy and an isolated Apple Speech adapter. It requests no permission, opens no microphone and contains no translation/network client. It distinguishes unsupported locale, unavailable on-device capability, missing permission, denied permission and eligibility to run an offline test.

`readyForOfflineTest` deliberately does not mean ready for production. Microphone authorization, installed speech assets, actual recognition success and thermal behavior still need device verification. Use it at a call site as:

```swift
let snapshot = SpeechCapabilityReader.capabilities(for: Locale(identifier: "en-US"))
let nextStep = snapshot.readiness
```

The reader is main-actor isolated; the snapshot is Sendable. The pure policy is tested with Swift Testing and deterministic value inputs, independently of device permissions. No stub or fixture abstraction is needed for these small value cases.

## Reproducible tests

```sh
swift test --package-path Tools/SpeechReadinessProbe
```

## Verification recorded

The Swift Testing suite passed three test functions with five scenarios after a failing baseline demonstrated four incorrect readiness outcomes. The package compiled on the host; source type-checks also passed for arm64 iOS 17 and arm64 visionOS 2. These are compilation and pure-policy results, not OS-adapter runtime or physical-device results.

## Physical validation protocol

1. Record device model, OS/build, app revision, selected English locale and asset setup status. Do not infer installed assets from the capability flag.
2. Explain microphone/local recognition, request permissions in context and verify denied/restricted states without recording.
3. Configure the selected recognition API to require on-device processing. Never retry with cloud recognition if local processing is unavailable.
4. After initial setup, disable all networking and restart the app. Run 30 minutes of synthetic/consented English speech. Record recognition failures, latency, resource/thermal behavior and interruptions without retaining content.
5. Repeat with missing assets, revoked permissions, screen lock/background, route changes and recognizer restart. Document precise recovery steps.
6. Inspect process/network evidence to establish that captions do not upload speech or text. Network failure alone is not a substitute for verifying an on-device-only configuration.
7. Publish measured support rows and limitations. Do not advertise a platform until it passes.

## Remaining blockers

The active app/audio pipeline is planned in #7/#9. This probe can be embedded into those targets but cannot replace hardware evaluation. Required physical devices, asset availability and measurements remain unverified; issue #4 stays open.
