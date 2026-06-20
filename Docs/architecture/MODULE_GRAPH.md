# Module Graph — Telluric Engine Next

## 0. Direction

```text
High-level clients -> Engine modules -> Foundation modules
```

Never reverse this direction.

Phase 0 creates only a compilable SwiftPM architectural skeleton. It does not implement engine behavior, gameplay, UI tools, Xcode apps, or Metal backends.

## 1. Phase 0 Active Targets

### Foundation modules

```text
TelluricCore
TelluricMath -> TelluricCore
TelluricDeterminism -> TelluricCore, TelluricMath
TelluricDiagnostics -> TelluricCore
```

Phase 1 implements the first real foundation contracts in these four targets. See:

- `Docs/architecture/ENGINE_FOUNDATION.md`
- `Docs/architecture/DETERMINISM.md`

### Simulation modules

```text
TelluricECS -> TelluricCore, TelluricMath, TelluricDeterminism
TelluricSimulation -> TelluricCore, TelluricMath, TelluricDeterminism, TelluricECS
```

### World modules

```text
TelluricWorld -> TelluricCore, TelluricMath, TelluricDeterminism
TelluricTerrain -> TelluricCore, TelluricMath, TelluricDeterminism, TelluricWorld
TelluricBiomes -> TelluricCore, TelluricMath, TelluricDeterminism, TelluricWorld, TelluricTerrain
TelluricStreaming -> TelluricCore, TelluricMath, TelluricWorld, TelluricTerrain
```

Phase 2 implements data, validation, hashing, and protocol contracts for `TelluricWorld`, `TelluricTerrain`, and `TelluricBiomes`. It does not implement generation algorithms or streaming behavior. See:

- `Docs/architecture/WORLD_DATA_CONTRACTS.md`
- `Docs/architecture/WORLD_GENERATION.md`

Phase 3 adds deterministic baseline generation while preserving dependency direction:

- `TelluricWorld` owns generic chunk orchestration and aggregate payload reports.
- `TelluricTerrain` owns deterministic terrain generation.
- `TelluricBiomes` owns deterministic biome resolving and the terrain+biome component adapter.

### Runtime and contract modules

```text
TelluricAssets -> TelluricCore, TelluricDiagnostics
TelluricPersistence -> TelluricCore, TelluricDeterminism, TelluricSimulation, TelluricWorld, TelluricDiagnostics
TelluricRuntime -> TelluricCore, TelluricDiagnostics, TelluricAssets, TelluricSimulation, TelluricWorld, TelluricTerrain, TelluricBiomes, TelluricStreaming, TelluricPersistence
TelluricRender -> TelluricCore, TelluricMath, TelluricAssets
```

`TelluricRender` is backend-independent. It must not import Metal or MetalKit.

### Tools CLI targets

```text
TelluricSeedValidator -> TelluricWorld, TelluricTerrain, TelluricBiomes, TelluricDiagnostics
TelluricAssetCooker -> TelluricAssets, TelluricDiagnostics
TelluricReplayInspector -> TelluricRuntime, TelluricSimulation, TelluricDiagnostics
```

These are command-line target boundaries only in Phase 0. They must not contain UI or real tool behavior yet.

## 2. Deferred Targets

These targets remain part of the architecture but are not created in Phase 0:

```text
TelluricGame
TelluricGameApp
TelluricRenderMetal
TelluricSurfaces
TelluricEcology
TelluricAudioCore
TelluricAudioRuntime
TelluricAudioTools
TelluricMotionCore
TelluricMotionRuntime
TelluricMotionTools
TelluricRPGCore
TelluricMLBridge
TelluricMLTools
TelluricWorldLab
```

`TelluricRenderMetal` is the future Metal/MetalKit backend and is the only planned target allowed to own GPU API integration. It is intentionally not created in Phase 0.

## 3. Guard Rules

Phase 0 architecture guards must fail if:

- a source target outside the Phase 0 active target list is created;
- Ruby/Rails markers or Ruby files appear;
- scripts invoke unsafe global commands;
- SwiftUI, AppKit, Metal, MetalKit, AVFoundation, CoreAudio, or GameplayKit are imported in Phase 0 sources;
- deterministic/procedural modules use `random(in:)`, `UUID()`, or `Date()`;
- engine modules import app, game, or tool modules.
