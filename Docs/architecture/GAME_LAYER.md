# Game Layer

Phase 14 implements the first durable game-layer contracts in `TelluricGame`.

This is a client layer above the engine runtime. It is not an app, not UI, not rendering, not Metal, not platform input handling, and not an RPG systems layer.

## Game Layer vs Engine

Engine modules own deterministic runtime, simulation, streaming, world generation, assets, persistence, rendering contracts, and backend boundaries.

`TelluricGame` sits above those modules:

```text
TelluricGame -> TelluricRuntime -> engine modules
```

The dependency must never reverse. Engine modules must not import `TelluricGame`, `TelluricGameApp`, or `TelluricGameAppCore`.

## Game Layer vs App

`TelluricGame` has no:

- Xcode project;
- app target;
- window;
- `MTKView`;
- SwiftUI or AppKit views;
- device input handling;
- platform lifecycle.

Phase 16 adds `TelluricGameApp` above the game layer as a minimal macOS host. The app shell creates deterministic app-shell frames and calls `GameSession`; it does not push AppKit, MetalKit, window state, or platform input types into `TelluricGame`.

Future app phases can translate keyboard, mouse, controller, touch, or accessibility input into `GameIntent` values. The current app shell does not implement platform input handling yet.

Phase 15 adds `telluric-headless-loop` as a CLI client of `TelluricGame`. It creates deterministic `GameInputFrame` values directly and feeds them into `GameSession` without platform input devices, an app bundle, UI, a player controller, or gameplay systems.

## Game Layer vs Runtime

`GameSession` owns a `TelluricRuntime` as a client. It maps ordered game intents into one ordered `SimulationInputFrame`, then steps runtime through `RuntimeStepInput`.

Runtime remains unaware of the game layer. Runtime still consumes only:

- neutral `StreamingObserver` values;
- engine-neutral `SimulationInputFrame` commands.

Invalid game intents are reported before runtime stepping. A failed mapping does not mutate the wrapped runtime.

The headless loop uses this exact boundary: it owns a `GameSession` as a client, steps it with ordered game input frames, then passes the resulting `RuntimeSnapshot` to render extraction. Runtime still does not know about game-layer types.

## Game Intents vs Simulation Commands

`GameIntent` is the first minimal game-level abstraction:

- spawn a controllable entity;
- move an entity by translation intent;
- set desired velocity.

`GameIntentMapper` converts those intents to existing engine-neutral `SimulationCommand` values:

- `spawnControllableEntity` -> `createEntity`;
- `moveEntity` -> `applyTranslation`;
- `setDesiredVelocity` -> `setVelocity`.

Intent order is command order. Command order is a deterministic input to simulation.

## Rules Profile

`GameRulesProfile` is deliberately small. It stores:

- a stable profile id;
- translation scale;
- velocity scale.

These values are enough to make intent mapping explicit and testable without introducing combat, RPG stats, inventory, quests, factions, abilities, or player-controller behavior.

## Deterministic Hashing

Game-layer hashing uses `StableHasher` domains:

```text
Telluric.GameInputFrame.v1
Telluric.GameIntentMappingResult.v1
Telluric.GameStepResult.v1
```

Hashes consume ordered game inputs, ordered simulation input frames, runtime snapshot hashes, ordered diagnostics, and success state. They exclude wall-clock time, platform input events, device handles, rendering resources, app lifecycle state, and unordered collection traversal.

## Dependency Rules

`TelluricGame` may depend on engine-level contracts, including:

```text
TelluricCore
TelluricMath
TelluricDeterminism
TelluricDiagnostics
TelluricECS
TelluricSimulation
TelluricStreaming
TelluricRuntime
```

`TelluricGame` must not import:

```text
SwiftUI
AppKit
Metal
MetalKit
TelluricRenderMetal
TelluricGameApp
TelluricGameAppCore
AVFoundation
CoreAudio
GameplayKit
```

## Not Implemented In TelluricGame

`TelluricGame` does not implement:

- app/window/view code;
- platform input devices;
- renderer ownership inside `TelluricGame`;
- direct Metal backend integration inside `TelluricGame`;
- player controller implementation;
- gameplay camera;
- combat;
- inventory;
- quests;
- factions;
- RPG stats;
- audio, motion, or ML.

Phase 16 implements `TelluricGameApp` as a thin host only. It still does not implement platform input devices, player controllers, gameplay camera, combat, inventory, quests, factions, RPG stats, renderer ownership inside `TelluricGame`, or direct backend integration inside `TelluricGame`.
