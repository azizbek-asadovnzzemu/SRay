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

Run the existing Swift package suites using synthetic responses. These cover separate parts of the incident path.

```sh
swift test --package-path Packages/SRayKit --filter SignMTClientTests
swift test --package-path Packages/SRayKit --filter TranslationGateTests
swift test --package-path Packages/SRayKit --filter TranslationQueueTests
swift test --package-path Packages/SRayKit --filter CaptionSessionTests
```

Check that the response boundary distinguishes 429, 5xx, authorization and malformed payloads. Check that pausing rejects late callbacks and permanently closes its queue. Confirm the app-owned caption session runs and clears synthetic text independently.

Repeat the exercise after the transport, queue and renderer are connected. A completed outage drill must record how the app reacted to the injected failure, how captions continued, how late output was rejected, and how fresh speech resumed after explicit action. The component exercise does not establish those integrated outcomes.
