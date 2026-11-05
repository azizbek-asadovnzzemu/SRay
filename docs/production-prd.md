# SRay — Production release requirements

**Version:** 0.1, 4 November 2026  
**Status:** Proposed specification for owner approval. No production readiness is claimed.  
**Owner:** Azizbek Asadov  
**Platforms:** visionOS, iOS and iPadOS  
**First language pair:** English → American Sign Language (ASL)

This is the authoritative product proposal and supersedes conflicting assumptions in `native-client-design.md` and `product-decisions.md`. Confirmed owner decisions are distinguished from proposed engineering and evaluation thresholds. The architecture review remains a historical baseline.

## 1. Problem statement

Deaf and hard-of-hearing people can miss spoken information during everyday one-to-one conversations with hearing people. The existing research prototype explores captions and spatial signed output, but its hosted web integration, speech lifecycle and unvalidated translation quality prevent dependable everyday use. The first release must provide locally processed English captions and optional online ASL output, with clear control over when conversation text leaves the device.

The thesis provides directional evidence for user-controlled modalities, lower latency and explicit language pairing; its limited evaluation is not evidence of broad product effectiveness. The source review confirms a working unsigned visionOS build, placeholder native transformers and no established native production service contract.

## 2. Audience and core outcome

**Primary:** Deaf ASL users and hard-of-hearing English readers following a nearby hearing person's speech. ASL fluency and caption preferences vary; neither modality is universally preferred.

**Secondary:** Hearing conversation partners who speak toward the device and can see whether a session is active. Open-source contributors and portfolio reviewers must also be able to build and understand the project.

**Core outcome:** A person starts a conversation on Vision Pro, iPhone or iPad, follows live offline captions, optionally enables automatic ASL translation, pauses external transmission without losing captions, and ends the session without retaining conversation content.

This release assists the spoken-to-visual direction of an everyday conversation. It does not translate the Deaf person's signs back into speech or claim to replace an interpreter.

## 3. Goals

Proposed release thresholds require approval and baseline measurement; they are not current results.

1. At least 90% of pilot participants complete start, enable ASL, pause ASL and end-session tasks without assistance after onboarding.
2. English captions remain functional with networking disabled on every advertised supported device/OS configuration after required language assets are installed; no audio or transcript requests occur in captions-only mode.
3. On the agreed evaluation set, achieve the caption accuracy and latency thresholds in section 10, and demonstrate ASL comprehension independently of visible captions.
4. Every pause, stop and interruption test prevents subsequent unauthorized submissions and stale output, including requests racing with state changes.
5. A new contributor can obtain a successful build from documented setup, and each release candidate passes automated checks plus independent code review and physical-device QA.

## 4. Scope and non-goals

### Confirmed launch scope

- Native SwiftUI application on Vision Pro, iPhone and iPad.
- Offline English captions using on-device processing; online ASL translation using Sign MT's existing capabilities.
- Automatic translation of finalized utterances during an explicitly enabled session.
- Persistent, clear pause control that stops sending text while captions continue.
- Skeleton-style signed output, conditional on ASL comprehension testing.
- Clear data-use disclosure and contribution-ready source distribution.

### Non-goals for release 1

1. **Sign-to-speech or video recognition:** a separate inference and capture pipeline; no camera permission is needed for the launch flow.
2. **Offline ASL/Core ML translation:** deferred until suitable models, licenses, device performance and linguistic quality are demonstrated. Core ML is not itself a translation model.
3. **Human-like avatar:** adds rendering, facial-animation and linguistic-validation work beyond the accepted skeleton output.
4. **Other language pairs and group conversation attribution:** require independent coverage and evaluation; no automatic speaker identification or claims of reliable overlapping-speech handling.
5. **Accounts, subscriptions, analytics SDKs, cloud history and cross-device handoff:** unnecessary for the core experience and would expand privacy and operational scope.

Medical, legal, emergency and safety-critical interpretation are not validated use cases. Product copy must describe actual supported behavior rather than reusing the prototype's enterprise/aviation claims.

## 5. Approaches and architecture decision

