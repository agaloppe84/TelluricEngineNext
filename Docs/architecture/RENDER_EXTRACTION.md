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
```

`TelluricRuntime` does not import `TelluricRender`, and `TelluricRender` does not import `TelluricRuntime`. The bridge sits above both contracts so future apps, CLI tools, and debug systems can request render snapshots without reversing either boundary.

Lower engine modules must not import `TelluricRenderExtraction`.

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

Chunk debug boundaries use the runtime world config chunk size and `ChunkCoord.x/z`. The lines are emitted in world coordinates on a flat configurable y plane, defaulting to `y = 0`.

These lines are debug visualization contracts. They are not terrain meshes, collision geometry, GPU buffers, material assignments, or biome rendering.

Negative chunk coordinates use the same integer chunk coordinate assumptions as streaming and world contracts. Extreme coordinates that overflow integer footprint calculation are reported as diagnostics.

## Deterministic Ordering

Extraction iterates resident chunk records in deterministic chunk-coordinate order. `RenderSnapshot` then canonicalizes debug lines, points, and labels before hashing.

The extraction path must not depend on dictionary or set iteration order, system randomness, wall-clock time, or Swift's built-in `Hasher`.

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

`TelluricRenderMetal` can consume the extracted `RenderSnapshot` as a backend client. Phase 13 can prepare extracted debug chunk boundary lines into CPU-side Metal vertices and, when a device exists, a Metal vertex buffer. Phase 17 can draw those debug lines into a caller-provided drawable through a debug-only top-down projection.

Extraction still does not allocate GPU resources, compile shaders, encode command buffers, create windows, or run a render loop. The bridge only produces backend-neutral render contracts.

## Not Implemented In Phase 9

Phase 9 does not implement:

- Metal or MetalKit;
- GPU buffers or shaders;
- app/window/view code;
- render loop orchestration;
- terrain mesh generation;
- terrain height visualization;
- asset loading;
- gameplay cameras;
- tools UI;
- audio, motion, or ML.
