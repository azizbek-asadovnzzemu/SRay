# Session-only caption memory

Issue #16: the caption-memory component is implemented; app-switcher protection and end-to-end diagnostics/transport inspection remain outstanding.

`CaptionMemory` retains at most 200 rows and removes rows aged ten minutes from their original monotonic start. Partial corrections replace the same stable ID and cannot extend its lifetime; finalized rows cannot be changed by late partials. The owner must call `snapshot(at:)` on updates and during idle expiry, and `clear()` on end/interruption. Returned view snapshots must also be cleared. This is ordinary Swift memory release, not a claim of cryptographic zeroization.

Each caption has a 64 KiB UTF-8 input envelope to bound memory even if recognition produces an abnormal result. Oversized input is rejected in full with `rejectedOversize`; callers must stop/report the omission rather than silently display truncated text. Normal captions are preserved unchanged. The upper bound is about 12.5 MiB of retained text before collection/rendering overhead; actual peak memory needs device measurement.

The component has no file, URL, clipboard, persistence, analytics or logging APIs. Its synthetic tests prove partial-to-final identity, immutable finals, count/age bounds, no expiry revival, exact/over-limit inputs and explicit clearing. They do not establish absence of content in framework diagnostics or process memory.

Run `swift test --package-path Packages/SRayKit`. The failing baseline produced eleven assertion failures before the implementation was added; the completed implementation passed. Integration and expiry scheduling belong to #17. Provider URL caches, pose storage and diagnostic inspection remain linked to #12/#14 and the rest of #16; do not close #16 on this component alone.
