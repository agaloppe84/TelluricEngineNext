# Simulation

Phase 6 implements the durable ECS and simulation contract layer:

```text
TelluricECS
TelluricSimulation
```

This is engine infrastructure. It is not gameplay, not a game layer, not runtime orchestration, and not UI.

## ECS Primitives vs Gameplay Systems

`TelluricECS` defines stable, engine-neutral data primitives:

- `EntityID`
- `EntityGeneration`
- `ComponentTypeID`
- `ComponentKey`
- `PositionComponent`
- `VelocityComponent`
- `ComponentValue`
- `EntityRecord`
- `EntitySnapshot`
- `ComponentStorage`

The built-in components are intentionally neutral. Position and velocity are basic engine state, not player movement, combat, inventory, quests, AI, factions, abilities, or RPG stats.

`ComponentStorage` is a minimal sorted-array storage contract. It is not a full ECS framework. It exists so future simulation, runtime, persistence, replay, and tools can agree on ordered snapshots before higher-performance storage internals are introduced.

## Fixed Tick Simulation

`TelluricSimulation` uses fixed ticks:

```text
SimulationInputFrame(tick: N)
  -> ordered SimulationCommand values
  -> SimulationWorld.step(...)
  -> SimulationSnapshot(tick: N + 1)
```

`SimulationTickRate` controls the fixed delta. The baseline simulation applies commands first, then integrates `VelocityComponent` into `PositionComponent` using the fixed delta.

This is not a physics engine. It is the smallest durable tick contract that proves state changes are deterministic and replayable.

## Command Application

`SimulationCommand` is engine-neutral:

- create entity;
- destroy entity;
- set position;
- set velocity;
- apply translation.

Commands are applied in the order stored in `SimulationInputFrame.commandBuffer`. Command order is part of the deterministic input contract and can change the resulting snapshot hash.

Invalid commands produce ordered `DiagnosticReport` entries. Invalid tick order is rejected and does not advance the simulation world.

Phase 14 adds `TelluricGame` above simulation. Game intents are mapped into these existing engine-neutral simulation commands before runtime stepping. `TelluricSimulation` does not import game code and does not gain player, controller, combat, inventory, quest, faction, ability, or RPG stat concepts.

## Replay-Friendly Input Frames

`SimulationInputFrame` stores one tick and an ordered `SimulationCommandBuffer`.

`ReplayInputLog` stores ordered input frames and is JSON-friendly. It is meant for future replay, seed validation, debugging, and CLI inspection. It does not store wall-clock time.

Phase 11 persistence can wrap replay logs through `ReplayPackage<ReplayInputLog>` and simulation snapshots through `SnapshotPackage<SimulationSnapshot>`. Simulation still does not import persistence; the package boundary belongs above simulation or inside `TelluricPersistence`.

## Snapshot Ordering

`EntitySnapshot` and `SimulationSnapshot` use ordered arrays. Entity records are sorted by `EntityID`; component values are sorted by `ComponentTypeID`.

No stable output may depend on dictionary or set iteration order.

## Simulation Hashing

Stable hash domains:

```text
Telluric.EntitySnapshot.v1
Telluric.SimulationSnapshot.v1
Telluric.ReplayInputLog.v1
```

Hashes use `StableHasher`, ordered values, and explicit domain strings. Swift's built-in `Hasher` is not used for stable simulation hashes.

## Dependency Rules

`TelluricECS` may depend on foundation modules only:

```text
TelluricCore
TelluricMath
TelluricDeterminism
```

`TelluricSimulation` may depend on:

```text
TelluricCore
TelluricMath
TelluricDeterminism
TelluricDiagnostics
TelluricECS
```

Simulation must not import runtime, render, UI, Metal, game, tool UI, audio, motion, or ML modules.
Simulation must also not import `TelluricPersistence`; persistence may wrap simulation payloads, but simulation remains lower-level.

`TelluricRuntime` may depend on `TelluricSimulation` and call `SimulationWorld.step(...)`. The dependency remains one-way: simulation never imports runtime. Runtime reports simulation diagnostics and does not silently advance simulation state when an input frame is rejected.

`TelluricGame` may depend on `TelluricSimulation` as a higher-level client and produce `SimulationInputFrame` values. That dependency also remains one-way.

## Not Implemented In Phase 6

Phase 6 does not implement:

- gameplay;
- player or camera concepts;
- NPCs;
- combat;
- inventory;
- quests;
- factions;
- abilities;
- RPG stats;
- runtime orchestration;
- async jobs;
- streaming integration;
- rendering;
- asset loading;
- save file formats;
- UI or tools UI;
- audio, motion, or ML.
