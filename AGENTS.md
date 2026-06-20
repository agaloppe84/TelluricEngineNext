# AGENTS.md — Telluric Engine Next Agent Rules

> Scope: entire repository.
> Purpose: mandatory rules for Codex and any automated coding agent.
> Priority: protecting the developer machine and keeping the engine architecture clean.

## 0. Absolute local environment rule

This machine has an existing Ruby-on-Rails development environment. It must not be modified.

Agents must not perform global system changes, global package installs, shell profile edits, Homebrew upgrades, Ruby/Rails configuration changes, or Xcode developer directory switches.

Everything must remain local to this repository.

## 1. Codex operating mode

Codex must work from inside this repository.

Before any non-trivial change, Codex must inspect:

- `AGENTS.md`
- `CODEX.md`
- `Docs/architecture/TELLURIC_ENGINE_NEXT_ARCHITECTURE.md`
- `Docs/architecture/SAFE_LOCAL_WORKFLOW_RUBY_RAILS.md`
- relevant legacy docs under `Docs/legacy/`

Codex must not assume that the old Xcode project is the current architecture.

## 2. Forbidden commands

Never run:

```sh
sudo
xcode-select
xcode-select --switch
xcode-select --reset
brew update
brew upgrade
brew install
brew uninstall
brew cleanup
gem install
gem update
bundle update
bundle install --global
npm install -g
pnpm add -g
yarn global
asdf install
mise install
rbenv install
rvm install
```

Never modify:

```text
~/.zshrc
~/.bashrc
~/.profile
~/.zprofile
~/.zshenv
~/.bash_profile
~/.rbenv
~/.rvm
~/.asdf
~/.mise
~/.gem
~/.bundle
/opt/homebrew
/usr/local
/Library/Developer
/Applications/Xcode.app
/Applications/Xcode-beta.app
```

## 3. Ruby/Rails protection

Telluric is not a Ruby project.

Do not run Ruby/Rails commands unless explicitly requested by the user for read-only diagnostics:

```sh
ruby
rails
rake
bundle
bundle exec
gem
irb
```

Do not create or modify:

```text
Gemfile
Gemfile.lock
.bundle/
vendor/bundle/
```

## 4. Xcode / Swift safety

Do not call `xcode-select`.

If Xcode is needed, scripts must set `DEVELOPER_DIR` locally:

```sh
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
```

Do not write DerivedData outside the repo.

Use repo-local scripts:

```sh
./scripts/codex-preflight-safe.sh
./scripts/swift-build-safe.sh
./scripts/swift-test-safe.sh
./scripts/check-architecture-guards.sh
```

If a script is missing, create it locally and make it non-destructive.

## 5. Architecture rules

Telluric Engine Next is a modular SwiftPM monorepo.

The dependency direction is:

```text
TelluricGameApp -> TelluricGame -> TelluricRuntime -> Engine modules
TelluricTools   -> Engine modules
Engine modules  -> never Game
Engine modules  -> never Tools UI
```

Forbidden imports:

- `TelluricCore`, `TelluricMath`, `TelluricDeterminism`: no SwiftUI, AppKit, Metal, MetalKit, AVFoundation, GameController.
- `TelluricWorld`, `TelluricTerrain`, `TelluricBiomes`, `TelluricSimulation`: no SwiftUI, AppKit, Metal, MetalKit.
- `TelluricRender`: no Metal, no MetalKit.
- `TelluricRenderMetal`: the only engine/backend module allowed to import Metal. It must not import MetalKit unless a backend phase explicitly requires it.
- `TelluricGameApp`: the only app shell target allowed to import AppKit/MetalKit. It may import Metal as platform glue for MTKView device creation.
- `TelluricAudioRuntime`: the only runtime audio backend allowed to import AVFoundation/CoreAudio APIs when introduced.
- Tool apps may import SwiftUI/AppKit, but only inside tool targets.

## 6. No throwaway code

The user does not want prototype code that will be thrown away.

Allowed:

- vertical slices;
- minimal implementations that respect final contracts;
- tests;
- diagnostics;
- explicit unsupported cases with errors.

Forbidden:

- fake implementations that return constant hashes;
- TODOs for required behavior;
- preview-only systems that become architectural debt;
- renderer-driven world data;
- `MTLBuffer` or GPU objects inside world/terrain/simulation payloads.

## 7. Determinism rules

Any procedural or simulation logic must be:

- seed-driven;
- versioned;
- stable-hashable;
- reproducible;
- testable;
- independent of wall-clock time;
- independent of global RNG;
- independent of unordered dictionary/set iteration for logical ordering.

Do not use in deterministic logic:

```swift
Float.random(in:)
Double.random(in:)
Int.random(in:)
UUID()
Date()
Dictionary iteration as logical order
Set iteration as logical order
```

## 8. Tests are not throwaway code

The user does not want throwaway implementation code. Automated tests are still mandatory engine infrastructure.

Every deterministic, math, generation, simulation, asset, streaming, replay, and persistence change must include tests.

## 9. Required response before implementation

For non-trivial work, Codex must state:

```text
1. Objective
2. Files to modify
3. Contracts added or changed
4. Determinism impact
5. Performance impact
6. Local environment impact
7. Tests to add/update
8. Safe validation commands
9. Risks
10. Small-step implementation plan
```

## 10. Git rules

Start with:

```sh
git status --short
```

Do not overwrite user changes.

Do not run without explicit user permission:

```sh
git reset --hard
git clean -fd
git checkout -- .
git rebase
git push --force
git commit
git push
```

Commits are allowed only when explicitly requested.