| Approach | Trade-off | Decision |
| --- | --- | --- |
| Harden the hosted web experience | Smaller initial change; retains remote DOM and browser-state dependency | Not the target architecture |
| Native client with offline captions and online Sign MT translation | Native interaction and testable lifecycle; requires verified service and pose decoding | Selected by owner |
| Fully offline captions and ASL inference | Reduces network dependency; requires a suitable deployable model and separate validation | Future Core ML track |

Shared modules own speech sessions, transcript events, translation contracts and pose data. Platform views adapt presentation without duplicating request/privacy logic. Presentation state is main-actor isolated; audio callback ownership and cancellation must be explicit. Native rendering must preserve the provider's pose timing and handedness; it must not invent missing signs or facial information.

Use Apple frameworks where practical. Preserve existing deployment targets until the capability study establishes the supported matrix. Do not introduce a new backend or provider as an unapproved fallback. The production conversation flow must not depend on JavaScript text injection or manipulation of the hosted page.

## 6. User stories

### Deaf ASL user

- As a Deaf ASL user, I want to choose ASL output so I can follow a hearing person's English speech in my preferred visual modality.
- As a Deaf ASL user, I want to pause online translation without stopping captions so I can keep following speech without sending further text.
- As a Deaf ASL user, I want to replay a completed signed utterance and see its associated text so I can revisit an unclear result.
- As a Deaf ASL user, I want unavailable or delayed translations to be clearly identified so I do not mistake old output for current speech.

### Hard-of-hearing caption user

- As a hard-of-hearing person, I want captions to work without connectivity so a network outage does not interrupt my access to speech.
- As a caption reader, I want readable, adjustable text and access to recent utterances so I can follow at my own pace.
- As a caption reader, I want clear recovery when microphone permission or local recognition is unavailable so I know how to continue.

### Conversation partner and contributor

- As a hearing partner, I want visible recording and translation states so I understand when my speech is being processed or sent externally.
- As a contributor, I want reproducible builds, deterministic service fixtures and documented constraints so I can safely improve the application.

## 7. Session contract

These proposed defaults make the agreed automatic/pause behavior implementable. Validate them with participants before release.

### Independent state

- **Caption session:** idle, preparing, listening, interrupted, failed or ended.
- **ASL transmission:** off, enabled, paused or unavailable. Playback state is separate: idle, waiting, playing or failed.
- One microphone owner and one authoritative conversation session per app process. Additional windows display or control that session rather than starting duplicate recordings. Session identifiers prevent old windows or callbacks from reviving an ended session.

### State transitions

| Action/event | Required behavior |
| --- | --- |
| Start conversation | Check permission and local English recognition readiness. Start captions only. No translation request. |
| Enable ASL | Present provider/data-use disclosure when not yet acknowledged; explicit session enable starts transmission eligibility for future utterances. No prior transcript backlog is sent. |
| Finalized eligible utterance | Submit once, in order, tagged to its session, utterance and transmission epoch. Partial captions remain local. |
| Pause ASL | Close the submission gate before returning UI acknowledgement, invalidate the epoch, discard queued text, request cancellation of in-flight work, stop playback and reject late results. Captions continue. |
| Resume ASL | Open a new epoch. Only new utterances wholly captured after resume are eligible. Do not upload text spoken while paused. |
| Offline/provider failure | Keep captions running. Stop new submissions, discard queued work and show ASL unavailable. Require explicit resume after recovery; no retrospective upload. |
| End session | Stop microphone/recognizer, cancel tasks, clear queued/in-memory conversation content and return to idle. Preferences may remain. |
| App background, device lock or audio interruption | Stop capture and transmission, invalidate pending results and present interrupted state on return. Require explicit restart; no hidden background recording. |

An utterance that crosses an enable, pause, resume or interruption boundary is captioned but not automatically submitted. Recognition adapters must provide capture-generation boundaries or reset segmentation to enforce this. Test delayed final results that contain speech captured before the boundary.

Pause cannot recall a request already handed to the network/provider. The interface must not promise deletion at Sign MT. Playback pause and transmission pause are distinct: launch UI uses **Pause ASL** for both; replaying a cached completed result performs no request and is allowed only while the session remains active.

