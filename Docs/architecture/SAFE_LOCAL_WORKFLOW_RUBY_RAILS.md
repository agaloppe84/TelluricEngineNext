# Safe Local Workflow — Ruby/Rails Protection

## 0. Priority

The developer machine already has a working Ruby-on-Rails environment.

Telluric Engine Next must not modify:

- Ruby;
- Rails;
- Bundler;
- gems;
- PostgreSQL;
- Homebrew global state;
- shell profiles;
- global Xcode selection;
- global DerivedData.

## 1. Repository-local only

All build outputs must stay inside the repo:

```text
.build/
DerivedData/
GeneratedAssets/
LocalAssets/
Tools/benchmarks/
Tools/captures/
```

## 2. Xcode safety

Never run:

```sh
xcode-select --switch
xcode-select --reset
```

Use local environment variables inside scripts:

```sh
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
```

## 3. SwiftPM safety

Use:

```sh
./scripts/swift-build-safe.sh
./scripts/swift-test-safe.sh
```

These scripts must set local scratch/build paths.

## 4. Forbidden installer behavior

Codex must not install dependencies.

If a dependency appears missing, Codex must stop and report:

```text
Missing dependency:
Impact:
Options:
Recommended safe action:
```

## 5. Rails protection checks

Architecture guard scripts should fail if Telluric accidentally becomes a Ruby project by adding:

```text
Gemfile
Gemfile.lock
.bundle/
vendor/bundle/
```

## 6. Manual setup required before Codex

Codex cannot create the user's local folder from nowhere in a reliable repo-attached workflow.

The user should create:

```sh
mkdir TelluricEngineNext
cd TelluricEngineNext
git init
```

Then copy this doc pack and open the repo with Codex.
