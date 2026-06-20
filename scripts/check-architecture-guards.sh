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
    TelluricRender
    TelluricSeedValidatorCore
    TelluricSeedValidator
    TelluricAssetCooker
    TelluricReplayInspector
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
      fail "Phase 0 source target is not allowed yet: $target_name"
    fi
  done

  forbidden_phase0_targets=(
    TelluricGame
    TelluricGameApp
    TelluricRenderMetal
    TelluricAudioTools
    TelluricMotionTools
    TelluricMLTools
    TelluricRPGCore
    TelluricWorldLab
  )

  for forbidden_target in "${forbidden_phase0_targets[@]}"; do
    if [ -e "Sources/$forbidden_target" ]; then
      fail "Phase 0 must not create $forbidden_target"
    fi
  done

  if grep -R -n -E "^[[:space:]]*import[[:space:]]+(SwiftUI|AppKit|Metal|MetalKit|AVFoundation|CoreAudio|GameplayKit)([[:space:]]|$)" Sources --include="*.swift" >/dev/null 2>&1; then
    grep -R -n -E "^[[:space:]]*import[[:space:]]+(SwiftUI|AppKit|Metal|MetalKit|AVFoundation|CoreAudio|GameplayKit)([[:space:]]|$)" Sources --include="*.swift" >&2
    fail "Phase 0 sources contain forbidden platform/UI/render/audio imports"
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
    Sources/TelluricRender
    Sources/TelluricSeedValidatorCore
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
  )

  for engine_dir in "${engine_dirs[@]}"; do
    [ -d "$engine_dir" ] || continue

    if grep -R -n -E "^[[:space:]]*import[[:space:]]+(TelluricGame|TelluricGameApp|TelluricTools|TelluricSeedValidator|TelluricSeedValidatorCore|TelluricAssetCooker|TelluricReplayInspector)([[:space:]]|$)" "$engine_dir" --include="*.swift" >/dev/null 2>&1; then
      grep -R -n -E "^[[:space:]]*import[[:space:]]+(TelluricGame|TelluricGameApp|TelluricTools|TelluricSeedValidator|TelluricSeedValidatorCore|TelluricAssetCooker|TelluricReplayInspector)([[:space:]]|$)" "$engine_dir" --include="*.swift" >&2
      fail "$engine_dir imports app/game/tool modules"
    fi
  done
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

for forbidden_package_name in TelluricGame TelluricGameApp TelluricRenderMetal TelluricAudioTools TelluricMotionTools TelluricMLTools TelluricRPGCore TelluricWorldLab; do
  if [ -f Package.swift ] && grep -n "\"$forbidden_package_name\"" Package.swift >/dev/null 2>&1; then
    fail "Package.swift contains a target not allowed in Phase 0: $forbidden_package_name"
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
