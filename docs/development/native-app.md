# Native app scaffold

Issue #7 — original SwiftUI scaffold; integration work remains open.

## Build

Open `SRay.xcodeproj`, select `SRay-iOS` or `SRay-visionOS`, and select a matching destination. The project references `Packages/SRayKit` by a repository-relative path. No dependency download, project generator, signing team or secret is required for unsigned SDK builds. The committed Xcode project is the source of truth.

```sh
xcodebuild -project SRay.xcodeproj -scheme SRay-iOS \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/sray-ios \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project SRay.xcodeproj -scheme SRay-visionOS \
  -destination 'generic/platform=visionOS' -derivedDataPath /tmp/sray-visionos \
  CODE_SIGNING_ALLOWED=NO build
```

The iOS target includes both iPhone and iPad device families; visionOS has its own target and scheme. iOS 17 and visionOS 2 are candidate deployment floors pending #4 device evidence. The package's macOS floor is only for host tooling, not product support. Bundle identifiers are development placeholders; signing and distribution are not configured.

## Structure and ownership

- `Apps/SRay/SRayApp.swift`: app composition root shared by both native targets.
- `Packages/SRayKit/Sources/SRayUI`: native SwiftUI presentation, semantic system styling and accessibility-compatible empty state.
- `Packages/SRayKit/Sources/ConversationCore`: platform-independent conversation capability boundary.

No original prototype files or third-party assets were imported. This is newly written source under the repository license. There is no web view or production web DOM bridge. The initial screen explicitly reports unavailable conversations; it does not simulate listening, translation or permission success.

Framework-free MVI is the selected fit for the forthcoming conversation feature because pause/stop, speech callbacks and transport completion must share explicit state transitions. Introduce reducer state and injected effects with the actual behavior, rather than a placeholder reducer now. The composition root supplies dependencies; views render state and send intents. SwiftUI/main-actor state owns presentation; immutable Sendable values cross service boundaries.

Speech ownership/lifecycle is tracked in #9, utterance segmentation in #10, and service/pose integration in their respective backlog issues. Those modules will be extracted with real contracts after #2/#4/#5 evidence. This scaffold intentionally contains no microphone or network capability. Issue #7 stays open until the shared service boundaries are integrated and prerequisite platform evidence is resolved.

## Recorded build evidence

Both unsigned generic-device builds passed with Xcode 27.0 and Swift 6 mode. This establishes compilation only. No simulator launch, physical-device session or accessibility runtime check is claimed.

## Verification and review

Use Swift Testing for behavior added to the shared package: Arrange–Act–Assert, deterministic clocks and injected services, state verification, and test doubles beside their interfaces under DEBUG. This static scaffold has no behavior suite; asserting a single enum case or copied UI strings would not establish correctness. Unsigned builds check source compilation and local package integration. Runtime layout, assistive technology, device support and product functionality need later validation.

Review declaration documentation and call-site naming, main-actor UI ownership, clean relative package resolution, both target families and the absence of embedded service credentials. Do not infer readiness for App Store distribution from a successful SDK build.
