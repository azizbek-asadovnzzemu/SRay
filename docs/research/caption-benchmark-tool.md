# Scoring an offline caption benchmark

Issue #23. This tool scores prepared observations. The caption benchmark still requires a frozen protocol, consented held-out corpus and physical device measurements.

Feed one condition at a time. Keep quiet/noise conditions, each platform, and cold starts separate. Apply the normalization approved in the [evaluation protocol](../research/evaluation-protocol.md) before tokenizing utterances. Keep the input outside the public repository.

```sh
swift run --package-path Tools/CaptionBenchmark caption-benchmark < private-batch.json
```

Synthetic input example:

```json
{
  "utterances": [
    {"reference": ["wait", "outside"], "hypothesis": ["wait", "inside"]},
    {"reference": ["please", "continue"], "hypothesis": null}
  ],
  "wordObservations": [
    {"spokenWordEndMilliseconds": 100, "firstVisiblePartialMilliseconds": 250},
    {"spokenWordEndMilliseconds": 400, "firstVisiblePartialMilliseconds": null}
  ]
}
```

Use the same monotonic origin for the end of each spoken word and the appearance of its first correct partial. Both timestamps must be nonnegative. The scorer subtracts word end from appearance time, so a correct partial visible before the word ends contributes negative latency. Supply a null partial time when no correct partial appears. A null hypothesis means recognition failed. The scorer counts all its reference words as deletions. An empty hypothesis array is a valid empty result and also contributes deletions.

The word error rate is the total number of substitutions, deletions and insertions divided by the total reference word count. It can exceed one. The nearest-rank p95 uses all word observations, with missing partials ranked after finite delays. The displayed-only p95 is reported separately. A percentile that cannot be computed or falls in the missing tail is absent from the JSON, with missing counts still reported.

The tool reads at most 8 MiB, accepts at most 512 tokens per utterance side, and limits total alignment work. Standard output contains aggregate counts and optional statistics, with no input text or per-word timing. Preserve the approved conditions and device evidence separately. Compare against release thresholds only after the protocol is frozen.
