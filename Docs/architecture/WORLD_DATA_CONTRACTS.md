# World Data Contracts

Phase 2 defines durable contracts for:

```text
TelluricWorld
TelluricTerrain
TelluricBiomes
```

This phase does not implement advanced procedural generation, streaming, rendering, gameplay, or tools UI. It establishes the data shapes that those systems will consume later.

## Renderer Independence

World payloads are CPU-side engine truth. They must not contain renderer-owned resources such as buffers, textures, command encoders, shader state, or Metal objects.

The renderer may consume future snapshots derived from these payloads, but it must not decide terrain, biome, or world truth. This keeps world validation, replay, seed audits, streaming, and save/delta systems independent from any backend.

## Integer Coordinates

Chunks and regions use integer coordinates:

```text
ChunkCoord
RegionCoord
```

Integer coordinates avoid floating-point rounding drift in seed derivation, chunk lookup, region partitioning, and stable hashing. Negative chunk coordinates use floor division for region derivation so world partitioning remains stable across the origin.

## WorldConfig

`WorldConfig` controls the root world contract:

- `worldSeed`
- `chunkSize`
- `verticalScale`
- `generationProfile`

`WorldGenerationContext` combines `WorldConfig` with `EngineVersion` and exposes deterministic seed derivation through `SeedDerivation`.

## Chunk Payload Hashes

`ChunkWorldPayload` aggregates ordered component hashes, such as terrain and biome hashes. It stores hashes rather than importing concrete terrain or biome payload types into `TelluricWorld`, which preserves the dependency direction:

```text
TelluricTerrain -> TelluricWorld
TelluricBiomes  -> TelluricWorld, TelluricTerrain
TelluricWorld   -> foundation modules only
```

Component hashes are sorted deterministically before aggregation. Hashes are for validation, replay/debug comparisons, cache invalidation, and future seed tooling.

## Terrain Contracts

`TelluricTerrain` defines:

- `HeightSample`
- `HeightField`
- `HeightSummary`
- `TerrainGenerationSettings`
- `TerrainPayload`
- `TerrainGenerating`
- `TerrainValidation`
- `TerrainHasher`

`HeightField` validation checks:

- positive dimensions;
- sample count equals `width * depth`;
- non-empty fields;
- finite height values.

`TerrainPayload` contains chunk coordinate, height field, height summary, settings, validation output, and stable hash. It contains no mesh buffers, GPU state, or renderer-specific data.

## Biome Contracts

`TelluricBiomes` defines:

- `BiomeID`
- `BiomeSample`
- `BiomeField`
- `BiomeRules`
- `BiomePayload`
- `BiomeResolving`
- `BiomeValidation`
- `BiomeHasher`

`BiomeSample` supports primary biome, optional secondary biome, secondary blend weight, moisture, temperature, and vegetation density.

Biome validation checks:

- positive dimensions;
- sample count equals `width * depth`;
- non-empty fields;
- finite `0...1` moisture;
- finite `0...1` temperature;
- finite `0...1` vegetation density;
- valid secondary biome blend rules.

## Contract-Only Boundary

The protocols `TerrainGenerating` and `BiomeResolving` are boundaries for later generation systems. Phase 2 does not provide generator implementations, biome solvers, terrain recipes, erosion, hydrology, mesh compilation, streaming residency, or tool UI.

Phase 3 implements the first concrete baseline behind these boundaries:

- `DeterministicTerrainGenerator`
- `DeterministicBiomeResolver`
- `DeterministicTerrainBiomeChunkGenerator`
- `DeterministicWorldGenerator`

These implementations still produce only renderer-independent data contracts. They do not add streaming, mesh data, GPU resources, app code, gameplay, or tools UI.
