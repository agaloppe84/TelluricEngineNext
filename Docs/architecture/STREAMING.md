# Streaming

Phase 5 implements the durable chunk streaming planner in `TelluricStreaming`.

This is a pure planning layer. It decides which chunks should be requested, kept, or evicted. It does not generate chunks, run async jobs, schedule runtime work, build meshes, render, load assets, know about players or cameras, or own gameplay behavior.

## Planner vs Runtime Streaming

The planner is synchronous and deterministic:

```text
observers + config + residency snapshot -> ChunkStreamingPlan
```

Future runtime streaming will consume this plan and decide how to schedule terrain/biome generation, persistence reads, asset loading, cancellation, prioritization, and eviction. Those runtime behaviors are intentionally outside Phase 5.

Phase 7 introduces the first runtime consumer of the plan. `TelluricRuntime` passes ordered runtime residency into the planner, generates requested chunks synchronously, keeps desired resident chunks, and evicts undesired chunks. The planner remains pure and does not mutate runtime state or generate data.

## Observer Coordinates

`StreamingObserver` stores an integer world-cell position:

```text
StreamingObserver.worldPosition: Int3
```

This keeps observer-to-chunk conversion exact. Future runtime code that tracks floating-point player or camera transforms must quantize to integer world cells before calling the planner.

Conversion uses floor division:

```text
chunk.x = floor(world.x / chunkSize)
chunk.y = floor(world.y / chunkSize)
chunk.z = floor(world.z / chunkSize)
```

That means world position `x = -1` with `chunkSize = 16` maps to chunk `x = -1`, not chunk `0`.

## Radius Policy

Phase 5 uses a horizontal square radius around each observer chunk:

```text
x in center.x - radius ... center.x + radius
z in center.z - radius ... center.z + radius
y = center.y
```

Radius `0` requests one chunk. Radius `1` requests nine chunks. Radius `2` requests twenty-five chunks.

The planner validates that `chunkSize` is positive and `radius` is non-negative.

## Deterministic Ordering

Planner output arrays are ordered. They must not rely on dictionary or set iteration.

Desired chunks are sorted by:

1. Manhattan distance from the nearest observer chunk;
2. squared horizontal distance;
3. observer ordinal after deterministic observer sorting;
4. chunk coordinate;
5. observer ID list.

Manhattan distance is the primary priority because it is cheap, integer-only, and produces stable expanding rings around the observer. Squared distance is retained as a secondary deterministic priority field for future policies.

Multiple observers are sorted by observer ID and then world position. If multiple observers want the same chunk, the planner merges them into one `ChunkStreamingRequest` with an ordered observer ID list and the best priority.

## Request / Keep / Evict

The planner compares desired chunks with a `ChunkResidencySnapshot`.

`chunksToRequest` contains desired chunks that are absent or currently in a non-keep state:

```text
unloaded
evicting
failed
```

`chunksToKeep` contains desired chunks already usable or in progress:

```text
requested
generating
ready
resident
```

`chunksToEvict` contains existing residency records outside the desired set.

An `unloaded` chunk should be omitted from `ChunkResidencySnapshot`; recording it is treated as an inconsistent snapshot and produces an error diagnostic.

## Plan Hash

`ChunkStreamingPlan.stableHash` uses:

```text
Telluric.ChunkStreamingPlan.v1
```

The hash includes ordered config, observers, request/keep/evict arrays, diagnostics, and success state through `StableHasher`. It does not use Swift's built-in `Hasher`.

## Not Implemented In Phase 5

Phase 5 does not implement:

- async jobs;
- runtime orchestration;
- terrain or biome generation;
- chunk persistence;
- mesh generation;
- rendering;
- asset loading;
- gameplay;
- player or camera concepts;
- UI or tools UI;
- audio, motion, or ML.
