# SRay

Native conversation accessibility for Vision Pro, iPhone and iPad.

**Status: pre-release. The `develop` branch builds a native English captions app. ASL output remains unavailable while provider access, rendering and comprehension are evaluated.**

SRay will help Deaf and hard-of-hearing people follow everyday one-to-one conversations through offline English captions and optional online English-to-ASL translation using Sign MT. Users explicitly enable translation and can pause transmission while captions continue. Skeleton output must pass ASL comprehension testing before release.

## Start here

- [Product requirements](docs/production-prd.md)
- [Issue roadmap](docs/ROADMAP.md)
- [Contributing](CONTRIBUTING.md)
- [Governance](GOVERNANCE.md)
- [Security reporting](SECURITY.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Third-party provenance](THIRD_PARTY_NOTICES.md)

## Development

Clone `develop` for the current app and contribution work. Use full Xcode with the iOS and visionOS SDKs. The project uses a local Swift package and builds without a signing team for SDK checks.

```sh
git clone --branch develop https://github.com/azizbek-asadovnzzemu/SRay.git
cd SRay
python3 scripts/apple_ci.py ios
python3 scripts/apple_ci.py visionos
python3 scripts/apple_ci.py packages
```

The commands above passed in a clean checkout of `develop` at `7f569da` with Xcode 27.2, including 57 Swift test functions. Hosted CI separately checks the configured toolchain.

Open `SRay.xcodeproj` and run `SRay-iOS` on an iPhone or iPad simulator. Start Conversation requests microphone and speech access when invoked. English recognition requires an on-device recognizer and available language assets. Follow the [native build guide](docs/development/native-app.md) and [captions guide](docs/development/live-captions.md).

| Area | Current evidence |
| --- | --- |
| iPhone and iPad | Native app and packages compile for iOS 17. Simulator launch and start-screen layout were checked with iOS 27.0. |
| Vision Pro | Native app and packages compile for visionOS 2. Device comfort, input and live caption capture still need hardware testing. |
| Speech and translation | Swift Testing covers session behavior and synthetic transport data. [Offline capture](docs/feasibility/offline-speech.md) and [ASL evaluation](docs/research/evaluation-protocol.md) remain release gates. |

The [MRSignTranslate prototype](https://github.com/azizbek-asadovnzzemu/MRSignTranslate) is a separate reference project. Its source, archives and third-party assets have not been copied into this repository. Importing any reusable material requires a provenance review and preserved notices.

## Roadmap

Release 1 targets English captions and ASL on all three platforms. Offline ASL with Core ML, human-like avatars, bidirectional translation, German/DSGS, Russian/Russian Sign Language and Uzbek/local signed language are later work. Language support requires community evaluation, not only a language selector.

## License

Original SRay material is licensed under [Apache-2.0](LICENSE). This does not license Sign MT services, models or assets; their terms remain separate. See [third-party notices](THIRD_PARTY_NOTICES.md). No interpreter-equivalence or validated emergency-use claim is made.
