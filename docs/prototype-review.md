# Architecture and production-readiness review

Reviewed on 4 November 2026 against `main` at `66c76d6`. This is a source review and unsigned build baseline, not a production certification or a completed security audit.

## Structure

| Location | Responsibility today |
| --- | --- |
| `src/MRSignTranslate` | visionOS Xcode app and XCTest target |
| `MRSignTranslate/app` | App entry point, dependency registration, multiple windows and immersive scene |
| `MRSignTranslate/presentation` | Scenario menu, speech captions/bubbles, history, settings, privacy, WebKit translation views |
| `MRSignTranslate/domain` | Services, repositories, providers and use cases |
| `MRSignTranslate/data` | Models, stubs, SwiftData and Core Data infrastructure |
| `src/MRSignMTKit` | Swift package containing speech/audio, camera, language selection, JavaScript bridge and placeholder translation transformers |
| `src/MRSignMTArchitecture` | Swift package containing dependency injection, repository abstractions, navigation helpers, Keychain and logging |
| `src/MRSignTranslate/Packages/RealityKitContent` | RealityKit scene resources |

The app imports both local packages and RealityKitContent. MRSignMTArchitecture depends on swift-log. The app uses Swift 5 language mode; both main packages declare Swift tools 5.9. Preserve the current deployment targets until a separate compatibility decision is made.

The active translation experience embeds `https://sign.mt/?lang=en` in WKWebView and injects transcribed text into page elements. Skeleton views manipulate the hosted page through JavaScript. This is not a native translation engine. `Text2SignTransformer` and `Sign2TextTransformer` both return `nil`.

## Baseline verification

- Xcode 27.0, build 27A266a.
- `xcodebuild -list -project src/MRSignTranslate/MRSignTranslate.xcodeproj`: passed and resolved dependencies.
- Unsigned device build: passed using the command below.
- Build warnings include mutable state in a Sendable speech-recognition class, ineffective `nonisolated(unsafe)`, capture ownership and asset-symbol issues.
- Simulator execution was not performed: only an iOS 27 runtime is installed, with no visionOS runtime.
- No device interaction, real translation-service integration, accessibility walkthrough, or linguistic accuracy evaluation was performed.

```sh
xcodebuild \
  -project src/MRSignTranslate/MRSignTranslate.xcodeproj \
  -scheme MRSignTranslate \
  -destination 'generic/platform=visionOS' \
  -derivedDataPath /tmp/MRSignTranslate-build \
  CODE_SIGNING_ALLOWED=NO build
```

## Prioritized findings

### 1. Translation implementation and claims do not match

Files: `README.md`, `MRSignMTKit/Sources/MRSignMTKit/Transformers/` and the app's `presentation/screens/webview/MRWebView.swift`.

The README describes working sign recognition and enterprise use cases while the native transformers are placeholders. Replace claims with a capability matrix distinguishing working prototype behavior, hosted-service behavior and planned features. A native client needs an explicit service contract and a real provider before translation can be considered implemented.

### 2. Transcripts are inserted into executable JavaScript

Files: `MRSignMTKit/Sources/MRSignMTKit/JavascriptEvents/SignMTInputText.swift` and `presentation/screens/webview/MRWebView.swift`.

Text is interpolated into quoted strings and template literals. Apostrophes, backticks, newlines and template expressions can break scripts or be interpreted as code. While the bridge exists, pass data as JavaScript arguments or encode it safely, restrict navigation origins and handle load failures. Regression tests must execute generated scripts with hostile and multilingual input. Remove the bridge from native translation paths during migration.

### 3. Speech lifecycle and isolation need repair

Files: `presentation/screens/speech2text/services/SpeechToTextService.swift`, `SpeechToTextViewModel.swift`, and the package's `SpokenLanguage/SpeechRecognition/SpeechRecognitionManager.swift`.

