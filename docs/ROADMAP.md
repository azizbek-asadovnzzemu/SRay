# Roadmap

Issues are the execution backlog. P0 items belong to release 1; P1/P2 items are later work. A closed issue requires its acceptance evidence. Milestones group work without promising dates.

## Feasibility

| Issue | Priority | Dependencies |
| --- | --- | --- |
| [#2 Verify Sign MT production access and service contract](https://github.com/azizbek-asadovnzzemu/SRay/issues/2) | P0 | [#1](https://github.com/azizbek-asadovnzzemu/SRay/issues/1) |
| [#3 Audit prototype, dependencies and assets before source migration](https://github.com/azizbek-asadovnzzemu/SRay/issues/3) | P0 | [#1](https://github.com/azizbek-asadovnzzemu/SRay/issues/1) |
| [#4 Validate offline English speech support on all platforms](https://github.com/azizbek-asadovnzzemu/SRay/issues/4) | P0 | [#1](https://github.com/azizbek-asadovnzzemu/SRay/issues/1) |
| [#5 Validate pose decoding and native rendering feasibility](https://github.com/azizbek-asadovnzzemu/SRay/issues/5) | P0 | [#2](https://github.com/azizbek-asadovnzzemu/SRay/issues/2) |
| [#6 Freeze caption and ASL evaluation protocol](https://github.com/azizbek-asadovnzzemu/SRay/issues/6) | P0 | [#2](https://github.com/azizbek-asadovnzzemu/SRay/issues/2), [#4](https://github.com/azizbek-asadovnzzemu/SRay/issues/4), [#5](https://github.com/azizbek-asadovnzzemu/SRay/issues/5) |

## Foundation

| Issue | Priority | Dependencies |
| --- | --- | --- |
| [#1 Establish open-source repository and contribution governance](https://github.com/azizbek-asadovnzzemu/SRay/issues/1) | P0 | None |
| [#7 Create native Apple application targets and shared modules](https://github.com/azizbek-asadovnzzemu/SRay/issues/7) | P0 | [#3](https://github.com/azizbek-asadovnzzemu/SRay/issues/3), [#4](https://github.com/azizbek-asadovnzzemu/SRay/issues/4) |
| [#8 Add reproducible builds and behavior tests to CI](https://github.com/azizbek-asadovnzzemu/SRay/issues/8) | P0 | [#7](https://github.com/azizbek-asadovnzzemu/SRay/issues/7) |

## Conversation core

| Issue | Priority | Dependencies |
| --- | --- | --- |
| [#9 Implement isolated speech lifecycle and permission handling](https://github.com/azizbek-asadovnzzemu/SRay/issues/9) | P0 | [#7](https://github.com/azizbek-asadovnzzemu/SRay/issues/7) |
| [#10 Implement finalized utterance identity and segmentation](https://github.com/azizbek-asadovnzzemu/SRay/issues/10) | P0 | [#9](https://github.com/azizbek-asadovnzzemu/SRay/issues/9) |
| [#11 Enforce automatic ASL enable, pause and resume boundaries](https://github.com/azizbek-asadovnzzemu/SRay/issues/11) | P0 | [#10](https://github.com/azizbek-asadovnzzemu/SRay/issues/10) |
| [#13 Bound translation and playback queues end to end](https://github.com/azizbek-asadovnzzemu/SRay/issues/13) | P0 | [#11](https://github.com/azizbek-asadovnzzemu/SRay/issues/11), [#12](https://github.com/azizbek-asadovnzzemu/SRay/issues/12), [#5](https://github.com/azizbek-asadovnzzemu/SRay/issues/5) |
| [#15 Implement disclosures and visible transmission controls](https://github.com/azizbek-asadovnzzemu/SRay/issues/15) | P0 | [#11](https://github.com/azizbek-asadovnzzemu/SRay/issues/11), [#2](https://github.com/azizbek-asadovnzzemu/SRay/issues/2) |
| [#16 Enforce ephemeral content and diagnostic redaction](https://github.com/azizbek-asadovnzzemu/SRay/issues/16) | P0 | [#7](https://github.com/azizbek-asadovnzzemu/SRay/issues/7), [#12](https://github.com/azizbek-asadovnzzemu/SRay/issues/12) |
| [#21 Validate background, audio-route and interruption recovery](https://github.com/azizbek-asadovnzzemu/SRay/issues/21) | P0 | [#9](https://github.com/azizbek-asadovnzzemu/SRay/issues/9), [#11](https://github.com/azizbek-asadovnzzemu/SRay/issues/11), [#18](https://github.com/azizbek-asadovnzzemu/SRay/issues/18), [#19](https://github.com/azizbek-asadovnzzemu/SRay/issues/19), [#20](https://github.com/azizbek-asadovnzzemu/SRay/issues/20) |

## Native experience

| Issue | Priority | Dependencies |
| --- | --- | --- |
| [#12 Implement typed Sign MT translation adapter](https://github.com/azizbek-asadovnzzemu/SRay/issues/12) | P0 | [#2](https://github.com/azizbek-asadovnzzemu/SRay/issues/2), [#7](https://github.com/azizbek-asadovnzzemu/SRay/issues/7) |
| [#14 Implement native skeleton playback with local replay](https://github.com/azizbek-asadovnzzemu/SRay/issues/14) | P0 | [#5](https://github.com/azizbek-asadovnzzemu/SRay/issues/5), [#7](https://github.com/azizbek-asadovnzzemu/SRay/issues/7) |
| [#17 Build readable live captions and modality selection](https://github.com/azizbek-asadovnzzemu/SRay/issues/17) | P0 | [#10](https://github.com/azizbek-asadovnzzemu/SRay/issues/10), [#7](https://github.com/azizbek-asadovnzzemu/SRay/issues/7) |
| [#18 Build adaptive iPhone conversation experience](https://github.com/azizbek-asadovnzzemu/SRay/issues/18) | P0 | [#17](https://github.com/azizbek-asadovnzzemu/SRay/issues/17), [#15](https://github.com/azizbek-asadovnzzemu/SRay/issues/15), [#13](https://github.com/azizbek-asadovnzzemu/SRay/issues/13), [#14](https://github.com/azizbek-asadovnzzemu/SRay/issues/14) |
| [#19 Build resizable iPad conversation experience](https://github.com/azizbek-asadovnzzemu/SRay/issues/19) | P0 | [#17](https://github.com/azizbek-asadovnzzemu/SRay/issues/17), [#15](https://github.com/azizbek-asadovnzzemu/SRay/issues/15), [#13](https://github.com/azizbek-asadovnzzemu/SRay/issues/13), [#14](https://github.com/azizbek-asadovnzzemu/SRay/issues/14) |
| [#20 Build native Vision Pro conversation windows](https://github.com/azizbek-asadovnzzemu/SRay/issues/20) | P0 | [#17](https://github.com/azizbek-asadovnzzemu/SRay/issues/17), [#15](https://github.com/azizbek-asadovnzzemu/SRay/issues/15), [#13](https://github.com/azizbek-asadovnzzemu/SRay/issues/13), [#14](https://github.com/azizbek-asadovnzzemu/SRay/issues/14) |

## Validation

| Issue | Priority | Dependencies |
| --- | --- | --- |
| [#22 Audit complete accessibility flows across all platforms](https://github.com/azizbek-asadovnzzemu/SRay/issues/22) | P0 | [#18](https://github.com/azizbek-asadovnzzemu/SRay/issues/18), [#19](https://github.com/azizbek-asadovnzzemu/SRay/issues/19), [#20](https://github.com/azizbek-asadovnzzemu/SRay/issues/20) |
| [#23 Benchmark offline caption accuracy and latency](https://github.com/azizbek-asadovnzzemu/SRay/issues/23) | P0 | [#6](https://github.com/azizbek-asadovnzzemu/SRay/issues/6), [#21](https://github.com/azizbek-asadovnzzemu/SRay/issues/21) |
| [#24 Validate ASL skeleton comprehension with Deaf fluent users](https://github.com/azizbek-asadovnzzemu/SRay/issues/24) | P0 | [#6](https://github.com/azizbek-asadovnzzemu/SRay/issues/6), [#14](https://github.com/azizbek-asadovnzzemu/SRay/issues/14), [#18](https://github.com/azizbek-asadovnzzemu/SRay/issues/18), [#19](https://github.com/azizbek-asadovnzzemu/SRay/issues/19), [#20](https://github.com/azizbek-asadovnzzemu/SRay/issues/20) |
| [#25 Run sustained-use, latency and beta reliability validation](https://github.com/azizbek-asadovnzzemu/SRay/issues/25) | P0 | [#23](https://github.com/azizbek-asadovnzzemu/SRay/issues/23), [#24](https://github.com/azizbek-asadovnzzemu/SRay/issues/24), [#22](https://github.com/azizbek-asadovnzzemu/SRay/issues/22), [#21](https://github.com/azizbek-asadovnzzemu/SRay/issues/21) |
| [#26 Document service outage, security and release response](https://github.com/azizbek-asadovnzzemu/SRay/issues/26) | P0 | [#12](https://github.com/azizbek-asadovnzzemu/SRay/issues/12), [#15](https://github.com/azizbek-asadovnzzemu/SRay/issues/15) |
| [#27 Review licensing, privacy and distribution readiness](https://github.com/azizbek-asadovnzzemu/SRay/issues/27) | P0 | [#3](https://github.com/azizbek-asadovnzzemu/SRay/issues/3), [#2](https://github.com/azizbek-asadovnzzemu/SRay/issues/2), [#16](https://github.com/azizbek-asadovnzzemu/SRay/issues/16), [#26](https://github.com/azizbek-asadovnzzemu/SRay/issues/26) |
| [#28 Publish reproducible setup, real screenshots and release evidence](https://github.com/azizbek-asadovnzzemu/SRay/issues/28) | P0 | [#8](https://github.com/azizbek-asadovnzzemu/SRay/issues/8), [#25](https://github.com/azizbek-asadovnzzemu/SRay/issues/25), [#27](https://github.com/azizbek-asadovnzzemu/SRay/issues/27) |
| [#29 Complete release checklist and reviewed develop-to-main promotion](https://github.com/azizbek-asadovnzzemu/SRay/issues/29) | P0 | [#28](https://github.com/azizbek-asadovnzzemu/SRay/issues/28), [#26](https://github.com/azizbek-asadovnzzemu/SRay/issues/26), [#27](https://github.com/azizbek-asadovnzzemu/SRay/issues/27), [#25](https://github.com/azizbek-asadovnzzemu/SRay/issues/25) |

## Later

| Issue | Priority | Dependencies |
| --- | --- | --- |
| [#30 Add explicit caption correction and resubmission](https://github.com/azizbek-asadovnzzemu/SRay/issues/30) | P1 | [#29](https://github.com/azizbek-asadovnzzemu/SRay/issues/29) |
| [#31 Add validated signing playback-rate controls](https://github.com/azizbek-asadovnzzemu/SRay/issues/31) | P1 | [#29](https://github.com/azizbek-asadovnzzemu/SRay/issues/29) |
| [#32 Design opt-in local history and export](https://github.com/azizbek-asadovnzzemu/SRay/issues/32) | P1 | [#29](https://github.com/azizbek-asadovnzzemu/SRay/issues/29) |
| [#33 Evaluate offline ASL inference with Core ML](https://github.com/azizbek-asadovnzzemu/SRay/issues/33) | P2 | [#29](https://github.com/azizbek-asadovnzzemu/SRay/issues/29) |
| [#34 Evaluate German to Swiss-German Sign Language](https://github.com/azizbek-asadovnzzemu/SRay/issues/34) | P2 | [#29](https://github.com/azizbek-asadovnzzemu/SRay/issues/29) |
| [#35 Evaluate Russian to Russian Sign Language](https://github.com/azizbek-asadovnzzemu/SRay/issues/35) | P2 | [#29](https://github.com/azizbek-asadovnzzemu/SRay/issues/29) |
| [#36 Define Uzbek input and local signed-language support with community](https://github.com/azizbek-asadovnzzemu/SRay/issues/36) | P2 | [#29](https://github.com/azizbek-asadovnzzemu/SRay/issues/29) |
| [#37 Evaluate human-like signing avatar](https://github.com/azizbek-asadovnzzemu/SRay/issues/37) | P2 | [#29](https://github.com/azizbek-asadovnzzemu/SRay/issues/29) |
| [#38 Specify sign-to-spoken bidirectional translation](https://github.com/azizbek-asadovnzzemu/SRay/issues/38) | P2 | [#29](https://github.com/azizbek-asadovnzzemu/SRay/issues/29) |

