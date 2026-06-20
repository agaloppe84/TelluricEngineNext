#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Telluric Engine Next preflight"
echo "ROOT=$ROOT"

if [ ! -f "AGENTS.md" ]; then
  echo "Missing AGENTS.md. Refusing to continue." >&2
  exit 1
fi

if [ ! -f "CODEX.md" ]; then
  echo "Missing CODEX.md. Refusing to continue." >&2
  exit 1
fi

if [ ! -d ".git" ]; then
  echo "Missing .git directory. Create a git repo first." >&2
  exit 1
fi

echo "Git status:"
git status --short

echo "Checking Ruby/Rails safety markers..."
for forbidden in Gemfile Gemfile.lock .bundle vendor/bundle; do
  if [ -e "$forbidden" ]; then
    echo "Forbidden Ruby/Rails marker found: $forbidden" >&2
    exit 1
  fi
done

echo "Checking local docs..."
test -f Docs/architecture/TELLURIC_ENGINE_NEXT_ARCHITECTURE.md
test -f Docs/architecture/SAFE_LOCAL_WORKFLOW_RUBY_RAILS.md
test -f Docs/architecture/MODULE_GRAPH.md

echo "Preflight OK"
