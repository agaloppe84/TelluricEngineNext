# Metal Backend

Phase 12 introduces `TelluricRenderMetal`, the isolated Metal backend module.

This is the first backend boundary for rendering. It is not an app, not a window, not an `MTKView`, not a render loop, not terrain mesh generation, not runtime integration, and not gameplay.

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

Only `Sources/TelluricRenderMetal` may import:

```text
Metal
MetalKit
```

Phase 12 uses `Metal` only. `MetalKit` is not needed because there is no app, window, drawable view, or presentation layer.

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

## Current Backend Capabilities

The backend skeleton can:

- report backend configuration;
- attempt `MTLCreateSystemDefaultDevice()`;
- create a command queue when a device exists;
- report device availability and command queue availability;
- accept a `RenderSnapshot`;
- return a deterministic `MetalRenderFrameResult`;
- emit explicit diagnostics for unsupported snapshot content.

It does not claim that drawing occurred.

## Explicitly Unsupported

Phase 12 reports unsupported diagnostics for:

- renderable instance drawing;
- mesh/material/texture binding;
- debug line drawing;
- debug point drawing;
- debug label drawing;
- drawable presentation.

Unsupported content is an error in the frame result. This prevents the backend from silently pretending to render data it cannot draw yet.

## No App, Window, Or MTKView

`TelluricRenderMetal` does not create:

- an Xcode project;
- an app target;
- a window;
- an `MTKView`;
- a render loop tied to display refresh;
- a platform event lifecycle.

Future apps or tools may provide drawables and presentation policy above this backend boundary.

## Future Draw Pipeline

The future real draw pipeline can extend this target with:

- shader libraries;
- render pipeline state creation;
- render graph scheduling;
- GPU resource residency;
- mesh upload from renderer-independent mesh contracts;
- debug primitive rendering;
- capture/profiling hooks.

Those steps must preserve the same boundary: world, runtime, simulation, assets, and render contracts remain backend-neutral.

## Not Implemented In Phase 12

Phase 12 does not implement:

- shader code;
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
