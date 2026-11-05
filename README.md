# SRay

Native conversation accessibility for Vision Pro, iPhone and iPad.

**Status: planning and implementation foundation. No runnable production app is included yet.**

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

Clone this repository and check out `develop` for contribution work. The initial repository contains requirements and community infrastructure; platform targets and executable build/test commands will be added through the foundation issues. Do not interpret documentation checks as app tests.

```sh
git clone https://github.com/azizbek-asadovnzzemu/SRay.git
cd SRay
git switch develop
```

The [MRSignTranslate prototype](https://github.com/azizbek-asadovnzzemu/MRSignTranslate) is a separate reference project. Its source, archives and third-party assets have not been copied into this repository. Importing any reusable material requires a provenance review and preserved notices.

## Roadmap

Release 1 targets English captions and ASL on all three platforms. Offline ASL with Core ML, human-like avatars, bidirectional translation, German/DSGS, Russian/Russian Sign Language and Uzbek/local signed language are later work. Language support requires community evaluation, not only a language selector.

## License

Original SRay material is licensed under [Apache-2.0](LICENSE). This does not license Sign MT services, models or assets; their terms remain separate. See [third-party notices](THIRD_PARTY_NOTICES.md). No interpreter-equivalence or validated emergency-use claim is made.
