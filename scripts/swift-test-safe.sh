#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export SWIFTPM_BUILD_DIR="$ROOT/.build/swiftpm"
export SWIFTPM_CACHE_DIR="$ROOT/.build/swiftpm-cache"
export SWIFTPM_CONFIG_DIR="$ROOT/.build/swiftpm-config"
export SWIFTPM_SECURITY_DIR="$ROOT/.build/swiftpm-security"
export HOME="$ROOT/.build/home"
export XDG_CACHE_HOME="$ROOT/.build/cache"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache/clang"
export SWIFT_MODULE_CACHE_PATH="$ROOT/.build/module-cache/swift"

mkdir -p "$SWIFTPM_BUILD_DIR" "$SWIFTPM_CACHE_DIR" "$SWIFTPM_CONFIG_DIR" "$SWIFTPM_SECURITY_DIR" "$HOME" "$XDG_CACHE_HOME" "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULE_CACHE_PATH"

if [ ! -f "Package.swift" ]; then
  echo "Package.swift not found yet. Nothing to test." >&2
  exit 0
fi

/usr/bin/xcrun swift test \
  --disable-sandbox \
  --scratch-path "$SWIFTPM_BUILD_DIR" \
  --cache-path "$SWIFTPM_CACHE_DIR" \
  --config-path "$SWIFTPM_CONFIG_DIR" \
  --security-path "$SWIFTPM_SECURITY_DIR" \
  -Xswiftc -module-cache-path \
  -Xswiftc "$SWIFT_MODULE_CACHE_PATH" \
  "$@"
