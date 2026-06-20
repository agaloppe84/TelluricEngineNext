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
./scripts/game-app-safe.sh
```

The dry run exercises the app-shell pipeline without opening a window. The normal run opens a minimal macOS window and `MTKView` when Metal is available, but drawable rendering is not implemented yet. Use the safe wrapper because it keeps SwiftPM scratch, cache, config, home, and module-cache paths under this repository.
