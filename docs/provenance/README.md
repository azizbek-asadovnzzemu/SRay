# Prototype provenance review

Reviewed 5 November 2026. Source: [MRSignTranslate](https://github.com/azizbek-asadovnzzemu/MRSignTranslate), commit `66c76d6`. The CSV records all 498 tracked paths and Git blob hashes without reproducing source or configuration values.

## Findings

- 173 Swift files are tracked. 168 have an Azizbek Asadov author header; five do not. Headers are evidence of authorship claims, not a guarantee that every incorporated algorithm or asset is original.
- The reviewed root has no license. The owner's Apache-2.0 choice applies to original SRay work; it does not resolve third-party material in the prototype.
- Bundled web distributions appear in multiple directories and in `src/dist.zip`. The ZIP contains 14 entries, including filesystem metadata. Do not import these artifacts.
- Images and RealityKit resources have no established file-level rights in this review. Keep them out until their provenance is documented.
- Environment configuration contains upstream service identifiers. Do not copy configuration values into SRay or mistake public client configuration for authorization to use a service.
- The prototype depends on swift-log. Resolve its exact version and preserve its own license if SRay adopts it; the native architecture does not currently need that dependency.

## Import decision

**Approved source/asset import allowlist: empty.** No source file, image, scene or distribution is approved for wholesale copying by this review. This is a deliberate migration boundary, not a claim that the owner lacks rights to their own work.

Proceed with independently written SRay modules implementing the PRD. Reuse product knowledge and public API concepts; do not transplant unreviewed implementations. If a specific prototype file is needed, record its pinned blob, author/rightsholder evidence, incorporated third-party content, intended modifications and notices in a dedicated review PR before import.

## Architecture and API implications

Do not migrate the global injection container, duplicated speech services, Core Data/SwiftData mixture or JavaScript bridge by default. New conversation state uses explicit ownership and typed service boundaries. Name interfaces by their role, document cancellation and keep transport details outside presentation.

New Swift behavior receives Swift Testing coverage against production types, with deterministic fixtures and interface-local doubles under DEBUG. A source inventory has no Swift behavior to test; verification here is completeness and reproducibility of Git-object metadata.

## Reproduce

From SRay, with the original checkout in a sibling/parent location:

```sh
python3 scripts/inventory_prototype.py /path/to/MRSignTranslate \
  --revision 66c76d6 --output /tmp/prototype-inventory.csv
```

Compare the generated file to `prototype-inventory.csv` in this directory. The script reads the pinned Git tree, not untracked files or working-copy content. ZIP inspection was directory-only; no archive was executed or extracted.

## Completion boundaries

The file inventory and conservative migration decision are complete. Any future import still requires file-specific rights verification. Provider service rights are tracked in #2; final distribution review is #27.
