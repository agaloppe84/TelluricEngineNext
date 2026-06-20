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
TelluricSimulation -> TelluricCore, TelluricMath, TelluricDeterminism, TelluricDiagnostics, TelluricECS
```

Phase 6 implements durable ECS and fixed-tick simulation contracts:

- `TelluricECS` owns stable entity IDs, neutral components, ordered entity snapshots, and minimal sorted component storage.
- `TelluricSimulation` owns fixed tick config, ordered input frames, engine-neutral commands, simulation snapshots, replay logs, diagnostics, and stable simulation hashes.

See `Docs/architecture/SIMULATION.md`.

### World modules

```text
TelluricWorld -> TelluricCore, TelluricMath, TelluricDeterminism
TelluricTerrain -> TelluricCore, TelluricMath, TelluricDeterminism, TelluricWorld
TelluricBiomes -> TelluricCore, TelluricMath, TelluricDeterminism, TelluricWorld, TelluricTerrain
TelluricStreaming -> TelluricCore, TelluricMath, TelluricDeterminism, TelluricDiagnostics, TelluricWorld
```

Phase 2 implements data, validation, hashing, and protocol contracts for `TelluricWorld`, `TelluricTerrain`, and `TelluricBiomes`. It does not implement generation algorithms or streaming behavior. See:

- `Docs/architecture/WORLD_DATA_CONTRACTS.md`
- `Docs/architecture/WORLD_GENERATION.md`

Phase 3 adds deterministic baseline generation while preserving dependency direction:

- `TelluricWorld` owns generic chunk orchestration and aggregate payload reports.
- `TelluricTerrain` owns deterministic terrain generation.
- `TelluricBiomes` owns deterministic biome resolving and the terrain+biome component adapter.

Phase 5 implements `TelluricStreaming` as a pure deterministic chunk planning layer:

- it converts integer observer positions to chunk coordinates;
- it computes ordered request/keep/evict plans;
- it hashes ordered plan contents;
- it does not import terrain, biomes, rendering, runtime, gameplay, tools UI, or asset systems.

See `Docs/architecture/STREAMING.md`.

### Runtime and contract modules

```text
TelluricAssets -> TelluricCore, TelluricDeterminism, TelluricDiagnostics
TelluricPersistence -> TelluricCore, TelluricDeterminism, TelluricSimulation, TelluricWorld, TelluricDiagnostics
TelluricRuntime -> TelluricCore, TelluricDeterminism, TelluricDiagnostics, TelluricAssets, TelluricSimulation, TelluricWorld, TelluricTerrain, TelluricBiomes, TelluricStreaming, TelluricPersistence
TelluricGame -> TelluricCore, TelluricMath, TelluricDeterminism, TelluricDiagnostics, TelluricECS, TelluricSimulation, TelluricStreaming, TelluricRuntime
TelluricRender -> TelluricCore, TelluricMath, TelluricDeterminism, TelluricAssets
TelluricRenderExtraction -> TelluricCore, TelluricDiagnostics, TelluricMath, TelluricRender, TelluricRuntime, TelluricWorld, TelluricTerrain
TelluricRenderMetal -> TelluricCore, TelluricDiagnostics, TelluricRender
TelluricGameAppCore -> TelluricGame, TelluricRuntime, TelluricRenderExtraction, TelluricRender, TelluricRenderMetal, engine contracts
TelluricGameApp -> TelluricGameAppCore
```

`TelluricRender` is backend-independent. It must not import Metal or MetalKit.

Phase 7 implements `TelluricRuntime` as the synchronous engine runtime shell:

- it owns runtime config, runtime state, chunk residency records, runtime step inputs and results, runtime snapshots, and runtime hashing;
- it composes the deterministic terrain+biome world generator, chunk streaming planner, and fixed-tick simulation world;
- it remains app-free, gameplay-free, UI-free, renderer-free, and synchronous.

See `Docs/architecture/RUNTIME.md`.

Phase 8 implements `TelluricRender` as the renderer-independent contract layer:

- it owns resource identifiers, render layers, camera snapshots, renderable instances, debug primitives, render snapshots, and render snapshot hashing;
- it depends on `TelluricDeterminism` only for stable hashing;
- it does not import runtime, render backends, platform UI, Metal, gameplay, or tools UI.

See `Docs/architecture/RENDERING.md`.

Phase 9 implements `TelluricRenderExtraction` as the backend-neutral bridge from runtime snapshots to render snapshots:

- it consumes ordered `RuntimeSnapshot` chunk residency;
- it emits chunk boundary debug lines, optional labels, and optional points;
- Phase 22 adds optional terrain height wireframe debug lines by regenerating deterministic terrain payloads for resident chunks from runtime config, terrain settings, and chunk coordinates;
- it keeps `TelluricRuntime` independent from `TelluricRender`;
- it does not import render backends, Metal, UI frameworks, gameplay, or tools UI.

See `Docs/architecture/RENDER_EXTRACTION.md`.

Phase 10 implements `TelluricAssets` as the asset manifest contract layer:

- it owns asset IDs, asset kinds, manifest versions, source/cooked paths, manifests, descriptors, registries, validation reports, and asset hashing;
- it validates manifest path policy and duplicate IDs;
- it depends on `TelluricDeterminism` only for stable manifest and descriptor hashes;
- it does not load assets, decode files, create GPU resources, stream runtime assets, or import cooker targets.

See `Docs/architecture/ASSETS.md`.

Phase 11 implements `TelluricPersistence` as the snapshot, replay, and report package contract layer:

- it owns persistence format versions, schema ids, envelope kinds, payload hashes, ordered metadata, generic envelopes, snapshot/replay/report packages, deterministic JSON helpers, validation reports, and stable package hashing;
- it imports simulation contracts for replay/simulation snapshot convenience types;
- it does not import runtime, render, render extraction, seed validator, asset cooker, app, game, UI, Metal, or platform storage code;
- runtime snapshots, render snapshots, and tool reports are wrapped through generic package APIs by their callers rather than by reversing dependency direction.

See `Docs/architecture/PERSISTENCE.md`.

Phase 12 implements `TelluricRenderMetal` as the isolated Metal backend skeleton:

- it is the only active engine/backend target allowed to import `Metal`;
- it attempts system-default device and command queue creation;
- it accepts backend-neutral `RenderSnapshot` values;
- Phase 13 adds debug line CPU conversion and optional Metal buffer preparation;
- it reports explicit unsupported diagnostics for renderable instances, texture/material binding, debug points, debug labels, and drawable presentation;
- it does not create an app, window, `MTKView`, render loop, runtime integration, mesh generation, asset loading, gameplay, or tools UI.

See `Docs/architecture/METAL_BACKEND.md`.

Phase 14 implements `TelluricGame` as the first game client contract layer:

- it owns game session ids, game config, neutral game rules profiles, ordered game intents, game input frames, intent mapping results, game step inputs/results, and a `GameSession` runtime client;
- it maps ordered `GameIntent` values into ordered `SimulationCommand` values through `GameIntentMapper`;
- it may own `TelluricRuntime` as a client, but runtime and lower engine modules must not import game code;
- it does not implement an app, platform input, UI, rendering, Metal, player controllers, gameplay camera, combat, inventory, quests, factions, RPG stats, audio, motion, or ML.

See `Docs/architecture/GAME_LAYER.md`.

Phase 16 implements `TelluricGameApp` as the first minimal macOS app shell:

- `TelluricGameAppCore` is UI-free and testable; it builds the stateful app-shell pipeline over the existing game/runtime/render-extraction/Metal-preparation modules;
- `TelluricGameApp` is the SwiftPM executable target that owns AppKit/MetalKit window and view glue;
- Phase 17 adds drawable debug-line rendering for extracted chunk boundaries when a live Metal drawable is supplied;
- Phase 18 adds bounded safe run/smoke options and JSON diagnostics reports without changing engine dependency direction;
- Phase 20 adds debug-only camera/projection contracts in `TelluricGameAppCore` and AppKit-only keyboard/mouse event glue in `TelluricGameApp`;
- Phase 21 adds backend-neutral debug visual layer options, fixed debug colors, app-shell toggles, and quieter frame logging;
- Phase 22 enables debug-only terrain height wireframe preview through backend-neutral `DebugLine` extraction and app-shell terrain toggles;
- Phase 23 adds app-shell projection mode, height exaggeration, and oblique-strength controls for terrain debug readability without changing engine/runtime/render backend dependency direction;
- engine modules, runtime, game, render extraction, and render contracts must not import app-shell targets.

See `Docs/architecture/GAME_APP_SHELL.md`.

### Tools CLI targets

```text
TelluricSeedValidator -> TelluricSeedValidatorCore
TelluricSeedValidatorCore -> TelluricCore, TelluricDeterminism, TelluricWorld, TelluricTerrain, TelluricBiomes, TelluricDiagnostics
TelluricAssetCooker -> TelluricAssetCookerCore
TelluricAssetCookerCore -> TelluricAssets, TelluricCore, TelluricDeterminism, TelluricDiagnostics
TelluricReplayInspector -> TelluricRuntime, TelluricSimulation, TelluricDiagnostics
TelluricHeadlessLoop -> TelluricHeadlessLoopCore
TelluricHeadlessLoopCore -> TelluricGame, TelluricRuntime, TelluricRenderExtraction, TelluricRender, TelluricRenderMetal, TelluricPersistence, TelluricDiagnostics, foundation contracts
```

`TelluricSeedValidatorCore` is a testable tool-support target, not an engine module. Engine modules must not import it.
`TelluricAssetCookerCore` is also a testable tool-support target, not an engine module. Engine modules must not import it.
`TelluricHeadlessLoopCore` is a testable tool-support target, not an engine module. Engine modules must not import it.

Phase 4 implements `telluric-seed-validator` as the first real CLI engine tool. It validates deterministic terrain+biome chunk generation over an ordered grid and writes deterministic JSON reports without app, UI, rendering, gameplay, or Metal dependencies.

Phase 10 implements `telluric-asset-cooker` as the first asset manifest validation/cooker CLI. It validates manifests and writes deterministic reports without pretending to convert unsupported asset kinds.

Phase 15 implements `telluric-headless-loop` as the app-free vertical smoke executable. It drives `TelluricGame`, `TelluricRuntime`, `TelluricRenderExtraction`, `TelluricRenderMetal`, and `TelluricPersistence` as a top-level client without creating app, window, UI, drawable, gameplay-system, or Xcode boundaries.

`TelluricReplayInspector` remains a command-line target boundary only until its tool phase.

### App shell targets

```text
TelluricGameApp -> TelluricGameAppCore
TelluricGameAppCore -> TelluricGame, TelluricRuntime, TelluricRenderExtraction, TelluricRender, TelluricRenderMetal, foundation contracts
```

`TelluricGameAppCore` is a testable app-support target, not an engine module. It must remain free of AppKit, SwiftUI, MetalKit, and window/view code.

`TelluricGameAppCore` may own debug visualization state such as `DebugCameraState` and platform-neutral debug camera control intents. These are app-shell contracts, not game/player input contracts, and must not be imported by engine modules.

`TelluricGameApp` is the only active source target allowed to import `AppKit` and `MetalKit`. It may import `Metal` as app-shell platform glue for `MTKView` device creation. No engine module may import either app-shell target.

## 2. Deferred Targets

These targets remain part of the architecture but are not created in Phase 0:

```text
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

