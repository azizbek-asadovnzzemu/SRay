# Transmission gate

Issues #11 and #13. The gate and first-frame queue share a coordinator. The shared conversation model connects accepted caption finals to the gate. Production capture still needs verified speech timing.

Share one main-actor `TranslationPipeline` across conversation windows. It owns the `TranslationGate`. A conversation starts captions-only with a fresh ID. Explicit enable/resume opens a new translation window. Snapshot it at each source utterance start as described in [the ledger contract](utterances.md). There is no implicit enable on startup, recovery or completion.

`dispatch(_:start:)` revalidates conversation, original enable window and finalized eligibility synchronously with request creation. The supplied closure must create/start its cancellable transport request immediately on the same actor; do not enqueue the actual send into another task. There is no await between the eligibility check and this callback. Only one request may be in flight, and a sequence watermark prevents duplicate/out-of-order submissions. The gate never stores text or queues rejected requests for replay. #13 owns queue admission and omission reporting.

Pause clears the active window and request identity and sets visible state before invoking transport cancellation. It preserves the conversation ID so local captions can continue. End/interruption invalidate the conversation too; resume cannot revive it, and explicit restart begins captions-only. Cancellation cannot retract text already dispatched. The transport adapter must map each token to an actual cancellable operation and treat cancellation as best effort.

`complete(_:)` accepts a response exactly once only for the current request and window. A result from before pause, from a prior conversation, or from a duplicate callback cannot release a newer request's capacity or be shown as fresh output. Completion never re-enables translation. The caller must use the returned Boolean before consuming response data.

## Queue and renderer wiring

Pass eligible finals with their finalization instant. Use the same session-relative monotonic clock for renderer and transport events. Reschedule the expiry timer to `nextExpiry` after each event and call `advance(to:)` when it fires. Expiry applies while waiting as text, in flight, or ready for a first frame. Report returned omissions against their caption sequences.

Present a ready clip only after `beginPlayback(for:at:)` accepts its submission. Render the current `activePlayback` and report the last displayed frame using its display ID. Each play attempt receives a new ID, including replay of the same clip. Release renderer references when the active attempt changes or clears.

The pipeline keeps one completed live clip for local replay in the current conversation. Use `canReplay` and `beginReplay(at:)` when the renderer is idle and no live work is waiting. Pause stops the active display and preserves the completed clip for explicit replay. End and interruption release both cached and active clips. A transport failure closes the enable window and drops queued text. Reopening the window requires an explicit action after connectivity and service policy permit it.

## Verification

Eight gate test functions cover fourteen scenarios with synchronous main-actor ordering and injected callbacks. Cases include duplicate conversation starts, default-off state, pause before cancellation, prior-window replay, late completions after resume, duplicate completion/submission, excluded captions, foreign conversation callbacks and end/interruption recovery. Moving the visible-state invalidation after cancellation caused a test failure; restoring the ordering passed. Existing ledger and speech suites remain passing.

Run `swift test --package-path Packages/SRayKit`. The coordinator tests exercise the production gate and queue together with a synthetic transport and monotonic event times. Hosted CI also compiles the package for iOS and visionOS.

## Caption integration

The caption session opens and closes the shared gate and forwards stored finals with verified monotonic audio boundaries. A caption can reach the translation pipeline only if its audio began after the current enable window opened. A final with missing timing, out-of-range timing or a start exactly at the enable boundary stays local. Pausing invalidates the window and cancels the current translation before returning. Captions continue until the conversation ends or is interrupted.

The platform speech backend currently supplies captions without verified audio boundaries. The Debug fixture provides controlled timing for the integration path. Live activation still depends on physical-device timing and cancellation evidence, authorized provider access and review of the complete consent flow.
