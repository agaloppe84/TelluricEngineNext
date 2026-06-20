# Telluric Engine Next

Telluric Engine Next is the clean restart of the previous Telluric / IsoWorld / IsoForge prototype.

The old Xcode-first implementation is not the technical base anymore. The previous documents are preserved under `Docs/legacy/` as design references only.

## Core principle

Telluric Engine is not an app.

- The engine is a modular SwiftPM platform.
- The game is a client of the engine.
- The tools are clients of the engine.
- The runtime app is a thin shell.
- Metal is a backend, not the world model.
- Tools never run inside the critical runtime.
- The local Ruby/Rails environment must never be modified.

## First local setup

From a terminal:

```sh
mkdir TelluricEngineNext
cd TelluricEngineNext
git init
mkdir -p Docs scripts
# copy this documentation pack into this repo
chmod +x scripts/*.sh
./scripts/codex-preflight-safe.sh
```

Then open this folder/repo with Codex.

Do not ask Codex to start from an empty global context. It must work inside this repository.

## Seed validator

The first CLI engine tool validates deterministic world generation over a chunk grid:

```sh
swift run telluric-seed-validator --seed 12345 --radius 2 --chunk-size 32 --vertical-scale 12 --report Tools/benchmarks/seed_12345.json
```

Use the repo-local scripts for normal validation. `./scripts/check-architecture-guards.sh` includes a tiny seed validator smoke run and writes its generated report under ignored `Tools/benchmarks/` output.

## Asset cooker

The asset cooker validates JSON asset manifests and writes deterministic reports:

```sh
swift run telluric-asset-cooker --manifest Assets/Manifests/assets.json --output Assets/Cooked --report Tools/benchmarks/asset_cook_report.json
```

Phase 10 produces validation reports and cooked descriptors only. It does not convert meshes, textures, materials, audio, motion, terrain recipes, or biome recipes yet. Use `--strict` to make unsupported conversions explicit errors.

## Headless loop

The headless loop is a vertical integration smoke tool. It runs game intent mapping, runtime stepping, render extraction, Metal debug-line preparation, and persistence packaging without creating an app, window, view, or drawable:

```sh
swift run telluric-headless-loop --seed 12345 --radius 1 --chunk-size 16 --vertical-scale 8 --ticks 3 --report Tools/benchmarks/headless_loop_report.json
```

The report is deterministic-friendly and contains ordered per-tick summaries, final runtime/render hashes, debug-line preparation counts, Metal availability diagnostics, and persistence package summaries.

## Minimal macOS app shell

The app shell is a thin SwiftPM executable host over the existing validated pipeline:

```sh
./scripts/game-app-safe.sh --dry-run
./scripts/game-app-safe.sh --smoke --frames 120
./scripts/game-app-safe.sh --run --seed 12345 --radius 1 --chunk-size 16 --vertical-scale 8
./scripts/game-app-safe.sh --run --diagnostics-report Tools/benchmarks/game_app_visual_report.json
```

The dry run and smoke paths exercise the app-shell pipeline without opening a window. `--run` opens a minimal macOS window and `MTKView` when Metal is available. The current drawable pass clears the view and draws extracted debug grid lines plus an optional terrain height wireframe preview; it does not render final terrain meshes, materials, textures, assets, or gameplay.

The app shell includes debug-only projection controls for viewing the chunk grid. `+`/`=` zooms in, `-` zooms out, arrow keys or `W`/`A`/`S`/`D` pan, `0` or `R` refocuses the grid, and mouse wheel zooms. These controls affect only debug visualization, not game/runtime state.

Visual layer toggles are also debug-only: `G` toggles chunk boundaries, `X` toggles axes, `O` toggles the origin marker, `C` toggles chunk center crosses, `H` toggles the central chunk highlight, `B` toggles streaming bounds, `T` toggles terrain height wireframe, and `V` toggles verbose frame logging.

For a bounded visual check with diagnostics:

```sh
./scripts/game-app-safe.sh --run --frames 120 --seed 12345 --radius 1 --chunk-size 16 --vertical-scale 8 --diagnostics-report Tools/benchmarks/game_app_camera_report.json
./scripts/game-app-safe.sh --run --frames 120 --seed 12345 --radius 1 --chunk-size 16 --vertical-scale 8 --diagnostics-report Tools/benchmarks/game_app_visual_polish_report.json
./scripts/game-app-safe.sh --run --seed 12345 --radius 1 --chunk-size 16 --vertical-scale 8 --show-terrain --terrain-stride 4 --terrain-height-scale 1.0 --diagnostics-report Tools/benchmarks/game_app_terrain_debug_report.json
```

With Metal and a drawable available, the radius 1 chunk grid should be centered and scaled in the window. The default polished debug view draws chunk boundaries, X/Z axes, the world origin marker, the central chunk highlight, the streaming radius outline, and a cyan/teal terrain height wireframe. Debug line draw calls should succeed with no diagnostics errors. For radius 1 / chunk size 16 / terrain stride 4, expect 408 prepared/drawn debug lines.

Run logging can be adjusted with `--quiet`, `--verbose`, and `--log-every <N>`. Visual layers can also be disabled at launch with `--hide-grid`, `--hide-axes`, `--hide-origin`, `--hide-central-highlight`, `--hide-radius-bounds`, `--hide-terrain`, or enabled with `--show-centers` and `--show-terrain`. Terrain preview density can be adjusted with `--terrain-stride <N>` and height exaggeration with `--terrain-height-scale <Float>`.

Use the safe wrapper because it keeps SwiftPM scratch, cache, config, home, and module-cache paths under this repository. `./scripts/game-app-safe.sh --script-help` prints wrapper examples without launching the app.
