# World Generation

Telluric world generation is seed-first, deterministic-first, and contract-first.

Phase 2 created world, terrain, and biome contracts. Phase 3 adds the first deterministic baseline implementation behind those contracts.

The Phase 3 baseline is production architecture, not throwaway visual prototype code. The generated world can remain simple, but the pipeline must be deterministic, testable, validated, hashable, and extensible.

## Fields Before Chunks

Legacy design guidance remains: world fields are the truth, chunks are evaluation windows.

Chunks are useful for streaming, caching, validation, and payload boundaries. They must not become isolated islands that choose local biomes or terrain independently from world-scale fields.

The baseline uses chunks as sample windows over world-space integer coordinates. Terrain and biome fields are sampled from `worldX/worldZ` coordinates derived from `ChunkCoord` and `WorldConfig.chunkSize`.

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

Phase 3 preserves the Phase 2 payload hash domains:

```text
Telluric.TerrainPayload.v1
Telluric.BiomePayload.v1
Telluric.ChunkWorldPayload.v1
```

No hash-domain version bump is needed because the payload contracts did not change; Phase 3 adds producers for those contracts.

## Phase 3 Pipeline

The baseline pipeline is:

```text
WorldGenerationContext
  -> DeterministicTerrainGenerator
  -> TerrainPayload
  -> DeterministicBiomeResolver
  -> BiomePayload
  -> DeterministicWorldGenerator
  -> ChunkWorldPayload + WorldGenerationReport
```

`TelluricWorld` keeps the orchestration generic through `WorldChunkComponentGenerating` so it does not import `TelluricTerrain` or `TelluricBiomes`. `TelluricBiomes` provides `DeterministicTerrainBiomeChunkGenerator`, which runs terrain generation, biome resolution, and returns ordered component hashes for world aggregation.

## Terrain Baseline

`DeterministicTerrainGenerator` produces a height field with dimensions:

```text
(chunkSize + 1) x (chunkSize + 1)
```

`chunkSize` is treated as the number of cells per chunk. The extra sample row/column stores the positive boundary so adjacent chunks share exact edge samples.

The baseline height function is deterministic value noise:

- lattice values are derived from `WorldGenerationContext.derivedSeed`;
- multiple world-space frequencies are blended;
- all sampling uses integer world coordinates;
- no system randomness or GameplayKit noise is used;
- no renderer or mesh data is produced.

This gives a coherent, simple height field suitable for validation and future replacement by richer terrain recipes without changing payload ownership.

## Biome Baseline

`DeterministicBiomeResolver` consumes `TerrainPayload` and resolves a `BiomeField` with the same dimensions as the terrain field.

The baseline maps deterministic world-space moisture and temperature fields plus normalized terrain elevation to stable biome IDs:

```text
biome.snow
biome.tundra
biome.mountain
biome.desert
biome.grassland
biome.temperate_forest
biome.wetland
```

Moisture, temperature, vegetation density, and secondary blend weight remain bounded in `0...1`. The baseline does not encode rendering colors, materials, props, gameplay, sub-biomes, or ecology simulation.

## Chunk Continuity

Continuity is defined at the sample contract level:

- adjacent chunks share identical terrain samples along the included boundary edge;
- biome samples on shared edges match because they use the same world-space coordinates and terrain edge samples;
- no chunk-local RNG state controls edge values.

Future terrain systems may add richer continuity tests for slopes, erosion, hydrology, or surface classification, but Phase 3 establishes the deterministic world-space sampling rule.

## Validation

World validation checks configuration-level issues such as invalid chunk sizes and invalid vertical scale.

Terrain validation checks dimensions, sample counts, empty fields, finite height samples, expected chunk coordinates, and payload hash consistency.

Biome validation checks dimensions, sample counts, empty fields, normalized climate/ecology values, blend consistency, expected chunk coordinates, and payload hash consistency.

Validation APIs return ordered issue arrays or reports so future CLIs can serialize and diff results deterministically.

`WorldGenerationReport.isSuccess` is true when no error issues are present. `DeterministicWorldGenerator` validates `WorldConfig`, component presence, terrain payload validation, and biome payload validation before returning a successful chunk result.

## Future Consumers

Phase 4 adds the first CLI consumer:

```text
telluric-seed-validator
  -> DeterministicWorldGenerator
  -> ordered ChunkWorldPayload results
  -> SeedValidationReport
```

The validator checks a square grid in deterministic `z` then `x` order, records ordered diagnostics, stores per-chunk payload hashes, and computes a report root hash using:

```text
Telluric.SeedValidationReport.v1
```

The report intentionally omits timestamps and timing data so JSON output can be diffed across runs.

The contracts are also designed for future:

- world labs;
- terrain and biome generation jobs;
- streaming planners;
- replay/debug tooling;
- asset cooking validation;
- renderer-independent snapshots.

None of those consumers are implemented in Phase 2.

Phase 3 still does not implement:

- streaming;
- runtime scheduling;
- mesh generation;
- rendering;
- assets;
- gameplay;
- app/UI;
- audio;
- motion;
- ML;
- advanced terrain recipes;
- hydrology, erosion, surfaces, props, or ecology.
