# Engineering conventions

## Architecture fit

SRay is a new SwiftUI application with app-wide session state and competing asynchronous effects. Use a small, framework-free MVI boundary for the conversation feature: value state, user intents, deterministic transition logic and an isolated effect runner. This fits the pause/cancellation/privacy invariants better than scattered observable flags.

Keep speech, translation and pose decoding behind focused injected interfaces. Views render state and send intents; they do not start recognition or network work directly. Do not add TCA or a global dependency container. Unrelated settings screens do not need reducers simply for consistency.

The prior prototype's iOS 17 and visionOS 2 declarations are evaluation candidates, not a verified support promise. Final deployment floors follow issue #4. Use main-actor observation only where available and appropriate. Session/utterance/transmission identifiers must reject stale responses; task cancellation alone is insufficient.

## Swift API review

Read declarations with real call sites. Prefer role-based names and fluent labels, such as `pauseTranslation()` and `translate(_:from:to:)`. Boolean properties read as assertions. Document each new declaration's behavior, and public cancellation, throwing, isolation and nonconstant complexity contracts. Avoid `Any` transport models and redundant type names in labels.

## Test strategy

Use Swift Testing (`@Test`, `#expect`, `#require`) for new unit and integration tests. Give each test clear Arrange/Act/Assert phases, deterministic inputs and isolated state. Use parameterized tests for input classes, including unsupported and boundary values. Tests must exercise production behavior rather than asserting that a mock returns its own canned value.

Place minimal stubs/spies near their interface and deterministic fixtures near their models under `#if DEBUG`. Do not use random fixture identifiers or wall-clock sleeps for race tests. Control completion order and clocks. Prefer state assertions; inspect submitted requests when verifying privacy boundaries. UI automation, when introduced, needs the platform's supported UI-test tooling and is distinct from Swift Testing unit tests.

Every reentrant asynchronous effect needs cancellation and stale-response tests. Every decoder needs malformed/oversized/non-finite input tests. Shared code must not require microphone, network or human participants to run unit tests.

## Per-issue review checklist

- Architecture: scope, UI stack, deployment assumptions, state ownership, injection and effects are explicit.
- API: call-site names, labels, documentation and cancellation semantics are clear.
- Testing: behavior, failure paths and concurrency boundaries have evidence; not-applicable checks are explained.
- Migration: imported material has source revision, provenance and notices; prefer a small verified boundary over copying prototype infrastructure wholesale.
- Completion: list covered and outstanding acceptance criteria; physical-device, provider and linguistic evidence is never inferred from a successful build.
