# World Generation

Telluric world generation is seed-first, deterministic-first, and contract-first.

Phase 2 creates world, terrain, and biome contracts. It intentionally does not implement advanced procedural generation. Future systems will plug into these contracts without changing their core ownership boundaries.

## Fields Before Chunks

Legacy design guidance remains: world fields are the truth, chunks are evaluation windows.

Chunks are useful for streaming, caching, validation, and payload boundaries. They must not become isolated islands that choose local biomes or terrain independently from world-scale fields.

## Seed Derivation

World generation streams derive from:

```text
WorldConfig.worldSeed
NamespaceID
Int3 coordinates
local index
```

`WorldGenerationContext.derivedSeed(...)` forwards to `SeedDerivation`. Namespaces should be explicit, for example:

```text
terrain.height
biome.selection
chunk.payload
```

This prevents unrelated systems from accidentally sharing the same deterministic stream.

## Stable Hash Contract

Terrain and biome payload hashes use `StableHasher`.

They must include:

- a domain/version string;
- chunk coordinate;
- generation settings or rules;
- ordered field dimensions and samples;
- summaries that are part of the payload contract.

They must not use Swift's built-in `Hasher`, because Swift hash values are intentionally process-randomized and unsuitable for persisted validation, replay checks, golden seeds, or cache signatures.

## Validation

World validation checks configuration-level issues such as invalid chunk sizes and invalid vertical scale.

Terrain validation checks dimensions, sample counts, empty fields, finite height samples, expected chunk coordinates, and payload hash consistency.

Biome validation checks dimensions, sample counts, empty fields, normalized climate/ecology values, blend consistency, expected chunk coordinates, and payload hash consistency.

Validation APIs return ordered issue arrays or reports so future CLIs can serialize and diff results deterministically.

## Future Consumers

The contracts are designed for future:

- seed validators;
- world labs;
- terrain and biome generation jobs;
- streaming planners;
- replay/debug tooling;
- asset cooking validation;
- renderer-independent snapshots.

None of those consumers are implemented in Phase 2.
