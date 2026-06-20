# Render Extraction

Phase 9 implements `TelluricRenderExtraction`, the backend-neutral bridge from `RuntimeSnapshot` to `RenderSnapshot`.

This is not a renderer backend, app, render loop, mesh generator, or Metal integration.

## Dependency Direction

`TelluricRenderExtraction` depends on:

```text
TelluricCore
TelluricDiagnostics
TelluricMath
TelluricRender
TelluricRuntime
TelluricWorld
TelluricTerrain
```

`TelluricRuntime` does not import `TelluricRender`, and `TelluricRender` does not import `TelluricRuntime`. The bridge sits above both contracts so future apps, CLI tools, and debug systems can request render snapshots without reversing either boundary.

Lower engine modules must not import `TelluricRenderExtraction`.

`TelluricTerrain` is an allowed extraction dependency as of Phase 22. Runtime snapshots currently store aggregate chunk payload hashes rather than full terrain payloads, so terrain debug preview regenerates the same deterministic terrain payload for each resident chunk from the snapshot's world config, engine version, runtime terrain settings, and chunk coordinate. This keeps runtime snapshots compact and keeps Metal free of terrain contracts.

## Extraction Model

`RuntimeRenderExtractor` accepts:

- a `RuntimeSnapshot`;
- a `RuntimeRenderExtractionConfig`;
- a caller-provided `CameraSnapshot`.

It returns `RuntimeRenderExtractionResult`, containing:

- the source runtime snapshot;
- a backend-neutral `RenderSnapshot`;
- extraction diagnostics;
- success state.

The extractor is synchronous and pure. It does not mutate runtime state and does not allocate backend resources.

## Chunk Debug Primitives

For each resident runtime chunk, extraction can produce:

- four `DebugLine` values for the chunk footprint;
- one optional `DebugLabel` with chunk coordinates;
- one optional `DebugPoint` at the chunk center.

Phase 21 extends this line-based debug output with optional visual layers:

- world X/Z axis lines;
- a small line cross at world origin;
- optional resident chunk center line crosses;
- accent boundary lines around chunk `(0, 0)`;
- a secondary outline around the current resident streaming footprint.

Chunk debug boundaries use the runtime world config chunk size and `ChunkCoord.x/z`. The lines are emitted in world coordinates on a flat configurable y plane, defaulting to `y = 0`.

These lines are debug visualization contracts. They are not terrain meshes, collision geometry, GPU buffers, material assignments, or biome rendering.

The default visual layer set uses deterministic backend-neutral colors from `TelluricRender`: neutral chunk boundaries, red X axis, blue Z axis, yellow origin marker, green central chunk highlight, purple streaming bounds, and pale-blue optional center crosses. No colors are random or asset-driven.

A radius 1 / chunk size 16 resident grid now produces 48 default debug lines: 36 chunk-boundary lines, 2 axis lines, 2 origin-marker lines, 4 central chunk accent lines, and 4 streaming-footprint lines. Optional chunk center crosses add 2 lines per resident chunk.

## Terrain Height Debug Preview

Phase 22 adds an optional sparse terrain height preview. Extraction uses the existing deterministic `DeterministicTerrainGenerator` and emits line-only terrain wireframes from `(chunkSize + 1) x (chunkSize + 1)` heightfields. The positive boundary sample row/column is included, so neighboring chunks share aligned edge samples.

The terrain preview:

- connects sampled heightfield points in local X and Z directions;
- uses world-space X/Z offsets from integer `ChunkCoord` and `WorldConfig.chunkSize`;
- stores scaled terrain height in the debug line Y coordinate;
- uses a configurable positive sample stride, defaulting to 4 for the app shell;
- emits deterministic `RenderColor.debugTerrainWireframe` lines;
- validates stride, height scale, base Y, finite generated heights, and expected dimensions.

This is not terrain mesh rendering. It does not create triangles, normals, materials, textures, GPU terrain buffers, collision, physics, lighting, biome materials, or asset loading.

For a radius 1 / chunk size 16 app-shell run with stride 4, terrain preview adds 360 terrain wireframe lines. With the polished 48-line grid enabled, the expected default app-shell line count is 408 debug lines. Phase 23 leaves this line count unchanged while making the app-shell default projection oblique and increasing the default height exaggeration to 2.0 for readability.

Negative chunk coordinates use the same integer chunk coordinate assumptions as streaming and world contracts. Extreme coordinates that overflow integer footprint calculation are reported as diagnostics.

## Deterministic Ordering

Extraction iterates resident chunk records in deterministic chunk-coordinate order. `RenderSnapshot` then canonicalizes debug lines, points, and labels before hashing.

The extraction path must not depend on dictionary or set iteration order, system randomness, wall-clock time, or Swift's built-in `Hasher`.

Layer toggles alter the ordered debug primitive set and therefore intentionally alter the render snapshot hash. This is useful for deterministic visual debugging and report comparison.

Terrain-preview toggles and stride/height-exaggeration options also alter the ordered debug line set and render snapshot hash by design. Projection-mode and oblique-strength controls alter Metal debug-line uniforms in the app shell; they do not alter extraction output unless height exaggeration changes the line Y values.

## Camera Boundary

The caller supplies a `CameraSnapshot` from `TelluricRender`.

This remains a render contract:

- no gameplay camera;
- no player coupling;
- no input controls;
- no platform view state.

## Metal Remains Outside Extraction

`TelluricRenderExtraction` must not import:

```text
Metal
MetalKit
SwiftUI
AppKit
TelluricRenderMetal
```

`TelluricRenderMetal` can consume the extracted `RenderSnapshot` as a backend client. Phase 13 can prepare extracted debug chunk boundary lines into CPU-side Metal vertices and, when a device exists, a Metal vertex buffer. Phase 17 can draw those debug lines into a caller-provided drawable through a debug-only projection. Phase 23 lets the app shell choose top-down or oblique-height projection without making extraction import Metal.

Extraction still does not allocate GPU resources, compile shaders, encode command buffers, create windows, or run a render loop. The bridge only produces backend-neutral render contracts.

## Not Implemented In Phase 9

Phase 9 does not implement:

- Metal or MetalKit;
- GPU buffers or shaders;
- app/window/view code;
- render loop orchestration;
- terrain mesh generation;
- asset loading;
- gameplay cameras;
- tools UI;
- audio, motion, or ML.

Phase 21 still does not implement GPU text labels or point drawing in Metal. Essential polish uses `DebugLine` primitives because those are currently rendered by the backend.
