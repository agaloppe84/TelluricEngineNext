# Determinism

Telluric Engine Next is seed-first and deterministic-first. The same engine version, same root seed, same namespace, same coordinates, and same ordered inputs must produce the same deterministic outputs.

## Rules

Deterministic and procedural modules must not use:

```swift
Float.random(in:)
Double.random(in:)
Int.random(in:)
UUID()
Date()
Hasher
```

They must also avoid unordered dictionary or set iteration as logical input order. If unordered data must be hashed or serialized, callers must provide an explicit sorted order first.

## Seed Derivation

`SeedDerivation` derives isolated stream seeds from:

```text
world seed
namespace/domain
integer coordinates
local index
```

The namespace is a `NamespaceID`. It separates streams so systems such as terrain height, biome selection, and future asset placement can use the same world seed without accidentally sharing identical random sequences.

Example inputs:

```text
worldSeed: 42
namespace: terrain.height
coordinates: (-4, 0, 9)
localIndex: 7
```

The same input tuple derives the same `WorldSeed`. Changing any field derives a different stream with high probability.

## Stable Hashing

Telluric does not use Swift's built-in `Hasher` for stable hashes because Swift intentionally randomizes hashing between processes. That behavior is correct for hash tables, but it is not valid for save files, replay validation, golden seeds, asset manifests, or cross-run diagnostics.

`StableHasher` consumes values in caller-provided order and produces a `StableHash`. It uses fixed integer mixing and documents its version through the seed derivation domain string:

```text
Telluric.SeedDerivation.v1
```

If the stable hashing algorithm ever changes, affected persisted formats and golden tests must be versioned explicitly.

World, terrain, and biome payload hashers add their own domain/version strings before ordered payload content. Payload hashes must include only deterministic contract data and must not include renderer resources, memory addresses, object identity, dictionary iteration order, or process-local values.

Phase 3 deterministic generators preserve those payload hash domains while adding producer algorithms. Terrain and biome baseline value-noise fields derive lattice values through `WorldGenerationContext.derivedSeed`, explicit namespaces, and integer world coordinates. Adjacent chunks therefore agree on shared boundary samples without sharing mutable RNG state.

Phase 4 seed validation reports add a CLI report hash domain:

```text
Telluric.SeedValidationReport.v1
```

The report hash is derived from ordered configuration fields, chunk coordinates, per-chunk payload hashes, component hashes, success state, and ordered diagnostics. It excludes timestamps, process-local values, performance timing, and unordered container traversal.

Phase 5 streaming plans add a planner hash domain:

```text
Telluric.ChunkStreamingPlan.v1
```

The plan hash is derived from ordered streaming config, observers, request/keep/evict arrays, diagnostics, and success state. `TelluricStreaming` may use lookup structures internally in future optimizations, but final plan output and hashing must stay explicitly ordered.

Phase 6 ECS and simulation contracts add:

```text
Telluric.EntitySnapshot.v1
Telluric.SimulationSnapshot.v1
Telluric.ReplayInputLog.v1
```

Simulation determinism depends on fixed tick order, ordered command buffers, ordered entity/component snapshots, and stable diagnostics. The same initial `SimulationWorld` plus the same ordered `ReplayInputLog` must produce the same snapshot hashes. Changing command order is a meaningful deterministic input change.

Phase 7 runtime snapshots add:

```text
Telluric.RuntimeSnapshot.v1
```

Runtime determinism depends on ordered observers, ordered streaming plans, ordered runtime chunk records, stable chunk payload hashes, fixed simulation input frames, and ordered diagnostics. The same `RuntimeConfig` plus the same ordered runtime step inputs must produce the same runtime hashes. Runtime snapshots exclude wall-clock time, process-local values, app lifecycle state, rendering resources, and unordered collection traversal.

Phase 8 render snapshots add:

```text
Telluric.RenderSnapshot.v1
```

Render determinism depends on ordered camera, resource ID, renderable instance, and debug primitive data. Render snapshots are backend-neutral and exclude GPU resources, command buffers, pipeline state, platform windows, process-local values, and unordered collection traversal.

## Deterministic RNG

`DeterministicRNG` is based on fixed-width integer arithmetic. It produces identical sequences for identical seeds and divergent sequences for different seeds with high probability.

The RNG is suitable for deterministic generation streams. It is not cryptographic randomness and must not be used for security.

## Diagnostics And CLI Consumers

Future CLI tools should emit deterministic `DiagnosticReport` values. Reports preserve message order and use ordered metadata entries rather than dictionaries, which keeps JSON output friendlier for tests, diffs, and agent-readable validation.
