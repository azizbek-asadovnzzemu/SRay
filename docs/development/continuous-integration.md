# Apple continuous integration

Issue #8. `Apple CI` runs for pull requests and pushes to develop/main. No signing, production credentials, microphone capture or translation-service traffic is required.

## Checks and toolchains

Three independent jobs build the iPhone/iPad target, build the visionOS target, and validate every Swift package directly under `Packages` and `Tools`. Each native job also compiles all package targets against its device SDK, covering adapters not yet linked into the app. Packages with test targets run `swift test`; other packages run `swift build`. New behavioral suites therefore join CI without a separate workflow change. There are currently no app UI test targets; these SDK builds do not claim simulator execution or physical-device validation.

The workflow selects Xcode 26.6 explicitly on `macos-26`, based on the [published runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md). Missing toolchains fail the run instead of silently selecting a different version. Local development currently uses Xcode 27.0. Runner OS images evolve; record the image and printed toolchain versions from each run when investigating a regression.

`Apple CI` is an aggregate check: success requires every matrix job to succeed, including the Swift tests. Cancellation or failure cannot produce a passing aggregate. The existing `Repository checks` remains separate. Once the new workflow passes, require both checks in branch protection. Independent review remains required.

## Reproduce locally

```sh
python3 scripts/apple_ci.py ios
python3 scripts/apple_ci.py visionos
python3 scripts/apple_ci.py packages
```

Run from a machine with full Xcode installed and selected. The commands write intermediate products under the runner temporary directory (or `/tmp` locally), never into tracked source. Each command exits nonzero on failure. SDK builds validate compilation and package resolution, not installed-device speech capability or ASL quality.

## Trust and artifacts

Use pull_request rather than pull_request_target. Checkout credentials are not persisted, permissions are read-only, and action revisions are pinned. Fork code is executed without repository secrets or signing assets. Do not add privileged tokens or service credentials to this workflow.

Failure artifacts contain only task labels and integer exit codes from `outcomes.json`, retained for seven days. No raw build log, environment dump, result bundle, audio, transcript or pose is uploaded. Console output remains visible to collaborators and the public; tests must use synthetic inputs and must not log content or secrets.

## Regression demonstration

Before accepting this workflow, temporarily change the existing offline-readiness test to expect success for a recognizer without on-device support. Observe a failed packages job and failed aggregate on GitHub, then restore the assertion and require a fully passing run. Record both run links in the PR. Never merge the deliberate failure.

## Swift conventions

Use Swift Testing for new unit/integration tests, deterministic dependency injection, Arrange–Act–Assert, and state assertions against production behavior. Keep UI tests separate when introduced; Swift Testing does not drive UI automation. Prefer framework-free MVI for conversation behavior and documented call-site APIs. Use modern FormatStyle/Text format APIs when displaying dates, numbers or durations; this CI change introduces no displayed formatted values.
