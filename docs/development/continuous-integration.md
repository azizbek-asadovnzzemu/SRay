# Apple continuous integration

Issue #8. `Apple CI` runs for pull requests and pushes to develop/main. No signing, production credentials, microphone capture or translation-service traffic is required.

## Checks and toolchains

Five matrix jobs build the iPhone/iPad and visionOS targets, validate the Swift packages, and run the [caption UI tests](accessibility-qa.md) on iPhone and iPad simulators. Each device build also compiles the device packages, including adapters outside the app graph. Explicitly macOS-only tools run in the host package job. Packages with test targets run `swift test`; other packages run `swift build`. Physical-device validation uses its own protocol.

The workflow selects Xcode 26.6 explicitly on `macos-26`, based on the [published runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md). Missing toolchains fail the run instead of silently selecting a different version. Local development currently uses Xcode 27.0. Runner OS images evolve; record the image and printed toolchain versions from each run when investigating a regression.

`Apple CI` succeeds only when every matrix job succeeds. `Apple CI` and `Repository checks` are both required, along with one independent review.

## Reproduce locally

```sh
python3 scripts/apple_ci.py ios
python3 scripts/apple_ci.py visionos
python3 scripts/apple_ci.py packages
python3 scripts/apple_ci.py iphone-ui
python3 scripts/apple_ci.py ipad-ui
```

Run from a machine with full Xcode installed and selected. The commands write intermediate products under the runner temporary directory (or `/tmp` locally), never into tracked source. Each command exits nonzero on failure. SDK builds validate compilation and package resolution, not installed-device speech capability or ASL quality.

Each UI job selects a device of the requested family on the newest available iOS simulator runtime. Set `SRAY_SIMULATOR_UDID` to use a specific simulator locally. A missing or mismatched destination fails the job. The iPad layout check is expected to skip on iPhone.

## Trust and artifacts

Use pull_request rather than pull_request_target. Checkout credentials are not persisted, permissions are read-only, and action revisions are pinned. Fork code is executed without repository secrets or signing assets. Do not add privileged tokens or service credentials to this workflow.

Failure artifacts contain only task labels and integer exit codes from `outcomes.json`, retained for seven days. No raw build log, environment dump, result bundle, audio, transcript or pose is uploaded. Console output remains visible to collaborators and the public; tests must use synthetic inputs and must not log content or secrets.

## Regression demonstration

Before accepting this workflow, temporarily change the existing offline-readiness test to expect success for a recognizer without on-device support. Observe a failed packages job and failed aggregate on GitHub, then restore the assertion and require a fully passing run. Record both run links in the PR. Never merge the deliberate failure.

## Swift conventions

Use Swift Testing for unit and integration tests, with deterministic dependencies and assertions against production behavior. Use XCUITest for simulator interaction. Prefer framework-free MVI for conversation behavior, documented call-site APIs, and FormatStyle for displayed values.
