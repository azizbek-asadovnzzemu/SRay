# Finalized utterance ledger

Issue #10 — pure identity/eligibility logic implemented; source-boundary integration remains outstanding.

`UtteranceLedger` belongs to one conversation and holds at most one pending source utterance plus a sequence watermark. Sequence IDs strictly increase across recognition restarts; they are never recycled within that conversation. Duplicate/late finals return nil. Starting a new utterance cannot silently replace unfinished work: either finalize it or explicitly interrupt it and mark the returned sequence in the caption store.

The capture integration must register the actual source start, not the arrival of the first partial/final callback. Start/end values use the same monotonic, session-relative time origin as enable/pause controls. Unknown, negative or reversed timing is excluded from ASL. The current Apple adapter provides text snapshots but does not yet provide these verified source boundaries; do not invent them from callback arrival time. Wiring that metadata is required before issue closure.

At begin, retain the enabled translation window. At finalization, require the same window and a source start at or after its opening. A new enable/resume requires a fresh identity even when timestamps are equal. Paused, pre-enable and boundary-crossing speech stays local. Partials can be accepted for captions, but the ledger produces submission eligibility only on finalization. Issue #11 must recheck that window when actually dispatching and reject late results after invalidation.

Text over 280 extended grapheme clusters or speech over fifteen seconds is excluded from ASL with an explicit reason. The full caption is returned unchanged: no silent truncation, automatic splitting or lost negation. Empty text is excluded. The future UI must surface omissions and the conversation store must apply the separate retention/memory limits in #16.

## Verification

Run `swift test --package-path Packages/SRayKit`. Nine ledger test functions cover fifteen scenarios, including exact/over-limit emoji graphemes and durations, corrected final text, duplicate finals, interruption/restart overlap, unknown timing, empty text and equal-timestamp epoch changes. Removing the epoch comparison locally made the boundary tests fail; restoring it passed. The twelve speech lifecycle test functions also remain passing.

This branch is stacked on mrst-9 (PR #47), which depends on mrst-8 (PR #46). PRs still target develop; merge prerequisites first and update downstream branches before merging. Hosted CI compiles all packages for both native SDKs and runs package tests.