### Segmentation and bounded work

Proposed initial policy: use finalized recognition segments, not arbitrary partial-word snapshots. Long or continuously spoken input must not create an unbounded request: cap an utterance at 280 Unicode grapheme clusters or 15 seconds and show that it was not translated if a valid final boundary is unavailable. Do not silently truncate or split away negation. Reassess limits against the actual provider contract during feasibility work.

Bound the entire pipeline, including playback: at most two utterances may await their first signed frame in total, whether queued as text, in flight or already translated. Within that bound, allow at most one in-flight request and one ready pose. Do not dispatch while the ready-pose slot is occupied. Active playback is outside the waiting count. Expire waiting work 10 seconds after utterance finalization, including a translated pose that has not started playback; late results for expired work are ignored.

When capacity is full, reject the newly finalized utterance from ASL rather than evicting an earlier one. Explicitly mark each omitted/expired ASL utterance and retain its caption. Preserve ordering among remaining work and never cut an active signed phrase to catch up. Count all playback waiting in first-frame latency and count omissions in the quality metrics. Reserve the three-pose memory allowance for active playback, one ready pose and one replay result; active/pending output takes precedence over replay history. If ordinary conversation repeatedly exceeds these limits, release gates fail; raising queue capacity alone is not a quality fix.

## 8. Requirements and acceptance criteria

### P0 — Required for launch

| ID | Requirement | Testable acceptance criteria | Dependency |
| --- | --- | --- | --- |
| P0-01 | Supported-device readiness | Given a listed device with downloaded English assets, airplane-mode start produces captions. Given missing assets or unsupported recognition, show the exact recovery action and never invoke cloud recognition. Installation prerequisites and tested configurations are published. | Speech API/device feasibility |
| P0-02 | Contextual permissions | Microphone and applicable speech permissions are requested on starting captions, not on app launch. Denial, revocation and restricted state produce recoverable UI with no recording; no camera request occurs. | OS permission behavior |
| P0-03 | Live readable captions | Partial text visibly settles into finalized utterances without duplication across recognizer restarts. Reader scrolling is not forcibly reset; a return-to-live action is available. Caption font size can be increased without clipping controls. | Speech adapter, accessibility |
| P0-04 | Automatic English → ASL | With ASL enabled and available, finalized eligible utterances use English/ASL identifiers and produce associated signed output in order. No network request is triggered by partial captions or repeated rendering of a view. | Verified Sign MT contract |
| P0-05 | Transmission controls | Given a controlled scheduler, pausing before dispatch results in zero dispatches afterward; racing callbacks cannot reopen the gate. Resume never submits paused or pre-enable speech. A request dispatched before pause may complete but cannot change playback. | Session state machine |
| P0-06 | Native skeleton playback | Valid supported pose data renders hands/body and available face data without mirroring meaning or cropping signing space. Invalid, oversized, non-finite or unsupported data produces an error, never fabricated output. Play/pause and local replay work. The ASL evaluation gate passes. | Pose schema, native renderer |
| P0-07 | Independent modality choice | Users can choose captions, signed output or both; caption processing continues while only signs are shown. Hidden captions remain available. ASL-off state requires no external translation connectivity. | Shared session state |
| P0-08 | Failure and overload handling | Offline, timeout, rate limit, authorization failure and malformed responses are distinguishable and recoverable. Queues meet section 7 bounds. Captions continue during ASL failure. No silent fallback provider, resubmission or catch-up upload. | Service adapter |
| P0-09 | Data minimization | Network inspection shows no raw audio/video upload. Text and minimum routing metadata leave only when eligible. No content or transcript-bearing URL appears in app logs, analytics, crash attachments or persistent URL cache. Provider disclosure is accurate. | Provider retention review |
| P0-10 | Ephemeral conversations | No transcript/pose persistence, cloud sync or automatic clipboard writes. Keep at most the latest 10 minutes or 200 finalized utterances, whichever is smaller, in memory, and at most three completed poses within a validated byte budget. End session clears references and temporary files; reopening starts empty. App-switcher previews conceal content. | Storage/caching audit |
| P0-11 | Native cross-device accessibility | Start, enable, pause/resume, replay and end are reachable with touch, VoiceOver, Switch Control and supported keyboard/pointer input. All required states survive compact/regular widths and maximum accessibility text sizes. Vision Pro gaze/pinch operation is validated on hardware. | Design/physical QA |
| P0-12 | Safe lifecycle | Repeated start/stop, cancellation during authorization, interruption, window closure and audio route changes leave no orphan recording, stream or request. Returning to the app requires explicit restart after interruption. | Audio lifecycle tests |
| P0-13 | Quality and operational readiness | Section 10 gates pass for all three platform families; provider access and license are documented. Service disablement leaves captions usable. No unresolved release-blocking defect or unsupported production claim remains. | Quality, owner, provider |
| P0-14 | Public contribution baseline | Accurate README, build guide, architecture, license/provenance notices, privacy policy, contribution/security reporting guides and issue/PR templates exist. CI checks real production behavior; required review/merge policy is configured or its enforcement limitation is documented before publication. | Repository access, licensing |

