# Metal Backend

Phase 12 introduced `TelluricRenderMetal`, the isolated Metal backend module.
Phase 13 adds the first backend-level debug line preparation path.

This is the backend boundary for rendering. It is not an app, not a window, not an `MTKView`, not a render loop, not terrain mesh generation, not runtime integration, and not gameplay.

## Backend Module vs Render Contracts

`TelluricRender` owns backend-neutral render contracts:

- resource identifiers;
- camera snapshots;
- renderable instances;
- debug primitives;
- render snapshots;
- stable render snapshot hashes.

`TelluricRenderMetal` consumes those contracts and owns the Apple GPU API boundary. Dependency direction is one-way:

```text
TelluricRenderMetal -> TelluricRender -> foundation/contracts
```

`TelluricRender` must never import `TelluricRenderMetal`, `Metal`, or `MetalKit`.

## Metal Isolation

Only `Sources/TelluricRenderMetal` may import Metal APIs inside engine/backend modules:

```text
Metal
```

`TelluricRenderMetal` still uses `Metal` only. `MetalKit` is not needed inside the backend because the backend does not own an app, window, drawable view, or presentation layer.

Phase 16 adds `TelluricGameApp` above the engine boundary. That app-shell target may import `AppKit`, `MetalKit`, and `Metal` as platform glue for a minimal `MTKView`. This exception does not allow Metal or MetalKit imports in engine modules.

The following modules must not import Metal APIs:

- `TelluricCore`;
- `TelluricMath`;
- `TelluricDiagnostics`;
- `TelluricWorld`;
- `TelluricTerrain`;
- `TelluricBiomes`;
- `TelluricStreaming`;
- `TelluricSimulation`;
- `TelluricRuntime`;
- `TelluricRender`;
- `TelluricRenderExtraction`;
- `TelluricAssets`;
- `TelluricPersistence`.
- `TelluricGame`;
- `TelluricGameAppCore`.

## Current Backend Capabilities

The backend skeleton can:

- report backend configuration;
- attempt `MTLCreateSystemDefaultDevice()`;
- create a command queue when a device exists;
- report device availability and command queue availability;
- accept a `RenderSnapshot`;
- convert ordered `DebugLine` primitives into ordered CPU-side Metal debug line vertices;
- validate debug line endpoint coordinates;
- create a Metal vertex buffer for debug lines when a Metal device context exists;
- return a deterministic `MetalRenderFrameResult`;
- emit explicit diagnostics for unsupported snapshot content.

It does not claim that drawing occurred.

## Debug Line Pipeline Status

Phase 13 supports debug line preparation, not on-screen debug line drawing.

The pipeline is:

1. consume ordered `DebugLine` values from a `RenderSnapshot`;
2. reject lines with NaN or infinite endpoint coordinates;
3. convert each valid line to two scalar `MetalDebugLineVertex` values;
4. preserve source ordering in the vertex array;
5. pack the vertices into an internal Metal-side layout;
6. create an `MTLBuffer` when a `MetalDeviceContext` is available.

The public debug line vertex contract stores scalar position and color fields. The internal packed representation is owned by `TelluricRenderMetal`; renderer-independent contracts are not treated as a GPU ABI.

When Metal is unavailable, CPU conversion still works and buffer creation reports `render.metal.debug_line.buffer_unavailable` instead of failing tests that do not require a GPU.

Phase 15 adds `telluric-headless-loop` as a top-level CLI client of this backend. The tool passes extracted `RenderSnapshot` values into `MetalRenderBackend` and records prepared debug line counts. In GPU-less or sandboxed environments, Metal unavailable and debug-line buffer unavailable diagnostics are treated as non-fatal warnings by the tool so the game/runtime/render-extraction chain can still be validated.

Phase 16 adds `telluric-game-app` as a top-level macOS host. It can create an `MTKView` when a Metal device exists, then calls the same backend preparation path. It still does not provide drawable rendering to the backend.

## Explicitly Unsupported

The backend still reports unsupported diagnostics for:

- renderable instance drawing;
- mesh/material/texture binding;
- debug point drawing;
- debug label drawing;
- drawable presentation.

Phase 13 no longer reports debug lines as simply unsupported when they can be prepared. It still does not implement shader compilation, render pass encoding, drawable presentation, or visible line drawing.

Unsupported content is an error in the frame result. This prevents the backend from silently pretending to render data it cannot draw yet.

## Backend Has No App, Window, Or MTKView

`TelluricRenderMetal` does not create:

- an Xcode project;
- an app target;
- a window;
- an `MTKView`;
- a render loop tied to display refresh;
- a platform event lifecycle.

Apps or tools may provide drawables and presentation policy above this backend boundary. Phase 16 creates only the first app-shell host; it does not add backend drawable presentation yet.

The headless loop does not provide a drawable. The app shell creates a view host but still exercises backend acceptance and debug line preparation only.

## Future Draw Pipeline

The future real draw pipeline can extend this target with:

- shader libraries;
- render pipeline state creation;
- render graph scheduling;
- GPU resource residency;
- mesh upload from renderer-independent mesh contracts;
- command encoding for prepared debug line buffers;
- debug point and debug label rendering;
- capture/profiling hooks.

Those steps must preserve the same boundary: world, runtime, simulation, assets, and render contracts remain backend-neutral.

## Test Strategy

Metal backend tests are split between CPU-only behavior and conditional GPU behavior.

CPU tests validate debug line conversion, ordering, coordinate preservation, color preservation, invalid coordinate diagnostics, and empty batch success. GPU buffer tests attempt `MetalDeviceContext.makeResult()` and only require an `MTLBuffer` when a Metal device is actually available. No test requires a display, window, drawable, `MTKView`, app lifecycle, or platform UI.

## Not Implemented In Phase 13

Phase 13 does not implement:

- shader code;
- render pipeline state;
- command encoder drawing;
- `MTKView`;
- drawable presentation;
- app/window creation;
- terrain mesh generation;
- asset loading or GPU upload;
- runtime integration;
- render graph execution;
- gameplay cameras;
- editor UI;
- audio, motion, or ML.

Phase 16 still does not implement visible debug line drawing, drawable presentation through `TelluricRenderMetal`, terrain mesh generation, runtime-owned render-loop integration, or gameplay rendering.
