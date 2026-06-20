# Rendering

Phase 8 implements renderer-independent contracts in `TelluricRender`.

This is not a renderer backend. It defines stable data that future backends, debug tools, editor tools, replay tools, and runtime visualization systems can consume.

Phase 9 adds `TelluricRenderExtraction` as a separate bridge module. `TelluricRender` remains independent from runtime and backend modules.

## Contracts vs Backend

`TelluricRender` owns CPU-side render contracts:

- resource identifiers;
- camera snapshots;
- renderable instances;
- debug primitives;
- ordered render snapshots;
- stable render snapshot hashing.

It must not own:

- Metal buffers;
- command queues;
- pipeline states;
- textures;
- shaders;
- platform windows;
- SwiftUI or AppKit views;
- a render loop.

## Backend Neutrality

Render contracts are value types. They describe what a backend may render, not how it allocates, uploads, schedules, culls, shades, presents, or profiles.

`TelluricRender` depends on `TelluricCore`, `TelluricMath`, `TelluricDeterminism`, and the existing asset contract boundary. The dependency on `TelluricDeterminism` exists only so render snapshots can use `StableHasher`.

`TelluricRenderExtraction` may consume `TelluricRuntime` and `TelluricRender` together to produce render snapshots from runtime snapshots. That bridge must not move into `TelluricRender`, because render contracts should remain reusable by future backends, tools, apps, and tests without taking a runtime dependency.

## Metal Boundary

Metal belongs in `TelluricRenderMetal` only.

`TelluricRender` must not import:

```text
Metal
MetalKit
SwiftUI
AppKit
TelluricRuntime
TelluricRenderMetal
```

Phase 12 introduced the first `TelluricRenderMetal` skeleton. Phase 13 adds backend-level preparation for `DebugLine` primitives: CPU conversion into ordered scalar vertices, validation diagnostics, and optional Metal buffer creation when a device exists. Phase 17 adds a minimal drawable pass for debug lines when a caller supplies a drawable and render pass descriptor. The backend still does not create app/window/view code.

Phase 20 adds debug camera/projection control in the app-shell layer. `TelluricRender` remains unchanged as a backend-neutral contract module; it still does not know about AppKit events, keyboard controls, mouse wheels, or Metal uniforms.

Future Metal backend phases may translate resource identifiers into backend resources and own GPU lifetime, RenderGraph execution, command encoding, captures, debug markers, and profiling.

## Render Snapshot

`RenderSnapshot` contains:

- `EngineVersion`;
- `FrameIndex`;
- `CameraSnapshot`;
- ordered `RenderableInstance` values;
- ordered debug lines;
- ordered debug points;
- ordered debug labels;
- stable snapshot hash.

Snapshot arrays are canonicalized by deterministic sorting before hashing. Stable output must not depend on dictionary or set iteration.

## Camera Snapshot

`CameraSnapshot` is a render contract, not a gameplay camera.

It stores:

- stable camera ID;
- engine-space transform;
- perspective or orthographic projection values;
- aspect ratio.

It does not store input bindings, player state, camera controllers, platform view state, or app lifecycle data.

The app-shell debug camera introduced in Phase 20 is separate from `CameraSnapshot`. It is a UI-free helper in `TelluricGameAppCore` that derives `MetalDebugLineProjection` values for the current debug grid. It does not change renderer-independent camera contracts and is not a player or terrain camera.

## Debug Primitives

Debug primitives are generic:

- `DebugLine`;
- `DebugPoint`;
- `DebugLabel`.

They are backend-neutral and suitable for future chunk boundary, residency, simulation, or world-field visualization. They do not encode UI behavior, overlay controls, GPU resources, or tool-specific interaction state.

Runtime render extraction uses these primitives for flat chunk footprint visualization. The lines are debug contracts only; they are not terrain meshes and do not carry backend material, shader, or GPU resource state.

## Render Hashing

Render snapshots use:

```text
Telluric.RenderSnapshot.v1
```

The hash includes ordered version/frame/camera fields, ordered renderable instances, and ordered debug primitives. It uses `StableHasher`, not Swift's built-in `Hasher`.

## Metal Backend Skeleton

The backend skeleton currently supports:

- backend configuration;
- Metal availability and device capability reports;
- command queue creation when a device exists;
- accepting `RenderSnapshot`;
- debug line CPU conversion and Metal buffer preparation;
- debug line render pipeline creation;
- drawable-backed debug line command encoding when the app supplies a drawable;
- deterministic frame results;
- explicit unsupported diagnostics for renderable instances, texture/material binding, debug points, and debug labels.

Debug line drawing is still a debug visualization path only. It uses a simple backend-owned top-down orthographic projection for chunk footprint lines. There is still no terrain mesh rendering, material system, texture loading, asset rendering, gameplay camera, or render graph.

Phase 20 makes that top-down projection controllable from the app shell: the default view fits the generated chunk grid, viewport aspect is accounted for, zoom and pan adjust only debug visualization state, and reset refocuses the grid.

See `Docs/architecture/METAL_BACKEND.md`.

## Not Implemented In Phase 8

Phase 8 does not implement:

- GPU buffers or textures;
- shaders;
- RenderGraph;
- mesh generation;
- resource loading;
- app/window/view code;
- gameplay cameras;
- tools UI;
- audio, motion, or ML.

## Runtime Extraction Boundary

Runtime render extraction is implemented in `TelluricRenderExtraction`, not `TelluricRender`.

`TelluricRenderExtraction` is still backend-neutral and still future-compatible with Metal. It produces `RenderSnapshot` values using runtime residency data, but it does not allocate resources, load assets, generate meshes, create windows, or render frames.
