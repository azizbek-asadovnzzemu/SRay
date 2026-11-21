# Session-only caption memory

Issue #16. The app bounds caption memory and hides the transcript when its scene is inactive. The simulator audit verifies whether the fixed QA caption appears in the app data container or its process logs.

`CaptionMemory` retains at most 200 rows and removes rows aged ten minutes from their original monotonic start. Partial corrections replace the same stable ID and cannot extend its lifetime; finalized rows cannot be changed by late partials. The owner must call `snapshot(at:)` on updates and during idle expiry, and `clear()` on end/interruption. Returned view snapshots must also be cleared. This is ordinary Swift memory release, not a claim of cryptographic zeroization.

Each caption has a 64 KiB UTF-8 input envelope to bound memory even if recognition produces an abnormal result. Oversized input is rejected in full with `rejectedOversize`; callers must stop/report the omission rather than silently display truncated text. Normal captions are preserved unchanged. The upper bound is about 12.5 MiB of retained text before collection/rendering overhead; actual peak memory needs device measurement.

The component has no file, URL, clipboard, persistence, analytics or logging APIs. Its synthetic tests prove partial-to-final identity, immutable finals, count/age bounds, no expiry revival, exact/over-limit inputs and explicit clearing. They do not establish absence of content in framework diagnostics or process memory.

Run `swift test --package-path Packages/SRayKit`. The failing baseline produced eleven assertion failures before the implementation was added; the completed implementation passed. Integration and expiry scheduling belong to #17. Provider URL caches, pose storage and diagnostic inspection remain linked to #12/#14 and the rest of #16; do not close #16 on this component alone.

## Simulator artifact audit

Use a disposable simulator containing only synthetic SRay conversations. Run `python3 scripts/apple_ci.py iphone-ui` or `python3 scripts/apple_ci.py ipad-ui` to run the XCUITest suite and audit its artifacts. To use a specific simulator, set `SRAY_SIMULATOR_UDID` to its UDID.

CI boots the selected simulator and runs XCUITest. The audit then launches the Debug synthetic fixture in a separate process and requires a content-free readiness record. It checks regular files in the app’s data container, including caches, and queries unified logs for that specific process. It searches for the fixed caption as UTF-8 and UTF-16 text. A match or unavailable source fails the job. Output contains counts, channel status, and the subsystem and category of matching log entries. Test records, raw logs and app files stay out of published artifacts.

Run `PYTHONPATH=scripts python3 -B -m unittest discover -s scripts/tests` to calibrate the scanner with positive file and log fixtures. This is an exact-text audit. Compressed data, physical app-switcher snapshots, crash reports and transcript-bearing provider diagnostics still need separate validation.

Use the latest caption’s accessibility identifier in UI-test selectors. Read its label separately when checking text so the test runner does not use the caption as a query predicate.

Apple Accessibility and XCTest logged the synthetic fixture during the instrumented UI suite, including after the identifier change. The standalone process isolates ordinary app execution from those test-driven records. To reproduce the instrumented observation, run `python3 scripts/audit_caption_artifacts.py SIMULATOR_UDID --last 15m` after a synthetic UI test suite. Verify physical-device and assistive-technology diagnostics separately before release.

The simulator jobs also launch a separate Debug pose fixture. It sends a fixed caption through the local translation pipeline and the native renderer. The fixture ends the conversation and emits a content-free readiness record when the pose reaches the replay slot. CI scans only that process and the app data container for the fixed pose caption. The audit reports counts and bounded log origin labels. Provider traffic, pose payload storage and physical-device diagnostics still need separate evidence.
