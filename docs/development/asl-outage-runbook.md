# Responding to an ASL service outage

SRay runs local English captions independently of Sign MT. The current app has no enabled ASL transport. Use this runbook for preflight exercises and for incidents after the service is enabled.

## Identify and contain

1. Record the affected app version, platform, rough time window and content-free error category. Use counts for offline, timeout, rate limit, authorization, invalid response, queue expiry and cancellation. Keep transcripts, poses, request URLs, bodies, credentials and real session IDs out of incident records.
2. Close ASL dispatch for the affected session. Invalidate its enable window before cancellation, clear work awaiting playback and stop the active renderer. Reject late work from that window. Continue local captions.
3. If permission or provider terms are in doubt, disable online ASL in the released composition until the maintainer verifies authorization. If this requires a code rollback, revert the enabling change through the usual reviewed release process. Until a remote disable mechanism exists, a released client cannot be disabled through this repository alone.
4. Communicate the status plainly in the app. Say that local captions remain available and ASL is unavailable. For a rate limit, honor Retry-After before offering an explicit resume. Never silently resend old captions or switch to another provider.

## Restore

- Confirm the approved provider endpoint, request and pose format, usage limits, retention and license if the failure followed a provider change. Re-run synthetic contract and pose fixtures before restoring availability.
- Verify that captions-only mode generates no ASL requests. Exercise failure and resume with a synthetic caption that spans the outage. The next explicit enable must create a new window, and only wholly new utterances can be dispatched.
- Monitor error categories, queue omissions and first-frame times as aggregates. A build or green endpoint says nothing about comprehension, so repeat the affected ASL checks when the provider model or rendering output changes.
- Direct ordinary reports to [support](../../SUPPORT.md). Route suspected content exposure or credential leaks through the [security reporting process](../../SECURITY.md).

## Preflight exercise

Run the package drill with synthetic speech and a synthetic service failure. It exercises the production caption session, utterance ledger and translation pipeline together.

```sh
swift test --package-path Packages/SRayKit --filter OutageRecoveryTests
swift test --package-path Packages/SRayKit --filter SignMTClientTests
swift test --package-path Packages/SRayKit --filter TranslationGateTests
swift test --package-path Packages/SRayKit --filter TranslationQueueTests
swift test --package-path Packages/SRayKit --filter CaptionSessionTests
```

The drill requires captions to stay active during the outage and verifies that the final local caption is still readable. It checks that the pending request and queue are omitted, late output is rejected, and a new request requires an explicit resume and fresh speech. The other suites check typed provider responses, queue bounds and transcript cleanup independently.

Repeat the exercise on devices after the service and renderer are connected to the app. Record actionable status feedback, continuous captions, late-result rejection and explicit resume. Verify the Retry-After policy with a rate-limit fixture and record whether the first fresh utterance plays within its latency budget.
