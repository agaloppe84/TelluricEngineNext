# Game App Shell

Phase 16 creates the first minimal macOS app shell for Telluric Engine Next.
Phase 17 adds the first drawable debug-line render pass.

This is a SwiftPM executable host, not a traditional Xcode project or packaged app bundle. It exists to prove that the existing engine/game/runtime/render-extraction/Metal-preparation pipeline can be hosted visually without moving engine behavior into UI code.

## App Shell vs Engine

`TelluricGameApp` is a top-level client. It must never become an engine module.

```text
TelluricGameApp -> TelluricGameAppCore -> TelluricGame -> TelluricRuntime -> engine modules
```

Engine modules must not import `TelluricGameApp` or `TelluricGameAppCore`.

`TelluricGameAppCore` is UI-free and testable. It owns the app-shell config, dry-run/smoke paths, stateful pipeline stepping, and renderer-independent frame values. `TelluricGameApp` owns only macOS process/window/view glue.

## App Shell vs Game Layer

`TelluricGame` remains app-free. It still owns game sessions, ordered game intents, and mapping into simulation commands.

The app shell does not add platform input handling yet. It creates deterministic `GameInputFrame` values through the same minimal intent path validated by the headless loop.

## UI Import Isolation

Only `Sources/TelluricGameApp` may import:

```text
AppKit
MetalKit
```

`Sources/TelluricGameApp` may also import `Metal` as platform glue to create an `MTLDevice` for `MTKView`.

Engine modules, `TelluricGame`, `TelluricRuntime`, `TelluricRender`, `TelluricRenderExtraction`, `TelluricRenderMetal`, and `TelluricGameAppCore` must remain free of AppKit, SwiftUI, and app/window code. `TelluricRenderMetal` remains the only engine/backend target that may import `Metal`.

## What The App Can Currently Show

The app shell can:

- create a minimal macOS window;
- create an `MTKView` when a Metal device exists;
- initialize `GameSession` with deterministic config;
- step the existing game/runtime pipeline from the `MTKView` draw callback;
- extract a backend-neutral `RenderSnapshot`;
- pass that snapshot to `TelluricRenderMetal`;
- prepare debug line vertex data through the Metal backend;
- render debug chunk boundary lines into the current drawable when Metal and a drawable are available;
- log structured frame diagnostics.

The app currently shows a clear background plus flat chunk boundary debug lines. Those lines come from `RuntimeRenderExtractor` and are drawn through a debug-only top-down projection. They are not terrain meshes.

## Safe Run

Use the repo-local wrapper:

```sh
./scripts/game-app-safe.sh --dry-run
./scripts/game-app-safe.sh --smoke
```

To open the minimal window from a local macOS shell:

```sh
./scripts/game-app-safe.sh
```

The wrapper pins SwiftPM scratch, cache, config, security, home, and module-cache paths under `.build/`. Raw `swift run` can use user-level SwiftPM cache and configuration paths, so wrappers are preferred for Codex and validation work.

If Metal is unavailable, the app shell falls back to a plain view and no drawable rendering occurs. The no-window dry-run and smoke paths still validate the game/runtime/render-extraction/debug-line preparation chain.

## Not Implemented Yet

Phase 16 does not implement:

- an `.xcodeproj`;
- a packaged app bundle;
- terrain mesh generation;
- asset rendering;
- platform input;
- player controller or gameplay camera;
- combat, inventory, quests, factions, RPG stats;
- editor UI;
- audio, motion, or ML.

Phase 17 adds drawable debug-line rendering only. It still does not implement terrain rendering, materials, textures, asset loading, camera controls, player controls, or editor UI.
