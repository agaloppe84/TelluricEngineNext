# Rendering

Phase 8 implements renderer-independent contracts in `TelluricRender`.

This is not a renderer backend. It defines stable data that future backends, debug tools, editor tools, replay tools, and runtime visualization systems can consume.

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

## Metal Boundary

Metal belongs in the future `TelluricRenderMetal` backend only.

`TelluricRender` must not import:

```text
Metal
MetalKit
SwiftUI
AppKit
TelluricRuntime
TelluricRenderMetal
```

The future Metal backend may consume `RenderSnapshot`, translate resource identifiers into backend resources, and own GPU lifetime, RenderGraph execution, command encoding, captures, debug markers, and profiling.

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

## Debug Primitives

Debug primitives are generic:

- `DebugLine`;
- `DebugPoint`;
- `DebugLabel`.

They are backend-neutral and suitable for future chunk boundary, residency, simulation, or world-field visualization. They do not encode UI behavior, overlay controls, GPU resources, or tool-specific interaction state.

## Render Hashing

Render snapshots use:

```text
Telluric.RenderSnapshot.v1
```

The hash includes ordered version/frame/camera fields, ordered renderable instances, and ordered debug primitives. It uses `StableHasher`, not Swift's built-in `Hasher`.

## Not Implemented In Phase 8

Phase 8 does not implement:

- Metal or MetalKit;
- `TelluricRenderMetal`;
- GPU buffers or textures;
- shaders;
- RenderGraph;
- mesh generation;
- resource loading;
- runtime render extraction;
- app/window/view code;
- gameplay cameras;
- tools UI;
- audio, motion, or ML.