The active service creates an unstructured task inside a stream without termination cleanup. Recognition callbacks mutate shared state, reset does not explicitly remove the audio tap or deactivate the audio session, and the view model does not restore `isRecording` when authorization fails or a stream finishes. Language detection changes a locale string while the recognizer remains immutable. Stop during pending authorization can still lead to recording startup without an explicit cancellation check.

Consolidate speech implementations behind one injectable interface. Keep presentation state on the main actor, define ownership of audio callbacks, finish streams on every terminal path and test cancellation, permission failure, restart and stale callbacks.

### 4. Privacy UI does not represent the data flow

Files: `presentation/screens/privacy/PrivacyView.swift`, `SpeechToTextService.swift`, and `app/Info.plist`.

The UI states that audio is processed on-device, but the inspected service does not require on-device recognition. Transcripts are logged and forwarded into a remote web page. Privacy toggles bind to local UI state rather than system authorization. Microphone and speech-recognition purpose strings are reversed in meaning.

Remove transcript logging, describe the selected processing mode accurately, surface real permission states and explain remote transmission before enabling it. Determine privacy-manifest requirements from actual APIs and final data handling. Do not claim camera sign recognition until supported and validated.

### 5. Tests do not establish production behavior

File: `MRSignTranslateTests/domain/SpeechToTextServiceTests.swift`.

The speech tests exercise `MockSpeechRecognitionService` itself rather than the production service or view model. This cannot catch the active lifecycle defects. Add behavior tests against production coordinators with injected audio/permission/recognizer boundaries. Preserve useful existing XCTest coverage; use Swift Testing for new unit tests supported by the toolchain.

### 6. Open-source and contribution infrastructure is missing

No root license, contribution guide, security-reporting guide, privacy manifest or `.github` CI workflow was found. The README clone command is a placeholder and its code fence is unclosed. There is no commitlint configuration. The remote has `main` and `dev`, but no `develop`; `dev` is one commit behind `main`.

Create `develop` from the reviewed main revision, preserving `dev` and other existing branches. Add setup instructions, architecture documentation, issue/PR templates, title validation and an executable build/test workflow. Require successful checks and one independent review before squash merging feature PRs. Release PRs from develop to main use `chore: release` and a merge commit.

### 7. Package and asset provenance needs cleanup

`MRSignMTKit/Package.swift` declares `../src/MRSignMTArchitecture`, which is not the sibling package path, and does not attach that dependency to a target. The Xcode project resolves the packages independently and its build succeeds despite the unused-dependency warning. Repair and verify standalone package resolution separately.

There are duplicate distribution files and a distribution ZIP, as well as upstream Firebase client configuration. Inventory their origin and actual use before deletion or redistribution. Client configuration identifiers alone are not proof of secret exposure. Do not assign a new project license to third-party material without checking its terms.

## Thesis and parity implications

The thesis calls the prototype SRay and evaluates captions, spatial speech bubbles, skeleton output and combinations of these modes. Its discussion identifies translation latency, missing non-manual signing features, language-pair selection and cognitive overload in combined modes. These support explicit spoken/signed language selection, user-controlled output modes and measured latency as release requirements.

The upstream feature map includes spoken/text input to sign production and camera/upload input to spoken output. A native SwiftUI shell alone does not implement these model pipelines. Native pose rendering, video ingestion, supported language pairs and sign-to-text inference each require separately verified implementations. Hand tracking is not equivalent to sign-language recognition.

## References

- [App repository](https://github.com/azizbek-asadovnzzemu/MRSignTranslate)
- [Thesis source](https://github.com/azizbek-asadovnzzemu/MRSignTranslate-Thesis-Overleaf), particularly chapters 4–6
- [Upstream feature map](https://github.com/sign/translate/blob/master/README.md)
- [Upstream license](https://github.com/sign/translate/blob/master/LICENSE.md): noncommercial/share-alike terms and a separate commercial tier; preserve attribution and resolve permitted reuse before redistribution.
