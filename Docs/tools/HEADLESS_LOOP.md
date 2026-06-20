# Headless Loop

`telluric-headless-loop` is a repo-local vertical integration smoke tool.

It proves that the current engine/game/render contract chain is connected without creating an app, window, `MTKView`, SwiftUI/AppKit UI, gameplay systems, terrain meshes, drawables, or an Xcode project.

## Command

```sh
swift run telluric-headless-loop --seed 12345 --radius 1 --chunk-size 16 --vertical-scale 8 --ticks 3 --report Tools/benchmarks/headless_loop_report.json
```

Options:

- `--seed <UInt64>`: deterministic world seed.
- `--radius <Int>`: non-negative chunk streaming radius.
- `--chunk-size <Int>`: positive world chunk size.
- `--vertical-scale <Float>`: finite positive terrain vertical scale.
- `--ticks <Int>`: positive fixed tick count.
- `--report <path>`: optional repo-relative deterministic JSON report path.
- `--verbose`: print ordered per-tick hashes.
- `--help`: print help.

Report paths are repo-relative. Absolute paths and `..` traversal are rejected.

## Chain

The tool runs:

```text
GameInputFrame
  -> GameSession
  -> TelluricRuntime
  -> RuntimeSnapshot
  -> RuntimeRenderExtractor
  -> RenderSnapshot
  -> MetalRenderBackend
  -> debug line CPU conversion / optional Metal buffer preparation
  -> Persistence snapshot package summaries
  -> HeadlessLoopReport
```

The game input is deterministic and ordered. Tick `0` spawns one controllable entity through the game-layer contract. Later ticks apply a simple ordered movement intent. This is not a player controller and not gameplay; it is the smallest engine-safe input that exercises the existing simulation path.

## Report

`HeadlessLoopReport` contains:

- tool and engine versions;
- seed, radius, chunk size, vertical scale, and tick count;
- final runtime and render snapshot stable hashes;
- final prepared debug line and vertex counts;
- Metal availability and command queue summary;
- ordered persistence package summaries for the final runtime and render snapshots;
- ordered per-tick summaries;
- ordered diagnostics;
- root report hash;
- success boolean.

The report intentionally excludes wall-clock timestamps and performance timing. It uses ordered arrays rather than dictionaries for stable output.

Because the tool uses the shared render extraction defaults, radius 1 / chunk size 16 now prepares the polished debug grid line set: chunk boundaries, X/Z axes, origin marker, central chunk highlight, and streaming footprint outline.

## Metal Behavior

The tool imports `TelluricRenderMetal` as a top-level client. It does not import `Metal` directly.

When a Metal device and command queue are available, the backend prepares debug line data and may create a Metal vertex buffer.

When Metal is unavailable, CPU render extraction and debug line conversion still run. Metal unavailable and debug-line buffer unavailable diagnostics are recorded as warnings in the headless report so sandboxed or GPU-less environments can still validate the architecture chain.

Unsupported renderable instances, debug points, debug labels, drawable presentation, invalid debug lines, runtime failures, extraction failures, and persistence package failures remain fatal.

## Persistence

The tool uses `TelluricPersistence` from the caller side. It wraps the final `RuntimeSnapshot` and final `RenderSnapshot` in generic `SnapshotPackage` envelopes and records ordered package summaries.

The persistence layer does not import runtime, render, render extraction, Metal, or this tool.

## Not Implemented

This phase does not implement:

- `TelluricGameApp`;
- app/window/view code;
- `MTKView`;
- drawable presentation;
- platform input;
- terrain mesh generation;
- full asset loading;
- advanced gameplay;
- player controller;
- gameplay camera;
- combat, inventory, quests, factions, or RPG stats;
- editor UI;
- audio, motion, or ML.
