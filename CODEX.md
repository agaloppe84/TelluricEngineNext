# CODEX.md — Operational Rules for Telluric Engine Next

This file complements `AGENTS.md`.

`AGENTS.md` is the primary instruction file for Codex. `CODEX.md` keeps the project-specific workflow readable for the user.

## Correct Codex startup workflow

Codex should not be launched against an empty, contextless environment.

The correct workflow is:

```text
1. User creates a local repository folder.
2. User copies this documentation pack into the repo.
3. User initializes Git.
4. User runs the safe preflight script.
5. User opens/attaches Codex to that repository.
6. Codex reads AGENTS.md and the architecture docs.
7. Codex performs one bounded task at a time.
```

## Minimal manual setup

The user only needs to create the repository shell and copy the docs.

```sh
mkdir TelluricEngineNext
cd TelluricEngineNext
git init
# copy files from this documentation pack here
chmod +x scripts/*.sh
./scripts/codex-preflight-safe.sh
```

After that, Codex can build the Phase 0 SwiftPM architectural skeleton.

## Safe command policy

Use:

```sh
./scripts/codex-preflight-safe.sh
./scripts/swift-build-safe.sh
./scripts/swift-test-safe.sh
./scripts/check-architecture-guards.sh
./scripts/game-app-safe.sh --dry-run
```

Do not use direct global setup commands.

## Phase definitions

```text
Phase 0 = repo-local safe bootstrap + SwiftPM architectural skeleton.
Phase 1 = first real engine foundation implementation: Core, Math, Determinism, Diagnostics.
```

Phase 0 may create a compilable SwiftPM package and minimal target source files, but it must not implement engine behavior, gameplay, UI tools, Xcode apps, or Metal backends.

## First Codex task

Once inside the repository, use:

```text
Read AGENTS.md, CODEX.md, README.md and all files under Docs/architecture.
Do not write code yet.

Audit the repository state and propose the exact Phase 0 implementation plan for Telluric Engine Next:
- SwiftPM monorepo skeleton limited to Phase 0 targets;
- safe scripts;
- architecture guards;
- docs integration;
- no Xcode app;
- no Metal backend yet;
- no gameplay;
- no tools UI;
- no changes outside the repo;
- no impact on Ruby/Rails.

Return the files you plan to create or modify and the safe commands you will run.
Wait for confirmation before editing.
```

## Project philosophy

Telluric Engine Next is:

```text
seed-first
deterministic-first
simulation-first
systemic-first
tools-as-clients
Metal-as-backend
Apple-Silicon-first
Ruby/Rails-safe
```