### P1 — Fast follow-ups, not launch blockers

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| P1-01 | Correct and resubmit a caption | Editing never silently sends text; explicit resubmission replaces only the selected utterance and identifies the corrected result. |
| P1-02 | Adjustable sign playback rate | Validated rate choices preserve intelligibility and timing; default remains the tested normal rate. |
| P1-03 | Optional local history/export | Explicit opt-in, retention and deletion controls, export preview and verified protection from accidental sharing; separate privacy review before implementation. |

### P2 — Later releases

| Track | Required evidence before promotion |
| --- | --- |
| Offline ASL with Core ML | Licensed model/data, reproducible conversion, supported operations, device memory/thermal/latency benchmarks and the same ASL comprehension gate; offline mode cannot silently switch to a remote service. |
| German → Swiss-German Sign Language | Community-reviewed language identity, provider/model coverage and independent language-pair evaluation. |
| Russian → Russian Sign Language | Verified target variant, dataset rights and fluent-user evaluation. |
| Uzbek → local signed language | Work with the intended Deaf community in Uzbekistan to define language/variant and evaluation; do not infer equivalence with Russian Sign Language. |
| Human-like avatar | Licensed rig/assets, preservation of manual and non-manual meaning, improved comprehension demonstrated against skeleton baseline. |
| Bidirectional translation | Separate capture/privacy spec, sign-video evaluation and platform capability verification. |

## 9. Apple-platform experience contract

**Design intent:** a quiet conversation aid where current language output and transmission state are immediately understandable. Caption legibility and visible privacy controls take priority over decorative spatial effects.

These are design requirements, not a claim that the existing UI passes an accessibility audit. Actual contrast, sizing and interaction must be measured in implementation.

- Use native SwiftUI controls, semantic colors and system text styles. Adopt a project minimum of 44 × 44 pt touch targets on iPhone/iPad and 4.5:1 text contrast for all conversation text, including larger text. These deliberately conservative product thresholds apply in light/dark/increased-contrast appearances.
- Support maximum Dynamic Type without clipped captions or inaccessible controls. Use text and symbols together for listening, online, paused and unavailable states; never depend on sound or color alone.
- Expose meaningful VoiceOver names and state values. Avoid announcing every partial transcript update; permit deliberate reading of finalized utterances and configurable announcements. Maintain stable focus as captions change.
- Reduce Motion removes decorative transitions and peripheral movement. Signing motion remains meaningful content, with explicit pause and captions-only alternatives; do not freeze or simplify signs automatically in ways that change meaning. Reduce Transparency supplies a solid legible caption surface.
- iPhone: compact conversation layout, reachable session controls, portrait/landscape support and safe-area compliance. iPad: adapt to available window space and keyboard/pointer input; narrowing a window retains all functions rather than hiding pause controls.
- Vision Pro: proposed launch presentation is a user-positioned window that keeps the physical conversation visible. No required immersive scene, face/person tracking or speaker anchoring. Validate gaze/pinch target acquisition, readable signing distance, adjustable window size and 30-minute comfort on hardware. Spatial assumptions are product judgments until tested, not findings from the mobile design references.
- Starting captions and enabling online translation are separate actions. Show a persistent concise status such as “Captions on device · ASL paused.” Keep **Pause ASL**, **Resume ASL** and **End Conversation** distinct. Common failures use inline text with a recovery action rather than repeated modal alerts.
- Settings contain caption appearance, data-use information and help. Do not add empty tabs, promotional cards or launch-time sign-in. Retain captions-only usefulness when ASL is unavailable.

