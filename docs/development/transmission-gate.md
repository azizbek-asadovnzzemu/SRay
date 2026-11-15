# Transmission gate

Issue #11 — dispatch state machine implemented; transport, caption and UI coordination are not yet wired.

Create one main-actor `TranslationGate` in the composition root and share it across windows. A conversation starts captions-only with a fresh ID. Explicit enable/resume opens a new translation window; utterance starts must snapshot it as described in [the ledger contract](utterances.md). There is no implicit enable on startup, recovery or completion.

`dispatch(_:start:)` revalidates conversation, original enable window and finalized eligibility synchronously with request creation. The supplied closure must create/start its cancellable transport request immediately on the same actor; do not enqueue the actual send into another task. There is no await between the eligibility check and this callback. Only one request may be in flight, and a sequence watermark prevents duplicate/out-of-order submissions. The gate never stores text or queues rejected requests for replay. #13 owns queue admission and omission reporting.

Pause clears the active window and request identity and sets visible state before invoking transport cancellation. It preserves the conversation ID so local captions can continue. End/interruption invalidate the conversation too; resume cannot revive it, and explicit restart begins captions-only. Cancellation cannot retract text already dispatched. The transport adapter must map each token to an actual cancellable operation and treat cancellation as best effort.

`complete(_:)` accepts a response exactly once only for the current request and window. A result from before pause, from a prior conversation, or from a duplicate callback cannot release a newer request's capacity or be shown as fresh output. Completion never re-enables translation. The caller must use the returned Boolean before consuming response data.

## Verification

Eight gate test functions cover fourteen scenarios with synchronous main-actor ordering and injected callbacks. Cases include duplicate conversation starts, default-off state, pause before cancellation, prior-window replay, late completions after resume, duplicate completion/submission, excluded captions, foreign conversation callbacks and end/interruption recovery. Moving the visible-state invalidation after cancellation caused a test failure; restoring the ordering passed. Existing ledger and speech suites remain passing.

Run `swift test --package-path Packages/SRayKit`. Hosted CI also compiles the package for iOS and visionOS. The branch is stacked on mrst-10 (PR #48), mrst-9 (PR #47), and mrst-8 (PR #46), while its PR targets develop. Merge prerequisites and update downstream branches in order.

## Outstanding integration

No actual text request starts in this PR. Provider access/retention remains #2, the transport adapter is #12, and disclosure/control UI is #15. The integration must call pause/stop on the same shared gate before acknowledging the action, connect its cancellation hook to transport tasks, stop capture for end/interruption, and leave capture running for ASL pause. Hardware/network race tests must verify those complete flows before issue #11 closes. Unit tests here establish gate behavior, not network cancellation or physical-device privacy.
