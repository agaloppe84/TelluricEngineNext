# Metal Backend

Phase 12 introduced `TelluricRenderMetal`, the isolated Metal backend module.
Phase 13 adds the first backend-level debug line preparation path.
Phase 17 adds the first minimal drawable debug-line render pass.
Phase 18 hardens app-shell visual smoke reporting around that drawable path.

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
- build a minimal debug line render pipeline from embedded shader source;
- encode debug line draw calls into a caller-provided render pass descriptor;
- present a caller-provided drawable;
- return a deterministic `MetalRenderFrameResult`;
- return an explicit `MetalDrawableRenderResult`;
- emit explicit diagnostics for unsupported snapshot content.

Headless preparation and drawable rendering are separate APIs. `render(snapshot:)` prepares and validates without a drawable. `renderDrawable(snapshot:descriptor:drawable:renderPassDescriptor:)` is the drawable path.

## Debug Line Pipeline Status

Phase 13 supports debug line preparation. Phase 17 adds on-screen debug line drawing when a drawable is supplied.

The pipeline is:

1. consume ordered `DebugLine` values from a `RenderSnapshot`;
2. reject lines with NaN or infinite endpoint coordinates;
3. convert each valid line to two scalar `MetalDebugLineVertex` values;
4. preserve source ordering in the vertex array;
5. pack the vertices into an internal Metal-side layout;
6. create an `MTLBuffer` when a `MetalDeviceContext` is available;
7. build a minimal Metal render pipeline state;
8. map line `x/z` world coordinates through a debug-only top-down orthographic projection;
9. encode `.line` primitives into the caller's render pass descriptor;
10. present the caller's drawable.

The public debug line vertex contract stores scalar position and color fields. The internal packed representation is owned by `TelluricRenderMetal`; renderer-independent contracts are not treated as a GPU ABI.

When Metal is unavailable, CPU conversion still works and buffer creation reports `render.metal.debug_line.buffer_unavailable` instead of failing tests that do not require a GPU.

Phase 15 adds `telluric-headless-loop` as a top-level CLI client of this backend. The tool passes extracted `RenderSnapshot` values into `MetalRenderBackend` and records prepared debug line counts. In GPU-less or sandboxed environments, Metal unavailable and debug-line buffer unavailable diagnostics are treated as non-fatal warnings by the tool so the game/runtime/render-extraction chain can still be validated.

Phase 16 adds `telluric-game-app` as a top-level macOS host. Phase 17 lets that app provide the current `MTKView` drawable and render pass descriptor to the backend. Phase 18 adds bounded app smoke/reporting around the same API without moving app lifecycle into the backend.

## Drawable Debug Line Pass

The drawable pass draws only `DebugLine` primitives from `RenderSnapshot`.

It uses:

- `MetalDrawableFrameDescriptor` for frame index, viewport, clear color, pixel format, and debug projection;
- `MetalDebugLineProjection` for a debug-only top-down orthographic mapping from world `x/z` to clip space;
- embedded minimal Metal shader source;
- the existing prepared debug line vertex buffer;
- caller-owned drawable and render pass descriptor.

The pass clears the drawable and draws line primitives. It does not interpret `CameraSnapshot` yet; the top-down projection is explicitly debug-only so chunk grids are visible before terrain/camera rendering exists.

## Explicitly Unsupported

The backend still reports unsupported diagnostics for:

- renderable instance drawing;
- mesh/material/texture binding;
- debug point drawing;
- debug label drawing;
- terrain mesh rendering;
- asset rendering.

Phase 17 no longer reports drawable debug-line presentation as unsupported when a drawable and render pass descriptor are supplied. The older headless `render(snapshot:)` API still reports drawable presentation as unsupported if the caller asks that preparation-only API to require a drawable.

Unsupported content is an error in the frame result. This prevents the backend from silently pretending to render data it cannot draw yet.

## Backend Has No App, Window, Or MTKView

`TelluricRenderMetal` does not create:

- an Xcode project;
- an app target;
- a window;
- an `MTKView`;
- a render loop tied to display refresh;
- a platform event lifecycle.

Apps or tools may provide drawables and presentation policy above this backend boundary. Phase 17 adds the backend draw call, but the backend still does not own the view or app lifecycle.

The headless loop does not provide a drawable. The app shell creates a view host and passes its drawable to the backend when Metal is available.

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

Drawable-path tests validate descriptor encoding, pipeline build-or-diagnose behavior, missing drawable diagnostics, and empty drawable-pass diagnostics without requiring a visible window.

App-shell smoke tests stay above the backend. They validate argument parsing, no-window smoke reports, and import boundaries without requiring a visible `MTKView`. A local user can run `./scripts/game-app-safe.sh --run` to visually verify that debug chunk boundaries draw when Metal and a drawable are available.

## Not Implemented In Phase 17

Phase 17 does not implement:

- terrain mesh generation;
- asset loading or GPU upload;
- runtime integration;
- render graph execution;
- persistent pipeline caching;
- material or texture binding;
- debug point drawing;
- debug label drawing;
- gameplay cameras;
- editor UI;
- audio, motion, or ML.

Phase 17 implements visible debug line drawing only when the app supplies a live Metal drawable.
