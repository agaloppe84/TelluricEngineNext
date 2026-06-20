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
