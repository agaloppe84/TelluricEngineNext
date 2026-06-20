# Seed Validator CLI

`telluric-seed-validator` validates deterministic world generation over an ordered square chunk grid.

It is a command-line engine tool. It does not create an app, UI, renderer, Xcode project, gameplay system, or Metal backend.

## Usage

Run through SwiftPM:

```sh
swift run telluric-seed-validator --seed 12345 --radius 2 --chunk-size 32 --vertical-scale 12 --report Tools/benchmarks/seed_12345.json
```

Repo-local validation uses:

```sh
./scripts/check-architecture-guards.sh
```

That guard script runs a tiny smoke validation and writes:

```text
Tools/benchmarks/seed_validator_smoke.json
```

`Tools/benchmarks/` is ignored because seed validation reports are local generated artifacts.

## Arguments

- `--seed <UInt64>`: root `WorldSeed` value.
- `--radius <Int>`: inclusive square grid radius around chunk origin.
- `--chunk-size <Int>`: positive world chunk cell size.
- `--vertical-scale <Float>`: finite positive world vertical scale.
- `--report <path>`: optional deterministic JSON report output path.
- `--fail-fast`: stop after the first invalid chunk or generation failure.
- `--verbose`: print ordered per-chunk hashes.
- `--help`: print usage.

The generated chunk order is deterministic:

```text
z from -radius...radius
x from -radius...radius
y fixed at 0
```

## Report Contract

`SeedValidationReport` uses ordered arrays, not dictionaries.

It includes:

- tool name and tool version;
- engine version;
- seed, radius, chunk size, and vertical scale;
- chunk counts;
- ordered chunk results;
- ordered diagnostics;
- deterministic root hash;
- success boolean.

Reports intentionally omit wall-clock timestamps and performance timings. If future profiling is needed, it should live in a separate non-deterministic artifact.

## Determinism

The validator consumes the Phase 3 deterministic generation pipeline:

```text
DeterministicWorldGenerator
  -> DeterministicTerrainBiomeChunkGenerator
  -> DeterministicTerrainGenerator
  -> DeterministicBiomeResolver
```

Per-chunk hashes come from the engine payload contracts:

```text
Telluric.TerrainPayload.v1
Telluric.BiomePayload.v1
Telluric.ChunkWorldPayload.v1
```

The report root hash uses:

```text
Telluric.SeedValidationReport.v1
```

It hashes ordered config, counts, chunk coordinates, chunk payload hashes, component hashes, success state, and diagnostics. It does not use Swift's built-in `Hasher`.

## Exit Codes

- `0`: parsing succeeded and all requested chunks validated successfully.
- `1`: parsing succeeded but validation failed, or report writing failed.
- `2`: command-line parsing failed.

## Current Limits

Phase 4 validates baseline terrain and biome generation only. It does not implement streaming, runtime scheduling, rendering, mesh generation, assets, gameplay, UI, audio, motion, ML, or advanced terrain recipes.
