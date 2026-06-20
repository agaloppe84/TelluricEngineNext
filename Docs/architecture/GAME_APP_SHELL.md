# Game App Shell

Phase 16 creates the first minimal macOS app shell for Telluric Engine Next.
Phase 17 adds the first drawable debug-line render pass.
Phase 18 hardens the local app run and visual smoke workflow.
Phase 20 adds debug-only camera and projection controls for viewing the chunk grid.
Phase 21 adds debug visual polish layers and quieter app-run logging.

This is a SwiftPM executable host, not a traditional Xcode project or packaged app bundle. It exists to prove that the existing engine/game/runtime/render-extraction/Metal-preparation pipeline can be hosted visually without moving engine behavior into UI code.

## App Shell vs Engine

`TelluricGameApp` is a top-level client. It must never become an engine module.

```text
TelluricGameApp -> TelluricGameAppCore -> TelluricGame -> TelluricRuntime -> engine modules
```

Engine modules must not import `TelluricGameApp` or `TelluricGameAppCore`.

`TelluricGameAppCore` is UI-free and testable. It owns the app-shell config, dry-run/smoke paths, stateful pipeline stepping, renderer-independent frame values, and deterministic-friendly diagnostics reports. `TelluricGameApp` owns only macOS process/window/view glue.

## App Shell vs Game Layer

`TelluricGame` remains app-free. It still owns game sessions, ordered game intents, and mapping into simulation commands.

The app shell creates deterministic `GameInputFrame` values through the same minimal intent path validated by the headless loop. Phase 20 adds platform input only for debug visualization controls. Those controls are not routed through `GameIntent`, do not mutate game/runtime state directly, and must not become player movement or a gameplay input layer.

## UI Import Isolation

Only `Sources/TelluricGameApp` may import:

```text
AppKit
MetalKit
```

`Sources/TelluricGameApp` may also import `Metal` as platform glue to create an `MTLDevice` for `MTKView`.

Engine modules, `TelluricGame`, `TelluricRuntime`, `TelluricRender`, `TelluricRenderExtraction`, `TelluricRenderMetal`, and `TelluricGameAppCore` must remain free of AppKit, SwiftUI, and app/window code. `TelluricRenderMetal` remains the only engine/backend target that may import `Metal`.

## What The App Can Currently Show

The app shell can:

- create a minimal macOS window;
- create an `MTKView` when a Metal device exists;
- initialize `GameSession` with deterministic config;
- step the existing game/runtime pipeline from the `MTKView` draw callback;
- extract a backend-neutral `RenderSnapshot`;
- pass that snapshot to `TelluricRenderMetal`;
- prepare debug line vertex data through the Metal backend;
- render debug chunk boundary lines into the current drawable when Metal and a drawable are available;
- log structured frame diagnostics.

The app currently shows a clear background plus flat chunk boundary debug lines. Those lines come from `RuntimeRenderExtractor` and are drawn through a debug-only top-down projection. They are not terrain meshes.

When Metal and a drawable are available, the app submits those debug lines through `TelluricRenderMetal` and reports attempted/succeeded draw calls. When Metal is unavailable, the app reports that state clearly and the no-window smoke path remains valid.

Phase 21 uses line-only debug primitives for visual polish because `DebugLine` rendering is the only confirmed drawable path. It does not rely on debug points or labels for essential visuals.

## Visual Layers

The app-shell default debug view enables:

- resident chunk boundaries;
- world X/Z axes;
- world origin marker;
- central chunk highlight for chunk `(0, 0)`;
- current streaming footprint outline.

Optional chunk center crosses are available but disabled by default to keep the radius 1 view readable.

Default colors are deterministic backend-neutral `RenderColor` values:

- chunk boundaries: neutral gray;
- X axis: red;
- Z axis: blue;
- origin marker: bright yellow;
- central chunk: green accent;
- streaming bounds: purple accent;
- optional chunk centers: pale blue.

For a radius 1 / chunk size 16 run, the default line set increases from the earlier 36 chunk-boundary lines to 48 total debug lines.

## Debug Camera

Phase 20 adds a UI-free debug camera model in `TelluricGameAppCore`:

- `DebugProjectionMode`;
- `DebugCameraConfig`;
- `DebugCameraState`;
- `DebugCameraControlIntent`;
- `DebugCameraValidationResult`;
- `DebugCameraProjectionResult`.