Reference basis: [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), sections Vision, Hearing, Mobility and Cognitive; [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), Adaptability; [Typography](https://developer.apple.com/design/human-interface-guidelines/typography), Using system fonts; [Color](https://developer.apple.com/design/human-interface-guidelines/color), Inclusive color; [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy), Requesting permission; [Motion](https://developer.apple.com/design/human-interface-guidelines/motion), Best practices; [iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios) and [iPadOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ipados), Best practices.

## 10. Success metrics and release evaluation

**All numeric thresholds below are proposed product hypotheses, not measurements or guarantees.** Freeze the benchmark protocol before collecting release evidence. Record build, OS, device, speech assets, provider version if available, input length, network conditions, and failure counts. Never improve an aggregate by silently excluding failed requests or unsupported phrases.

| Metric | Success threshold | Stretch | Method and evaluation point |
| --- | --- | --- | --- |
| Core-flow task completion | ≥90% unassisted | ≥95% | Moderated pilot: at least 12 Deaf/hard-of-hearing participants, balanced exposure across device families; report counts, denominators and platform-specific failures before release |
| Offline captions | All advertised configurations pass 30-minute airplane-mode conversation tests | Same with audio route changes | Physical-device QA after asset setup; capture and inspect app network activity |
| Partial-caption latency | p95 ≤1 second | ≤0.5 second | From annotated spoken word end to first corresponding visible partial; ≥200 reference utterances per platform, report cold start separately |
| English caption error | WER ≤15% quiet, ≤25% moderate noise | ≤10% / ≤20% | Held-out ≥200 utterances, ≥10 speakers with varied English accents; human transcript reference; quiet SNR ≥25 dB and moderate-noise SNR 10–15 dB; report each condition separately |
| ASL response latency | p95 ≤5 seconds | ≤3 seconds | Eligible utterance finalized to first displayed signed frame, including queueing; ≥200 3–20-word utterances per platform on Wi-Fi with measured RTT ≤100 ms and throughput ≥10 Mbps; report completion time and cellular degradation separately |
| ASL service outcomes | ≥98% eligible submissions produce a valid result; omissions ≤5% in paced conversation | ≥99% / ≤2% | Failures, timeouts and queue drops counted; ≥500 synthetic/consented test utterances across seven days, within approved quota |
| Privacy boundaries | 100% controlled pause/stop/race tests pass; zero content leaks in inspected diagnostics | No weaker target | Deterministic dispatch tests plus physical-device traffic inspection for every candidate |
| Stability | Zero crash/hang or stuck-microphone defects in release suite; ≥99.5% crash-free beta sessions | ≥99.9% | ≥200 consented beta sessions, report statistical limitations; local/system crash reports and explicit study reporting, no content analytics SDK |
| Sustained use | Thirty minutes with no serious/critical thermal state and no latency-gate regression | Sixty minutes | Oldest supported and representative current hardware, per-platform memory/battery profile and lifecycle traces |

### ASL intelligibility gate

Recruit at least eight Deaf fluent ASL users, with compensation and informed consent, and involve an ASL linguist or qualified evaluator in protocol design. Use 120 held-out everyday messages balanced across questions, negation, numbers, time, directions, requests and short social exchanges. Include unsupported names/phrases and report them, rather than narrowing the set after observing results.

Each message receives at least three independent evaluations. Evaluate signed output **without source captions first**, followed by the combined experience separately; visible English must not conceal unintelligible signing. Randomize presentation order and use comprehension questions or meaning paraphrases scored against a pre-agreed rubric.

Proposed pass: ≥85% meaning comprehension overall, ≥80% in each semantic category and zero observed severe meaning reversals involving negation, quantities or direction. Report participant-level spread, disagreements and uncertainty; zero observed reversals does not establish universal safety. Two evaluators adjudicate severe errors. A failed skeleton gate blocks the advertised ASL release; improve integration, narrow and revalidate the claimed domain, or explicitly re-scope with the owner. Do not label unvalidated gestures as successful translation.

### Leading and lagging indicators after release

- **Leading, first two weeks:** study participants' time to first captions ≤30 seconds after permissions/assets are ready; ≥90% correctly explain what Pause ASL does; service error and queue-drop rates remain within the benchmark envelope.
- **Lagging, four weeks:** proposed ≥60% of enrolled pilot users voluntarily use the app in at least two conversations per week and median usefulness ≥4/5. Measure through opt-in diaries/interviews, report attrition and raw denominators. These are product-learning targets, not automatic launch blockers.
- No covert engagement tracking. Performance timings must be content-free, collected locally for tests or with explicit beta participation consent, and aggregated before publication.

## 11. Sign MT integration and operations

The inspected upstream source constructs a `spoken_text_to_signed_pose` request with text, spoken-language and signed-language parameters, and separately supports a SignWriting request path. This demonstrates upstream usage, not permission for unlimited third-party production traffic. Language lists alone do not establish quality or coverage.

Before integration is declared production-ready, document the authorized endpoint, exact request/response schema and pose format, supported language codes, maximum input/output sizes, error semantics, quota, timeout behavior, version/change policy, content retention and applicable licensing. Pin an inspected upstream revision for reproducible fixtures. Use synthetic phrases for automated contract tests, never unsuspecting conversation content.

The current pose integration places text in the URL query. Avoid transcript-bearing URLs in logs, disk caches, telemetry and support reports. Confirm provider/proxy URL logging and retention before writing privacy promises. HTTPS does not prevent server-side logging. If provider access or privacy requirements cannot be met, this is a release blocker rather than a reason to silently use another service.

Proposed network defaults: 15-second transport timeout, one active request, no automatic resubmission of conversation text, and explicit recovery after 429/5xx/authorization errors. The 10-second utterance expiry is an earlier user-experience deadline: cancel expired work and ignore completion even if transport cancellation is delayed. Respect provider Retry-After before allowing a new attempt. Validate redirects against the approved endpoint allowlist and reject insecure schemes. Limit response size and pose allocation before parsing; establish numeric byte/frame limits from real fixtures in the feasibility phase.

Owner maintains a provider failure playbook: reproduce with synthetic input, inspect content-free error rates, disable ASL when unsafe or unusable, inform users while captions remain available, and revalidate after provider changes. A bundled feature gate and app update are sufficient initially; any remote configuration must be authenticated, contain no conversation content and never turn transmission on without user action.

Release checklist includes support contact, security-reporting channel, dependency/license inventory, privacy policy and App Store disclosures matched to actual data handling, reproducible build instructions, rollback/disable procedure and signed physical-device verification. No availability SLA is advertised without supporting evidence and an operational agreement.

## 12. Delivery phases and GitHub work packages

No hard deadline or budget has been supplied. Dates should follow feasibility results, not precede them. All three platform families are launch scope; staged TestFlight builds are acceptable but a partial platform release needs an explicit scope decision.

| Phase | Separate issue/PR candidates | Exit gate |
| --- | --- | --- |
| A — Feasibility and specification | Provider contract/provenance; offline speech device matrix; pose decode/render spike; frozen evaluation protocol | Owner-approved PRD, documented service access, offline captions feasible on each platform and a decodable ASL result; otherwise report blocker |
| B — Repository foundation | Accurate documentation and contribution flow; package path repair; CI for app/packages; baseline privacy cleanup | Reproducible builds and real behavioral tests on equipped runners |
| C — Conversation core | Speech lifecycle; utterance segmentation; epoch-based transmission gate; privacy state UI | P0-01–05, 09–10, 12 pass under deterministic failure/race tests |
| D — Native experience | Sign MT adapter; native skeleton renderer; adaptive iPhone/iPad/visionOS views; accessibility | P0-06–08 and 11 pass on hardware, no production DOM bridge |
| E — Validation and release | ASL study; sustained-use QA; service monitoring/playbook; license/privacy review; portfolio screenshots | All P0s and release gates pass with traceable evidence and independent review |

Create real GitHub issues before assigning identifiers. Use `mrst-<issue number>` branches and `type(scope): [MRST-<issue number>] description` commits/PR titles. Feature PRs target `develop`; require passing checks and at least one independent review, then squash merge. Do not recycle branches; suffix follow-up branches numerically. Release PRs target `main`, use `chore: release`, merge commits and no release tagging. Preserve existing history and upstream attribution.

GitHub repository write access is an operational dependency for publishing these work packages; missing access does not prevent local specification work. No issue IDs or PR links are fabricated here. A separate implementation plan follows PRD approval.

## 13. Open questions and decision owners

| Question | Owner | Blocking point | Current proposal |
| --- | --- | --- | --- |
| Which Sign MT deployment permits this application's production use, at what quota/cost and retention? | Project owner + provider | Live integration/release | Existing Sign MT capabilities; no new hosting or paid commitment assumed |
| Which minimum OS/hardware combinations meet offline speech, rendering and thermal gates? | Engineering | Final platform promise | Capability study on all three families; do not guess support from package declarations |
| What pose schema, size/frame limits and signing features does the deployed service actually return? | Engineering + provider | Native renderer acceptance | Use verified fixtures and reject unsupported results |
| Which original-code license and third-party notices permit intended distribution? | Owner + licensing reviewer | Public distribution | Inventory first; preserve Sign MT terms, avoid blanket relicensing |
| Who recruits/compensates ASL evaluators and approves the proposed thresholds? | Owner + Deaf ASL evaluation lead | Study and release | Section 10 protocol; costs and schedule not yet authorized |
| Is the public release free, and which territories are intended? | Owner | Store/legal submission | No monetization implementation or distribution assumptions in v1 |
| Final product name: MRSignTranslate or thesis name SRay? | Owner/design | Store assets, non-blocking for engineering | Retain repository name for now |

Engineering may choose internal type names, test organization and implementation details that satisfy the contracts. Proposed queue, timeout, memory and quality thresholds require evidence before being changed; record rationale and owner acceptance for any relaxation of user-visible quality or privacy guarantees.

## 14. Definition of ready to release

- [ ] Every P0 has test evidence and an accountable reviewer; no open critical/high correctness, privacy or accessibility defect.
- [ ] Offline-caption support matrix is verified on physical devices, including installation prerequisites and denied-permission paths.
- [ ] English-to-ASL skeleton output passes independent comprehension and latency gates.
- [ ] Pause/resume/stop semantics pass race tests and traffic inspection; no conversation retention or content logging.
- [ ] Provider access, quotas, retention, licensing and failure handling are documented and accurate in user disclosures.
- [ ] Native iPhone, iPad and Vision Pro flows pass accessibility, resize, interruption and sustained-use QA.
- [ ] CI, independent review, reproducible setup, contribution documentation and third-party notices are complete.
- [ ] Release owner has reviewed actual screenshots, known limitations, privacy disclosures and support/rollback procedures.

## Evidence and references

- [Architecture review](prototype-review.md): source findings and unsigned visionOS build baseline.
- [Thesis](https://github.com/azizbek-asadovnzzemu/MRSignTranslate-Thesis-Overleaf): chapters 4–6; prototype design, evaluation limitations and improvements.
- [Sign MT translation service](https://github.com/sign/translate/blob/master/src/app/modules/translate/translate.service.ts) and [SignWriting service](https://github.com/sign/translate/blob/master/src/app/modules/translate/signwriting-translation.service.ts): inspected integration paths, not a verified production service agreement.
- [Sign MT license](https://github.com/sign/translate/blob/master/LICENSE.md): noncommercial/share-alike and separate commercial terms; distribution decision remains open.
