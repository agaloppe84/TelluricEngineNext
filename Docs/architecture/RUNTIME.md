# Runtime

Phase 7 implements the first durable runtime orchestration layer in `TelluricRuntime`.

The runtime is the engine shell. It coordinates existing engine systems, but it is not an app, not gameplay, not rendering, not UI, and not an async job system.

## Runtime vs App

`TelluricRuntime` has no window, event loop, input device handling, SwiftUI, AppKit, Metal, or platform lifecycle code.

Future apps will call into the runtime and provide engine-level inputs such as streaming observers and simulation input frames. The runtime returns deterministic snapshots and diagnostics that apps, tools, replay inspectors, and future render contracts can consume.

Phase 8 adds renderer-independent `RenderSnapshot` contracts in `TelluricRender`. Runtime still does not import render contracts or build render snapshots; a future extraction layer can translate runtime/world/simulation state into render snapshots without reversing dependencies.

## Runtime vs Gameplay

Runtime code must not know about:

- player;
- camera;
- NPCs;
- combat;
- inventory;
- quests;
- factions;
- abilities;
- RPG stats.

It uses neutral `StreamingObserver` values and engine-neutral `SimulationInputFrame` commands.

## Runtime vs Streaming Planner

`TelluricStreaming` remains a pure planner:

```text
observers + config + residency snapshot -> ChunkStreamingPlan
```

`TelluricRuntime` consumes that plan synchronously:

```text
ChunkStreamingPlan
  -> generate requested chunks
  -> keep desired resident chunks
  -> evict undesired chunks
  -> build RuntimeSnapshot
```

The runtime owns chunk residency records. The planner does not generate chunks, persist chunks, schedule jobs, render, or mutate runtime state.

## Runtime vs Simulation

`TelluricSimulation` owns fixed tick state changes. Runtime supplies one `SimulationInputFrame` per runtime step and stores the resulting `SimulationSnapshot`.

Invalid simulation tick order is surfaced as diagnostics. The runtime does not reinterpret simulation rules or silently advance the simulation when `TelluricSimulation` rejects a frame.

## Synchronous Residency

Phase 7 residency is synchronous and deterministic:

1. Validate runtime config.
2. Build a `ChunkStreamingPlan` from current residency and observers.
3. Generate requested chunks through the existing deterministic world pipeline.
4. Keep resident chunks still desired by the plan.
5. Evict resident chunks outside the desired set.
6. Step the simulation.
7. Commit the new runtime state only when no error diagnostics were produced.

This is intentionally not async streaming. Future runtime phases can add scheduling, budgets, cancellation, persistence reads, and background generation without changing the deterministic snapshot contract.

## Runtime Snapshot

`RuntimeSnapshot` is ordered and JSON-friendly. It contains:

- `RuntimeConfig`;
- `RuntimeState`;
- ordered chunk records;
- the current `SimulationSnapshot`;
- ordered diagnostics;
- success state;
- stable runtime hash.

Public runtime arrays are sorted deterministically. Hashing never depends on dictionary or set iteration.

## Runtime Hashing

Runtime snapshots use:

```text
Telluric.RuntimeSnapshot.v1
```

The hash includes ordered runtime config, runtime state, chunk records, simulation snapshot contents, diagnostics, and success state.

Runtime hashes use `StableHasher`, not Swift's built-in `Hasher`.

## Not Implemented In Phase 7

Phase 7 does not implement:

- rendering;
- `RenderSnapshot`;
- Metal or MetalKit;
- mesh generation;
- asset loading or cooking behavior;
- persistence and save formats;
- gameplay;
- player or camera concepts;
- app lifecycle;
- UI or tools UI;
- async jobs;
- audio, motion, or ML.
