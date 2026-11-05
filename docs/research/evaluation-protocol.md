# Caption and ASL evaluation protocol

Version 0.1 proposal — issue #6. **Not frozen, not executed, no passing result claimed.**

This operationalizes section 10 of the [PRD](../production-prd.md). The owner and a Deaf fluent-ASL evaluation lead must approve the protocol, sample selection, compensation and thresholds before recruitment or release measurement. No participants have been recruited and no expenditure is authorized by this document.

## Freeze record

Before execution, record protocol version/hash, app revision, test build, target hardware/OS, English locale and installed speech assets, provider/decoder version (or explicit unknown), corpus manifest hashes, randomization seed, rubric revision, threshold decisions, evaluation lead and owner approval dates. Store the approved record alongside the eventual anonymized report. Any post-freeze change needs a new version and reason; do not select a favorable subset after observing results.

## Caption corpus

Use at least 200 held-out utterances and at least ten speakers with varied English accents. Separate development examples from the evaluation manifest before tuning. Obtain permission for recording and the exact intended use; public redistribution needs separate explicit permission. Keep recordings and identifying material outside this public repository.

Test quiet SNR at least 25 dB and moderate noise SNR 10–15 dB as separate conditions, recording calibration and microphone distance. Use human-verified references with spoken-word end timestamps. Freeze case, punctuation, number and contraction normalization before scoring. Calculate word error rate as (substitutions + deletions + insertions) / reference words; report numerators and denominators, not only percentages. Do not cap WER at 100%.

For each advertised platform, report partial-caption latency from reference word end to first corresponding visible partial. Track incorrect or missing partials separately. Report cold starts separately. Proposed gates remain p95 at most one second, WER at most 15% quiet and 25% moderate noise. At least 200 reference utterances per platform are required. Missing recognition results contribute deletions and explicit failures; do not discard them.

Perform the 30-minute disconnected session and network inspection on physical iPhone, iPad and Vision Pro after asset setup. Record oldest supported and representative current hardware. Compilation, an API capability flag and simulator execution do not establish this gate.

## ASL corpus and recruitment

Recruit at least eight Deaf fluent ASL users with informed consent and compensation. An ASL linguist or qualified evaluator must co-design the rubric. Record inclusion criteria and relevant language experience without publishing identities. Participants may withdraw without losing agreed compensation. Provide accessible consent and support in their preferred communication form.

Use 120 held-out everyday messages: questions (18), negation (18), numbers (18), time (17), directions (17), requests (16), short social exchanges (16). This allocation is a proposal for the lead to approve. Include unsupported names/phrases in the predetermined manifest and report failure; do not remove hard examples after translation. Prepare expected semantic units and severe-error conditions before viewing system output.

Each message receives at least three independent evaluations (at least 360 ratings). Balance assignments across participants and categories; randomize with a recorded seed. Avoid assigning only easy items to one evaluator. Obtain ratings of signing without visible English first. Run the combined-caption experience separately, after independent signing ratings are locked.

Ask for a meaning paraphrase or comprehension answers; avoid yes/no “did you understand?” ratings alone. Predefine required semantic units and score a message as comprehended only when all critical units are correct. Preserve partial-unit scores for diagnosis but do not substitute them for the message-level pass rate. Report participant-level and category results, disagreements and missing ratings. Missing ratings require a predefined replacement procedure or leave the gate unassessed; they cannot silently improve the result.

Two evaluators adjudicate suspected severe reversals of negation, quantity or direction. Record independent judgments before discussion, a short non-identifying rationale and resolution. Unresolved severe-error disputes block the gate. Do not average a severe reversal away.

Proposed gates: at least 85% comprehended message-ratings overall, at least 80% in each category, and zero observed severe reversals. Report raw denominators and participant/message clustering when estimating uncertainty. Zero observed reversals is not a general safety guarantee. A failed skeleton gate blocks advertised ASL release; changes require another held-out evaluation.

## Service performance and usability

Within approved service quotas, use at least 200 3–20-word utterances per platform for latency. Record Wi-Fi RTT at most 100 ms and throughput at least 10 Mbps, plus a separate cellular/degradation condition. Measure finalization to first visible signed frame, including queue time; completion time is a separate metric. Treat omissions/timeouts as failures, with success-conditioned latency explicitly labeled. Report the fraction of all eligible utterances reaching first frame within five seconds so missing results cannot disappear from the latency account.

For reliability, measure at least 500 synthetic/consented utterances over seven days. Report service success (proposed at least 98%) and paced-conversation omissions (at most 5%) with eligible denominators, queue drops and timeouts. Never send study content before provider disclosure/consent. Provider access, retention and output rights must be resolved in #2.

Recruit at least 12 Deaf/hard-of-hearing participants for start, enable ASL, pause ASL and end-session tasks. Record assistance and platform-specific failures. Proposed task completion is at least 90% unassisted. Confirm that participants can explain that pausing stops future text transmission while captions continue locally; it cannot retract text already sent.

## Privacy and records

Consent must identify recording, remote processing/logging, purpose, access, storage location, retention/deletion date and withdrawal limits. Owner and lead must select actual retention periods and compensation before recruitment. Keep identity/contact/consent records separate from pseudonymous measurements with restricted access. Publish aggregate results and synthetic examples only unless separate permission permits more. Do not put recordings, transcript text, participant names or service URLs containing text in issue reports, CI artifacts or logs.

The public measurement schema is metadata only: protocol_version, run_id, app_revision, platform, os_build, device_class, corpus_item_id, semantic_category, condition, outcome, latency_ms, failure_kind. ASL ratings use item_id, pseudonymous_rater_id, comprehension_pass, severe_error_candidate, adjudication_status. A real study's linked rows can still identify people; review release data for re-identification before publishing. No empty measurement table should be presented as a result.

## Engineering and Swift verification

Inject clock, speech and translation dependencies at boundaries; the conversation reducer owns session and dispatch state. Swift Testing tests should prove cancellation, late-callback rejection, pause/stop privacy and bounded queue behavior using production components. Parameterize independent scenarios; keep time deterministic and exclude real network/microphone work from unit suites. Name measurement APIs by their actual event (finalized, dispatched, first frame), document units, and distinguish missing values from zero latency. No benchmark implementation is included in this protocol PR.

## Decision and unresolved work

Issue #6 stays open until the owner and evaluation lead approve a frozen protocol and corpus, provider and device feasibility are established, recruitment/consent/compensation are agreed, and baseline collection can be scheduled. Results must identify pass, fail or unassessed per gate; an unassessed gate never counts as a pass.
