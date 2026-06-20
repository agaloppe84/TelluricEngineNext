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
  -> TelluricSimulation / World / Assets / Render extraction / Render contracts
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

Phase 10 implements the first asset behavior in `TelluricAssets`: JSON manifests, asset IDs, source/cooked paths, cooked descriptors, asset registries, validation reports, and stable asset hashes. It does not implement runtime asset streaming, GPU resources, conversion, editor UI, or gameplay assets.

Phase 11 implements the first persistence behavior in `TelluricPersistence`: snapshot packages, replay packages, report packages, schema/version metadata, deterministic JSON helpers, payload hash verification, and validation diagnostics. It does not implement game save slots, platform storage, cloud sync, databases, binary compression, or gameplay save semantics.

### Rendering contracts and backend

```text
TelluricRender
TelluricRenderExtraction
TelluricRenderMetal
```

Responsibilities:

- `TelluricRender` defines backend-independent snapshots.
- `TelluricRenderExtraction` bridges runtime snapshots into backend-neutral render snapshots without making runtime import render.
- `TelluricRenderMetal` owns the isolated Apple Metal backend boundary.

World payloads must not contain GPU objects.

Phase 8 implements renderer-independent render contracts in `TelluricRender`: neutral resource identifiers, camera snapshots, renderable instances, debug primitives, ordered render snapshots and stable render snapshot hashing.

Phase 9 implements runtime render extraction in `TelluricRenderExtraction`: resident chunk debug boundaries, optional coordinate labels, optional center points and deterministic render snapshots.

Phase 12 introduces `TelluricRenderMetal` as the isolated Metal backend skeleton. It can attempt default device and command queue creation and accepts `RenderSnapshot`, but it does not create an app, window, `MTKView`, render loop, runtime integration, mesh generation, asset loading, shaders, or gameplay.

Future `TelluricRenderMetal` phases may own RenderGraph, pipelines, GPU resources and IVDS rendering. Metal API usage must remain isolated to this backend target for engine code, with only app-shell platform glue allowed to touch Metal/MetalKit above the engine boundary.

### Game layer

```text
TelluricGame
```

Responsibilities:

- game session contracts;
- game input frames;
- ordered game intents;
- mapping game intents to engine-neutral simulation commands;
- owning `TelluricRuntime` as a client when a game session is needed;
- game-layer diagnostics and stable step hashes.

Phase 14 implements the first game-layer contracts. It does not create an app, platform input, UI, rendering, Metal integration, player controllers, combat, inventory, quests, factions, RPG stats, audio, motion or ML.

### Minimal app shell

```text
TelluricGameApp
TelluricGameAppCore
```

Responsibilities:

- SwiftPM executable host;
- minimal macOS window and `MTKView` glue;
- deterministic app-shell configuration;
- stateful stepping over `TelluricGame`, `TelluricRuntime`, `TelluricRenderExtraction`, and `TelluricRenderMetal`;
- structured diagnostics for the current no-drawable-rendering state.

Phase 16 implements the first app shell. `TelluricGameAppCore` remains UI-free and testable. `TelluricGameApp` is the only target allowed to import AppKit/MetalKit. The app shell does not create an Xcode project, packaged app bundle, gameplay systems, editor UI, terrain mesh generation, asset rendering, audio, motion, or ML.

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
TelluricAssetCookerCore
TelluricReplayInspector
TelluricHeadlessLoop
TelluricHeadlessLoopCore
TelluricGameApp
TelluricGameAppCore
```

These are top-level client target boundaries only. Phase 4 implements the seed validator. Phase 10 implements the asset cooker as a manifest validation and descriptor/report tool. Phase 15 implements the headless loop as a vertical integration smoke executable over game, runtime, render extraction, Metal debug-line preparation, and persistence packaging. Phase 16 implements the minimal app shell over the same pipeline without moving engine logic into app code. Replay inspection remains future work.

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

Phase 15 validates the current subset of this chain headlessly:

```text
GameInputFrame
  -> GameSession
  -> RuntimeSnapshot
  -> RenderSnapshot
  -> TelluricRenderMetal debug line preparation
  -> TelluricPersistence package summaries
```

This is a validation executable, not the runtime app. It creates no window, drawable, `MTKView`, app bundle, platform input layer, or gameplay system.

Phase 16 adds the minimal macOS app shell above the same pipeline. It can create a window and `MTKView`, but it still does not implement drawable presentation, platform input, gameplay systems, or terrain mesh rendering.

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
Thin app shell later
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
9. Runtime render extraction
10. Assets / AssetCooker behavior
11. Persistence / snapshot save-load contracts
12. Isolated RenderMetal backend skeleton
13. Metal debug line pipeline
14. Game layer contracts
15. Headless end-to-end game loop
16. Minimal macOS app shell
17. ReplayInspector behavior
18. WorldLab
19. Advanced Terrain Forge / Motion Forge / Audio Forge / ML Bridge
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
