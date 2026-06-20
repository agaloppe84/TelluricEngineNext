# Legacy Documentation Migration Map

The uploaded legacy documents are preserved in `Docs/legacy/`.

They must be treated as design references, not current repo structure.

## TELLURIC_BASE_SPECS.md

Keep:

- no fake intermediate systems;
- repo-local safe scripts;
- EngineCore pure;
- RenderCoreMetal separated;
- RuntimeApp thin;
- assets manifest/cooker;
- Apple tooling awareness;
- no global environment modification.

Adapt:

- old multi-package folder names become a SwiftPM monorepo module graph;
- Xcode project comes later, not first;
- RenderGraph is planned early but introduced after render contracts.

## TELLURIC_ENGINE_FINAL_ARCHITECTURE.md

Keep:

- seed-first;
- deterministic-first;
- systemic-first;
- simulation-first;
- Metal-first as backend strategy;
- Terrain Forge;
- Biome Forge;
- Surface Forge;
- EcoGrowth Forge;
- Motion Forge;
- Audio Forge;
- ML Bridge as non-authoritative.

Adapt:

- engine/game/tools separation becomes explicit;
- old Xcode app is not central;
- modules are divided into foundation, simulation, world, runtime, render, audio, motion, ML, clients.

## CODEX.md

Keep:

- Ruby/Rails safety;
- no global commands;
- no xcode-select;
- local DEVELOPER_DIR only;
- repo-local build caches;
- scripts safe;
- no Ruby commands;
- no external dependency install.

Adapt:

- use `AGENTS.md` as the primary Codex instruction file;
- retain `CODEX.md` as user-facing operational companion;
- update structure from old `EngineCore/RenderCoreMetal/...` folders to a SwiftPM monorepo target graph.

## TELLURIC_BIOME_TERRAIN_FORGE_ULTIMATE.md

Map to:

```text
TelluricWorld
TelluricTerrain
TelluricBiomes
TelluricSurfaces
TelluricEcology
TelluricStreaming
TelluricWorldLab
TelluricSeedValidator
```

Key rule:

```text
World fields and graph truth first, chunk payloads second.
No biome-by-chunk island generation.
```

## TELLURIC_MOTION_FORGE_ULTIMATE.md

Map to:

```text
TelluricMotionCore
TelluricMotionRuntime
TelluricMotionTools
TelluricGame
TelluricRender
TelluricAudioCore
```

Key rule:

```text
Motion is intent-driven, contact-aware, world-aware and tool-authored.
Runtime consumes cooked motion data and produces pose/contact snapshots.
```

## TELLURIC_PROCEDURAL_PARAMETRIC_AUDIO_ENGINE.md

Map to:

```text
TelluricAudioCore
TelluricAudioRuntime
TelluricAudioTools
TelluricSurfaces
TelluricWorld
TelluricRuntime
```

Key rule:

```text
Audio reads world/surface/event snapshots.
Audio runtime does not own world state.
```

## TELLURIC_METAL4_AI_ML_RPG_PIPELINE.md

Map to:

```text
TelluricRPGCore
TelluricMLBridge
TelluricMLTools
TelluricRuntime
TelluricPersistence
```

Key rule:

```text
ML proposes.
Deterministic rules validate.
Only validated decisions enter WorldState/SaveDelta.
```