This is a debug visualization camera, not a gameplay camera. It stores only the data needed to frame the flat chunk grid: world-space center X/Z, vertical half extent, viewport aspect, and projection mode. It does not store input devices, player state, camera controllers, runtime entities, or gameplay intent.

The default camera fits the generated chunk grid with a small margin. For the common radius 1 / chunk size 16 smoke run, the default focus is centered on the generated 3-by-3 chunk footprint and scaled so the negative chunks, origin area, and positive chunks are visible without user input.

Invalid camera or viewport values are clamped or reset by `TelluricGameAppCore` and reported as diagnostics. The app diagnostics report includes the final camera center, half extent, projection extents, viewport size, projection mode, debug line counts, and draw success.

## Controls

`TelluricGameApp` owns the AppKit event glue. `TelluricGameAppCore` receives only platform-neutral `DebugCameraControlIntent` values.

Current controls:

- `+` or `=`: zoom in;
- `-` or `_`: zoom out;
- arrow keys: pan;
- `W`, `A`, `S`, `D`: pan;
- `0` or `R`: reset/focus the debug grid;
- `G`: toggle chunk boundaries;
- `X`: toggle world axes;
- `O`: toggle origin marker;
- `C`: toggle chunk center crosses;
- `H`: toggle central chunk highlight;
- `B`: toggle streaming radius bounds;
- `V`: toggle verbose frame logging;
- mouse wheel: zoom.

These controls are debug visualization controls only. They do not create a player controller, gameplay camera, editor UI, or general input system.

## Safe Run

Use the repo-local wrapper:

```sh
./scripts/game-app-safe.sh --dry-run
./scripts/game-app-safe.sh --smoke --frames 120
```

To open the minimal window from a local macOS shell:

```sh
./scripts/game-app-safe.sh --run --seed 12345 --radius 1 --chunk-size 16 --vertical-scale 8
./scripts/game-app-safe.sh --run --diagnostics-report Tools/benchmarks/game_app_visual_report.json
./scripts/game-app-safe.sh --run --frames 120 --seed 12345 --radius 1 --chunk-size 16 --vertical-scale 8 --diagnostics-report Tools/benchmarks/game_app_camera_report.json
./scripts/game-app-safe.sh --run --frames 120 --seed 12345 --radius 1 --chunk-size 16 --vertical-scale 8 --diagnostics-report Tools/benchmarks/game_app_visual_polish_report.json
```

The wrapper pins SwiftPM scratch, cache, config, security, home, and module-cache paths under `.build/`. Raw `swift run` can use user-level SwiftPM cache and configuration paths, so wrappers are preferred for Codex and validation work.

`./scripts/game-app-safe.sh --script-help` prints wrapper usage examples without launching the app.

If Metal is unavailable, the app shell falls back to a plain view and no drawable rendering occurs. The no-window dry-run and smoke paths still validate the game/runtime/render-extraction/debug-line preparation chain.

## Diagnostics Report

`--diagnostics-report <path>` writes a JSON report to a repo-relative path such as `Tools/benchmarks/game_app_visual_report.json`.

The report contains:

- seed, radius, chunk size, and vertical scale;
- requested and simulated frame counts;
- Metal availability and command queue capability;
- `MTKView` and drawable availability when known;
- final debug line and vertex counts;
- final drawn debug line and vertex counts;
- enabled debug visual layers;
- attempted and successful draw call counts;
- final debug camera center and half extent;
- final debug projection extents, mode, and viewport size;
- first warning or error, when present;
- ordered frame summaries;
- ordered diagnostics and severity counts;
- success state.

The deterministic report section does not include wall-clock timestamps.

## Not Implemented Yet

Phase 16 does not implement:

- an `.xcodeproj`;
- a packaged app bundle;
- terrain mesh generation;
- asset rendering;
- platform input;
- player controller or gameplay camera;
- combat, inventory, quests, factions, RPG stats;
- editor UI;
- audio, motion, or ML.

Phase 17 adds drawable debug-line rendering only. It still does not implement terrain rendering, materials, textures, asset loading, camera controls, player controls, or editor UI.

Phase 20 adds debug camera controls only. It still does not implement a gameplay camera, player input, terrain mesh rendering, asset rendering, editor UI, or a full input system.

Phase 21 adds debug visual polish only. It still does not implement terrain meshes, material or texture rendering, GPU text labels, editor UI, gameplay controls, or asset rendering.