`TelluricRenderMetal` is now active as of Phase 12. Future backend expansions must keep Metal isolated to that target.
`TelluricGame` is now active as of Phase 14. `TelluricGameApp` is now active as of Phase 16.

## 3. Guard Rules

Phase 0 architecture guards must fail if:

- a source target outside the Phase 0 active target list is created;
- Ruby/Rails markers or Ruby files appear;
- scripts invoke unsafe global commands;
- SwiftUI, AVFoundation, CoreAudio, or GameplayKit are imported in active sources;
- AppKit is imported outside `Sources/TelluricGameApp`;
- Metal is imported outside `Sources/TelluricRenderMetal` and `Sources/TelluricGameApp`;
- MetalKit is imported outside `Sources/TelluricGameApp`;
- deterministic/procedural modules use `random(in:)`, `UUID()`, or `Date()`;
- engine modules import app, game, or tool modules.
- `TelluricGame` imports render backend or app targets.
- low-level engine modules import `TelluricRenderExtraction`.
- engine modules import `TelluricAssetCooker` or `TelluricAssetCookerCore`.
- engine modules import `TelluricHeadlessLoop` or `TelluricHeadlessLoopCore`.
- low-level modules import `TelluricPersistence` outside allowed runtime/persistence boundaries.
- render contracts, runtime, or render extraction import `TelluricRenderMetal`.
- non-app sources contain app/window/view code such as `MTKView` or `NSWindow`;
- active sources contain `UIWindow`.

Phase 4 also runs a tiny repo-local seed validator smoke check from `scripts/check-architecture-guards.sh`.
