# Sign MT compatibility and production-access assessment

Issue #2. Assessed 5 November 2026. Status: **compatibility observed; production access and retention agreement unresolved**.

## Pinned evidence

Upstream revision: `928d49ffe223fccedca64162851d4951b9152ecc`.

- [Translation service](https://github.com/sign/translate/blob/928d49ffe223fccedca64162851d4951b9152ecc/src/app/modules/translate/translate.service.ts)
- [Privacy policy](https://github.com/sign/translate/blob/928d49ffe223fccedca64162851d4951b9152ecc/PRIVACY.md)
- [License](https://github.com/sign/translate/blob/928d49ffe223fccedca64162851d4951b9152ecc/LICENSE.md)

The client constructs a GET request to `https://us-central1-sign-mt.cloudfunctions.net/spoken_text_to_signed_pose` with `text`, `spoken` and `signed` query parameters. English is `en`; ASL is `ase`. This is an observed integration, not a documented third-party service contract.

A single synthetic `Hello` request returned HTTP 200 and `application/pose`, with 256,192 bytes. See [probe metadata](sign-mt-probe.json). No response body or upstream model/pose asset is redistributed. A successful request proves neither complete coverage nor stable access, quality or licensing rights.

## Privacy finding

The provider's policy states that the spoken-to-signed feature logs full input for rendering-quality improvement. It names Google Cloud Logs and BigQuery and describes deletion when no longer operationally required, without a fixed period in the inspected text. SRay must not promise provider-side zero retention or deletion when the user ends a session.

Local offline captions remain separate. Enabling online ASL must disclose text transmission and provider logging. Query strings containing transcripts must be excluded from local logs, crash attachments, analytics and disk caches. Avoid optional normalization/vocalization paths unless separately specified and disclosed; their provider flows differ.

## Required answers before production activation

| Item | Evidence today | Remaining decision |
| --- | --- | --- |
| Endpoint and language parameters | Pinned client plus one synthetic 200 response | Supported integration contract and version policy |
| Authentication/access | Probe succeeded without credentials | Authorization for SRay distribution and sustained usage |
| Rate limits, quota and cost | Not established | Written operating limits and budget decision |
| Content retention | Full-input logging described | Concrete retention, deletion and regional processing terms |
| Pose schema and version | application/pose observed | Decoder/version/size/frame contract in #5 |
| Error behavior | Success only | Document 4xx/5xx/429/timeout semantics without stressing service |
| License | Separate upstream noncommercial/share-alike/commercial terms | Scope of permitted integration and any redistribution |

No provider contact or agreement acceptance has been performed. The maintainer must obtain the service terms before enabling production translation. Existing functionality is not permission to make an unlimited-volume dependency.

## Implementation boundaries

Use an injected typed translation interface; keep provider URLs and binary parsing out of SwiftUI. Model expected service failures explicitly. New Swift declarations should document cancellation and the distinction between a received pose and a validated translation. Adapter tests in #12 must use synthetic, rights-cleared fixtures and deterministic stubs near the interface under DEBUG; do not call the live service in ordinary CI.

The app's request timeout and queue bounds remain local policies, not provider guarantees. Treat any response after a pause/epoch change as stale even if transport cancellation fails. The application must remain useful for offline captions when this integration is unavailable.

## Coverage

Pinned request path, language identifiers, synthetic compatibility and privacy risks are documented. Production authorization, quotas, versioning, retention agreement and error semantics remain outstanding. This report does not close issue #2.
