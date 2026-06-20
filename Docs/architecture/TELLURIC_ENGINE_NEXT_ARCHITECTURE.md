# Telluric Engine Next — Architecture Adapted From Legacy Docs

## 0. Why this document exists

The first Telluric / IsoWorld / IsoForge attempt mixed too much inside an Xcode app.

This document adapts the legacy design documents to a clean architecture:

```text
Engine platform != Game != Tools != Runtime shell
```

Legacy docs are preserved in `Docs/legacy/` and remain valuable as design references, but they are not implementation structure.

## 1. Naming

Historical names:

- IsoWorld
- IsoForge
- IsoForge Engine

Current reference name:

```text
Telluric Engine Next
```

Subsystem names may remain:

- Terrain Forge
- Biome Forge
- Surface Forge
- Motion Forge
- Audio Forge
- ML Bridge
- IVDS

## 2. Non-negotiable architecture

```text
TelluricGameApp
  -> TelluricGame
  -> TelluricRuntime
  -> TelluricSimulation / World / Assets / Render contracts
  -> TelluricCore / Math / Determinism / Diagnostics

TelluricTools
  -> Engine modules

TelluricRenderMetal
  -> TelluricRender contracts

Engine modules never import Game or Tool targets.
```

## 3. Repository strategy

Use a monorepo at the start.

Reason:

- easier refactors;
- one AGENTS.md scope;
- one CI/check script;
- easier Codex context;
- less versioning overhead;
- still allows strict module boundaries.

## 4. Target SwiftPM module graph

Phase 0 is the repo-local safe bootstrap plus SwiftPM architectural skeleton. It creates only the module boundaries needed for a real compilable repository context. It does not implement engine behavior.

### Foundation

```text
TelluricCore
TelluricMath
TelluricDeterminism
TelluricDiagnostics
```

Responsibilities:

- seeds;
- stable hashes;
- tick/frame indexes;
- coordinates;
- deterministic RNG;
- diagnostics;
- basic math;
- no rendering;
- no app dependencies.

### Simulation

```text
TelluricECS
TelluricSimulation
```

Responsibilities:

- entity IDs;
- components;
- simulation commands;
- fixed tick;
- simulation snapshots;
- replay logs;
- stable world hashes.

### World generation

```text
TelluricWorld
TelluricTerrain
TelluricBiomes
TelluricStreaming
```

Responsibilities:

- WorldDNA;
- field system;
- chunk coordinates;
- Terrain Forge payloads;
- Biome Forge payloads;
- chunk residency planning.

`TelluricSurfaces` and `TelluricEcology` are planned later targets, not Phase 0 targets.

### Runtime orchestration

```text
TelluricAssets
TelluricRuntime
TelluricPersistence
```

Responsibilities:

- asset manifests;
- cooked asset registry;
- runtime config;
- world loading;
- simulation ticking;
- chunk residency;
- save/delta layer.

Phase 7 implements the first runtime behavior in `TelluricRuntime`: synchronous world generation composition, chunk streaming plan consumption, chunk residency, fixed-tick simulation stepping, deterministic runtime snapshots and diagnostics. It does not implement apps, gameplay, rendering, assets behavior, persistence behavior or async jobs.

### Rendering contracts and backend

```text
TelluricRender
```

Responsibilities:

- `TelluricRender` defines backend-independent snapshots.

World payloads must not contain GPU objects.

`TelluricRenderMetal` is the future Metal/MetalKit backend. It owns RenderGraph, pipelines, GPU resources and IVDS rendering when introduced, and is intentionally not created in Phase 0.

### Audio

```text
TelluricAudioCore
TelluricAudioRuntime
TelluricAudioTools
```

Adapted from legacy audio doc:

- AudioCore defines `WorldAudioDNA`, `AudioEvent`, `AudioRecipe`, `AudioSnapshot`.
- AudioRuntime owns Apple audio backend integration.
- AudioTools owns authoring, graph validation, profiling, recipe debugging.

Runtime audio reads snapshots/events. It does not own world state.

Audio targets are not created in Phase 0.

### Motion

```text
TelluricMotionCore
TelluricMotionRuntime
TelluricMotionTools
```

Adapted from Motion Forge:

- MotionCore defines `MotionIntent`, contact contexts, motion primitives, pose snapshots.
- MotionRuntime evaluates motion deterministically where necessary.
- MotionTools / ProtoMotion Lab imports, retargets, validates and cooks motion packs.

Motion targets are not created in Phase 0.

### ML / AI

```text
TelluricMLBridge
TelluricMLTools
TelluricRPGCore
```

Adapted from ML/RPG pipeline:

- ML proposes, scores, classifies, reformulates, or compresses.
- Deterministic engine validates.
- Only validated decisions enter world state.
- Offline tools own training/dataset generation.
- Runtime inference must be bounded and fallback-safe.

ML/RPG targets are not created in Phase 0.

### Phase 0 CLI boundaries

```text
TelluricSeedValidator
TelluricAssetCooker
TelluricReplayInspector
```

These are command-line target boundaries only in Phase 0. They do not contain real validation, cooking, replay inspection, UI, or gameplay behavior yet.

## 5. Runtime loop

```text
Raw input
  -> GameInput
  -> GameIntent
  -> SimulationCommand
  -> fixed simulation tick
  -> WorldState / SaveDelta
  -> SimulationSnapshot
  -> RenderSnapshot / AudioSnapshot / MotionSnapshot
  -> RenderMetal / AudioRuntime / Tools
```

## 6. What changed from the first attempt

Old approach:

```text
Xcode app as center
GameView orchestrates too much
Renderer knows too much about world
Tools/debug mixed with runtime
Metal path mixed with gameplay experiments
```

New approach:

```text
SwiftPM modules first
Xcode app later
Engine contracts first
Runtime app thin
Tools are separate clients
Metal backend isolated
Procedural systems testable before rendering
```

## 7. Implementation order

```text
0. Repo-local safe bootstrap + SwiftPM architectural skeleton
1. First real engine foundation implementation: Core, Math, Determinism, Diagnostics
2. World data contracts
3. Terrain/Biome baseline implementation respecting final contracts
4. Seed validator CLI behavior
5. Chunk streaming planner
6. ECS / Simulation contracts
7. Runtime behavior
8. RenderSnapshot contracts
9. Assets / AssetCooker behavior
10. ReplayInspector behavior
11. RenderMetal backend
12. Runtime app thin
13. Game layer
14. WorldLab
15. Advanced Terrain Forge / Motion Forge / Audio Forge / ML Bridge
```

## 8. No throwaway code policy

A vertical slice may be small, but it must use final-shaped contracts.

Good:

```text
Implement TerrainPayload, TerrainHasher and a simple deterministic generator that respects the final payload contract.
```

Bad:

```text
Make a quick preview terrain directly in Metal, then replace it later.
```
