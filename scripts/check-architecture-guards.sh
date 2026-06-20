#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "Architecture guard failed: $1" >&2
  exit 1
}

if [ -d Sources ]; then
  allowed_source_targets=(
    TelluricCore
    TelluricMath
    TelluricDeterminism
    TelluricDiagnostics
    TelluricECS
    TelluricSimulation
    TelluricWorld
    TelluricTerrain
    TelluricBiomes
    TelluricStreaming
    TelluricAssets
    TelluricPersistence
    TelluricRuntime
    TelluricGame
    TelluricRender
    TelluricRenderExtraction
    TelluricRenderMetal
    TelluricGameAppCore
    TelluricGameApp
    TelluricSeedValidatorCore
    TelluricSeedValidator
    TelluricAssetCookerCore
    TelluricAssetCooker
    TelluricReplayInspector
    TelluricHeadlessLoopCore
    TelluricHeadlessLoop
  )

  for source_path in Sources/*; do
    [ -d "$source_path" ] || continue
    target_name="$(basename "$source_path")"
    is_allowed=0

    for allowed_target in "${allowed_source_targets[@]}"; do
      if [ "$target_name" = "$allowed_target" ]; then
        is_allowed=1
        break
      fi
    done

    if [ "$is_allowed" -ne 1 ]; then
      fail "source target is not allowed in the current architecture phase: $target_name"
    fi
  done

  forbidden_source_targets=(
    TelluricAudioTools
    TelluricMotionTools
    TelluricMLTools
    TelluricRPGCore
    TelluricWorldLab
  )

  for forbidden_target in "${forbidden_source_targets[@]}"; do
    if [ -e "Sources/$forbidden_target" ]; then
      fail "current architecture phase must not create $forbidden_target"
    fi
  done

  if grep -R -n -E "^[[:space:]]*import[[:space:]]+(SwiftUI|AVFoundation|CoreAudio|GameplayKit)([[:space:]]|$)" Sources --include="*.swift" >/dev/null 2>&1; then
    grep -R -n -E "^[[:space:]]*import[[:space:]]+(SwiftUI|AVFoundation|CoreAudio|GameplayKit)([[:space:]]|$)" Sources --include="*.swift" >&2
    fail "sources contain forbidden UI/audio/game framework imports"
  fi

  if grep -R -n -E "^[[:space:]]*import[[:space:]]+AppKit([[:space:]]|$)" Sources --include="*.swift" --exclude-dir="TelluricGameApp" >/dev/null 2>&1; then
    grep -R -n -E "^[[:space:]]*import[[:space:]]+AppKit([[:space:]]|$)" Sources --include="*.swift" --exclude-dir="TelluricGameApp" >&2
    fail "AppKit imports are allowed only in Sources/TelluricGameApp"
  fi

  if grep -R -n -E "^[[:space:]]*import[[:space:]]+Metal([[:space:]]|$)" Sources --include="*.swift" --exclude-dir="TelluricRenderMetal" --exclude-dir="TelluricGameApp" >/dev/null 2>&1; then
    grep -R -n -E "^[[:space:]]*import[[:space:]]+Metal([[:space:]]|$)" Sources --include="*.swift" --exclude-dir="TelluricRenderMetal" --exclude-dir="TelluricGameApp" >&2
    fail "Metal imports are allowed only in Sources/TelluricRenderMetal and app-shell platform glue"
  fi

  if grep -R -n -E "^[[:space:]]*import[[:space:]]+MetalKit([[:space:]]|$)" Sources --include="*.swift" --exclude-dir="TelluricGameApp" >/dev/null 2>&1; then
    grep -R -n -E "^[[:space:]]*import[[:space:]]+MetalKit([[:space:]]|$)" Sources --include="*.swift" --exclude-dir="TelluricGameApp" >&2
    fail "MetalKit imports are allowed only in Sources/TelluricGameApp"
  fi

  deterministic_dirs=(
    Sources/TelluricDeterminism
    Sources/TelluricECS
    Sources/TelluricSimulation
    Sources/TelluricWorld
    Sources/TelluricTerrain
    Sources/TelluricBiomes
    Sources/TelluricStreaming
    Sources/TelluricRuntime
    Sources/TelluricGame
    Sources/TelluricRender
    Sources/TelluricRenderExtraction
    Sources/TelluricRenderMetal
    Sources/TelluricAssets
    Sources/TelluricPersistence
    Sources/TelluricSeedValidatorCore
    Sources/TelluricAssetCookerCore
    Sources/TelluricHeadlessLoopCore
    Sources/TelluricHeadlessLoop
    Sources/TelluricGameAppCore
  )

  for deterministic_dir in "${deterministic_dirs[@]}"; do
    [ -d "$deterministic_dir" ] || continue

    if grep -R -n -E "random[[:space:]]*\(in:|UUID[[:space:]]*\(\)|Date[[:space:]]*\(\)" "$deterministic_dir" --include="*.swift" >/dev/null 2>&1; then
      grep -R -n -E "random[[:space:]]*\(in:|UUID[[:space:]]*\(\)|Date[[:space:]]*\(\)" "$deterministic_dir" --include="*.swift" >&2
      fail "$deterministic_dir contains unstable deterministic/procedural API usage"
    fi
  done

  engine_dirs=(
    Sources/TelluricCore
    Sources/TelluricMath
    Sources/TelluricDeterminism
    Sources/TelluricDiagnostics
    Sources/TelluricECS
    Sources/TelluricSimulation
    Sources/TelluricWorld
    Sources/TelluricTerrain
    Sources/TelluricBiomes
    Sources/TelluricStreaming
    Sources/TelluricAssets
    Sources/TelluricPersistence
    Sources/TelluricRuntime
    Sources/TelluricRender
    Sources/TelluricRenderExtraction
    Sources/TelluricRenderMetal
  )

  for engine_dir in "${engine_dirs[@]}"; do
    [ -d "$engine_dir" ] || continue

    if grep -R -n -E "^[[:space:]]*import[[:space:]]+(TelluricGame|TelluricGameApp|TelluricGameAppCore|TelluricTools|TelluricSeedValidator|TelluricSeedValidatorCore|TelluricAssetCooker|TelluricAssetCookerCore|TelluricReplayInspector|TelluricHeadlessLoop|TelluricHeadlessLoopCore)([[:space:]]|$)" "$engine_dir" --include="*.swift" >/dev/null 2>&1; then
      grep -R -n -E "^[[:space:]]*import[[:space:]]+(TelluricGame|TelluricGameApp|TelluricGameAppCore|TelluricTools|TelluricSeedValidator|TelluricSeedValidatorCore|TelluricAssetCooker|TelluricAssetCookerCore|TelluricReplayInspector|TelluricHeadlessLoop|TelluricHeadlessLoopCore)([[:space:]]|$)" "$engine_dir" --include="*.swift" >&2
      fail "$engine_dir imports app/game/tool modules"
    fi
  done

  bridge_forbidden_import_dirs=(
    Sources/TelluricCore
    Sources/TelluricMath
    Sources/TelluricDeterminism
    Sources/TelluricDiagnostics
    Sources/TelluricECS
    Sources/TelluricSimulation
    Sources/TelluricWorld
    Sources/TelluricTerrain
    Sources/TelluricBiomes
    Sources/TelluricStreaming
    Sources/TelluricAssets
    Sources/TelluricPersistence
    Sources/TelluricRuntime
    Sources/TelluricRender
    Sources/TelluricRenderMetal
  )

  for bridge_forbidden_import_dir in "${bridge_forbidden_import_dirs[@]}"; do
    [ -d "$bridge_forbidden_import_dir" ] || continue

    if grep -R -n -E "^[[:space:]]*import[[:space:]]+TelluricRenderExtraction([[:space:]]|$)" "$bridge_forbidden_import_dir" --include="*.swift" >/dev/null 2>&1; then
      grep -R -n -E "^[[:space:]]*import[[:space:]]+TelluricRenderExtraction([[:space:]]|$)" "$bridge_forbidden_import_dir" --include="*.swift" >&2
      fail "$bridge_forbidden_import_dir imports the render extraction bridge"
    fi
  done

  if [ -d Sources/TelluricGame ]; then
    if grep -R -n -E "^[[:space:]]*import[[:space:]]+(TelluricRenderMetal|TelluricGameApp|TelluricGameAppCore)([[:space:]]|$)" Sources/TelluricGame --include="*.swift" >/dev/null 2>&1; then
      grep -R -n -E "^[[:space:]]*import[[:space:]]+(TelluricRenderMetal|TelluricGameApp|TelluricGameAppCore)([[:space:]]|$)" Sources/TelluricGame --include="*.swift" >&2
      fail "TelluricGame must not import render backends or app targets"
    fi
  fi

  if grep -R -n -E "MTKView|NSWindow" Sources --include="*.swift" --exclude-dir="TelluricGameApp" >/dev/null 2>&1; then
    grep -R -n -E "MTKView|NSWindow" Sources --include="*.swift" --exclude-dir="TelluricGameApp" >&2
    fail "MTKView and NSWindow are allowed only in Sources/TelluricGameApp"
  fi

  if grep -R -n -E "UIWindow" Sources --include="*.swift" >/dev/null 2>&1; then
    grep -R -n -E "UIWindow" Sources --include="*.swift" >&2
    fail "UIWindow is not allowed in the macOS app shell"
  fi
fi

for forbidden in Gemfile Gemfile.lock .bundle vendor/bundle; do
  if [ -e "$forbidden" ]; then
    fail "Ruby/Rails marker exists: $forbidden"
  fi
done

if find . -path ./.git -prune -o \( -name "*.rb" -o -name Rakefile -o -name config.ru -o -name Gemfile -o -name Gemfile.lock -o -name .ruby-version -o -name .ruby-gemset \) -print | grep . >/dev/null 2>&1; then
  find . -path ./.git -prune -o \( -name "*.rb" -o -name Rakefile -o -name config.ru -o -name Gemfile -o -name Gemfile.lock -o -name .ruby-version -o -name .ruby-gemset \) -print >&2
  fail "Ruby/Rails files are not allowed in this repo"
fi

for forbidden_package_name in TelluricAudioTools TelluricMotionTools TelluricMLTools TelluricRPGCore TelluricWorldLab; do
  if [ -f Package.swift ] && grep -n "\"$forbidden_package_name\"" Package.swift >/dev/null 2>&1; then
    fail "Package.swift contains a target not allowed in the current architecture phase: $forbidden_package_name"
  fi
done

forbidden_script_commands=("su""do" "br""ew" "ru""by" "ge""m" "bun""dle" "rai""ls" "ra""ke" "xcode""-select")
script_command_pattern="(^|[;&|[:space:]])($(IFS='|'; echo "${forbidden_script_commands[*]}"))([[:space:];&|]|$)"

if grep -R -n -E "$script_command_pattern" scripts --include="*.sh" >/dev/null 2>&1; then
  grep -R -n -E "$script_command_pattern" scripts --include="*.sh" >&2
  fail "unsafe command invocation appears in scripts"
fi

if [ -f Package.swift ] && [ -d Sources/TelluricSeedValidator ]; then
  bash scripts/seed-validator-smoke-safe.sh
fi

echo "Architecture guards OK"
