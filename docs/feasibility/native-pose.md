# Native pose feasibility

Issue #5 — **investigation started; native playback and provider fixtures unverified**.

## Evidence and version boundary

Inspecting source is not proof that the hosted provider uses that revision. The provider's returned `application/pose` content type alone does not establish a binary version or an ASL component schema.

Pinned pose-format source: revision `5119d5aed321f32f0ce952949ca5f187438e5248`:

- [Header implementation](https://github.com/sign-language-processing/pose/blob/5119d5aed321f32f0ce952949ca5f187438e5248/src/python/pose_format/pose_header.py) writes version 0.2, dimensions and named components, points, limbs and colors.
- [Body implementation](https://github.com/sign-language-processing/pose/blob/5119d5aed321f32f0ce952949ca5f187438e5248/src/python/pose_format/pose_body.py) has separate version readers. The 0.2 reader consumes floating-point FPS, a 32-bit frame count and a 16-bit person count. Coordinates and confidence are separate arrays.
- [Older specification](https://github.com/sign-language-processing/pose/blob/5119d5aed321f32f0ce952949ca5f187438e5248/docs/specs/v0.1.md) describes 16-bit FPS and frame count. The 0.1 implementation derives frames from remaining bytes to accommodate the old frame-count limit. Do not silently apply this legacy behavior to 0.2.

No source, model, generated provider pose or third-party asset is imported by this change. A software license does not establish redistribution rights for service-generated fixtures.

## Architecture decision

Keep binary decoding separate from transport and rendering. A decoder accepts bounded bytes and returns an immutable, Sendable sequence or a typed failure. No network, logging of input or UI state belongs in the decoder. Rendering consumes only validated sequences. Conversation state owns cancellation and playback ordering.

Prefer an explicit `decode(_ data: Data) throws -> PoseSequence` boundary once the provider profile is verified. Document units, indexing, ownership, accepted versions and failure cases at the API. Do not expose unvalidated arrays as a renderable sequence.

## Proposed resource envelope

These are conservative spike limits, not measured provider requirements. Validate against licensed fixtures and device memory before accepting them as the production profile. An oversized result must fail visibly, never be silently truncated.

| Quantity | Proposed limit / validation |
| --- | --- |
| Encoded response | 8 MiB maximum, enforced while receiving as well as before decoding |
| Header | 256 KiB, at most 16 components; bounded UTF-8 names |
| Points and limbs | At most 1,024 total points and 4,096 total limbs; all indexes in bounds |
| People | Exactly one signer for this release profile |
| Frames | 1–1,800, with checked multiplication before allocating |
| Frame rate | Finite, greater than zero and at most 120 FPS |
| Duration | At most 60 seconds, checked independently of frame count |
| Coordinates | Only a verified 2D/3D profile; finite values; preserve coordinate semantics |
| Confidence | Finite and within the verified profile's range; missing points never invented |
| Decoded storage | 32 MiB per pose including metadata and temporary allocations; measure peak memory |

Verify exact payload length, version-specific widths, byte order, string encoding and arithmetic overflow. Reject unknown versions, unsupported component formats, truncation, invalid indexes and non-finite values. Avoid per-point heap objects. Enforce the PRD's three-pose total allowance separately; this table does not authorize unbounded queueing.

## Required fixture manifest

Before committing any generated pose, record origin, creation command/input, provider/model revision if available, creation date, permission/license, SHA-256, encoded size, version, frame rate, duration, dimensions, component/point names, index ordering, confidence semantics and expected rendering. Use synthetic everyday input only. If permission is unclear, retain metadata only and use original geometric fixtures for parser tests.

A format version does not define handedness or prove the presence of meaningful face/hand motion. Verify actual provider fields with an ASL evaluator. Document signer-left versus viewer-left, axis origins/direction, scaling and camera orientation. Never mirror automatically or discard facial components to make a renderer easier.

## Swift Testing plan

Use deterministic original byte fixtures close to decoder tests, with no live service in unit tests. Cover every truncation boundary, invalid UTF-8, unsupported versions, overflowing counts, exact limits and one-over-limit, malformed limb references, zero/non-finite FPS, and NaN/infinite coordinates/confidence. Compare valid decoded fields against an independent reference, not against a writer sharing decoder logic. Use parameterized tests for malformed variants. Mutation checks must demonstrate that removing a bounds check fails the relevant test.

## Native rendering experiment

After a licensed provider fixture establishes the profile, build a small native SwiftUI/graphics spike on iPhone, iPad and Vision Pro. Use asymmetric left/right movement and known timing to verify orientation and playback. Measure first-frame delay, dropped frames, peak memory and cancellation. Show hands and facial detail at supported sizes and contrast settings. Seek ASL assessment before claiming that a skeleton preserves meaning.

No native decoder or renderer is delivered here. Issue #5 remains open pending provider schema/fixture rights from #2 and the decoding/rendering evidence above. Issue #6 owns linguistic evaluation; a visually moving skeleton cannot close that gate.
