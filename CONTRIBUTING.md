# Contributing to SRay

Contributions from Deaf and hard-of-hearing people, ASL users, designers, researchers and engineers are welcome. Please follow the [code of conduct](CODE_OF_CONDUCT.md).

## Before starting

Read the PRD, linked issue and [engineering conventions](docs/ENGINEERING.md). Discuss scope changes in an issue before implementation. Never post private conversations, participant recordings, access tokens or identifiable study data. Use synthetic examples and fixtures. For vulnerabilities use the private route in SECURITY.md.

## Branches and commits

`main` is the release branch; `develop` is integration/staging. These names do not imply deployments already exist. Create one branch per issue, `mrst-<number>`, from develop. Do not recycle branches; use `mrst-<number>-1` for follow-up work.

Use Conventional Commit titles with the issue identifier:

`feat(captions): [MRST-42] preserve finalized utterance order`

Scopes are optional; use a concise affected area such as captions, translation, playback, privacy, accessibility, ios, ipados, visionos, ci or docs. The project title validator is the executable convention. No release tags are used.

## Pull requests

Target develop, describe behavior and reference `Closes #<number>` only when all acceptance criteria are met. Include exact validation performed and limitations. Small focused PRs are preferred. New behavior needs tests against production components, including failures and cancellation; mock-only tests do not establish correctness.

A passing CI run and at least one independent approval are required before squash merging. Reviewers should run relevant checks locally and record the result. Do not approve or merge your own changes to bypass this requirement. Release PRs go from develop to main, are titled `chore: release`, and use a merge commit. GitHub permits both methods, so maintainers must choose the method appropriate to the PR.

## Accessible and reproducible work

Keep captions and privacy controls usable with accessibility text sizes and alternative input. Preserve on-device processing guarantees. Record device/OS/build for hardware checks. Use synthetic input for integration tests. Include provenance and license details for every dependency, model or asset.

By intentionally submitting original contributions, you agree to license them under Apache-2.0 as described in LICENSE. Preserve existing copyright and third-party notices. You must have the right to contribute submitted material. No CLA or mandatory sign-off is currently required.
