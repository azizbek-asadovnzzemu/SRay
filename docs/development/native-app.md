# Build and test SRay on Apple platforms

Use full Xcode with the iOS and visionOS SDKs. Select that installation as the
active developer directory and verify the toolchain with `xcodebuild -version`.
The committed `SRay.xcodeproj` references `Packages/SRayKit` by a
repository-relative path. The unsigned build uses no external Swift packages or
developer account.

## Build from a clean checkout

```sh
git clone --branch develop https://github.com/azizbek-asadovnzzemu/SRay.git
cd SRay
xcodebuild -version
python3 scripts/apple_ci.py ios
python3 scripts/apple_ci.py visionos
python3 scripts/apple_ci.py packages
```

These checks build the unsigned device targets and run host package tests. iOS 17
and visionOS 2 are the current deployment targets. The supported-device matrix
will follow [offline speech verification](../feasibility/offline-speech.md).

## Try the conversation in a simulator

Open `SRay.xcodeproj`. Select the `SRay-iOS` scheme for iPhone or iPad, or
`SRay-visionOS` for Vision Pro. Choose a simulator that has its runtime
installed. Under **Product → Scheme → Edit Scheme → Run → Arguments**, add one
environment variable for a Debug run:

| Variable | Value | Scenario |
| --- | --- | --- |
| `SRAY_SYNTHETIC_CAPTIONS` | `1` | Start and end a conversation with generated caption text |
| `SRAY_SYNTHETIC_ASL` | `1` | Start captions, enable the demo, and generate a caption to play and replay a local geometric pose |

Each fixture runs without microphone input or a provider request. Use the
[caption accessibility guide](accessibility-qa.md) for the iPhone and iPad
simulator test commands. Keep generated content in any public test screenshots.

## Run on a physical device

1. Pair an approved test device with the Mac and enable Developer Mode on the
   device. [Enable Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
2. Sign in to Xcode with an Apple Account that can provision that device. In the
   relevant app target’s **Signing & Capabilities** tab, enable automatic signing
   and select your team. Use a bundle identifier available to that team. Keep
   local team and bundle changes out of contribution commits.
   [Set up physical-device signing](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices).
3. Select the physical device in the same scheme and run the app. If Xcode
   requests registration, use a team authorized to register the device.
4. Remove simulator fixture variables from the Run scheme to test live English
   capture. Select **Start Conversation** to request the microphone and speech
   permissions. Follow the offline protocol to verify assets, lock and recovery
   behavior. Record device class, OS build, app revision and the results.
   [Offline speech protocol](../feasibility/offline-speech.md).

SRay uses on-device recognition for live English captions. Live ASL remains
unavailable while the service contract, source timing and comprehension are
under evaluation. The [release evidence roadmap](../ROADMAP.md) tracks
physical-device and provider validation.

## Structure and ownership

- `Apps/SRay/SRayApp.swift` composes the shared session for the Apple app targets.
- `Packages/SRayKit/Sources/SRayUI` contains the conversation windows and controls.
- `ConversationCore` owns the caption session and coordinated transmission and
  playback state. SwiftUI sends user actions and observes presentation state.
- `SpeechPlatform` adapts Apple Speech to the shared `SpeechCore` boundary.
- `PoseCore` decodes verified pose data and `PosePlayback` renders it.
- `SignMT` contains the typed transport adapter and is tested independently
  of the app. Its live-service integration depends on provider authorization.

See [engineering conventions](../ENGINEERING.md) for isolation, Swift API and
verification guidance.
